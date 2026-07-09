defmodule HeidyApi.Moodle.Client.Ediciplinas do
  @moduledoc """
  e-Disciplinas client using USP's SAML single-sign-on flow.

  The client performs the browser flow in memory, reads Moodle's authenticated
  course and activity pages, and keeps no credential or cookie after the
  request ends.
  """

  @behaviour HeidyApi.Moodle.Client

  alias HeidyApi.Moodle.{Activity, ActivityDetail, Assignment, Course, CourseDetail, Session}

  @moodle_url "https://edisciplinas.usp.br"
  @login_url @moodle_url <> "/auth/shibboleth"
  @max_redirects 8
  @max_inline_file_size 10_000_000

  @impl true
  def login(username, password) do
    with {:ok, response, session} <- request(%Session{username: username}, :get, @login_url, []),
         {:ok, idp_url} <- location(response, @login_url),
         {:ok, idp_page, session} <- follow_redirects(session, idp_url),
         {:ok, form_url} <- form_action(idp_page.body, idp_url),
         {:ok, response, session} <-
           request(session, :post, form_url,
             form: [j_username: username, j_password: password, _eventId_proceed: "Login"]
           ),
         {:ok, session} <- complete_saml(session, response, form_url, 0),
         {:ok, dashboard, session} <- request(session, :get, @moodle_url <> "/my/", []),
         true <- authenticated?(dashboard) do
      {:ok, session}
    else
      false -> {:error, :invalid_credentials}
      {:error, :invalid_credentials} = error -> error
      _failure -> {:error, :unavailable}
    end
  end

  @impl true
  def fetch_assignments(%Session{} = session) do
    with {:ok, courses} <- fetch_courses(session) do
      assignments =
        courses
        |> Enum.flat_map(fn course ->
          case fetch_course(session, course.id) do
            {:ok, detail} -> assignments_from_course(session, course, detail)
            {:error, _reason} -> []
          end
        end)

      {:ok, assignments}
    else
      _failure -> {:error, :unavailable}
    end
  end

  @impl true
  def fetch_courses(%Session{} = session) do
    with {:ok, response, _session} <- request(session, :get, @moodle_url <> "/", []) do
      {:ok, courses_from_html(response.body)}
    else
      _failure -> {:error, :unavailable}
    end
  end

  @impl true
  def fetch_course(%Session{} = session, course_id)
      when is_integer(course_id) and course_id > 0 do
    with {:ok, response, _session} <-
           request(session, :get, @moodle_url <> "/course/view.php?id=#{course_id}", []) do
      course_from_html(response.body, course_id)
    end
  end

  def fetch_course(%Session{}, _course_id), do: {:error, :unavailable}

  @impl true
  def fetch_activity(%Session{} = session, activity_url) do
    with {:ok, activity_id} <- valid_activity_url(activity_url),
         {:ok, response, _session} <- follow_redirects(session, activity_url) do
      if html_response?(response) do
        activity_from_html(response.body, activity_id)
      else
        file_from_response(response, activity_id)
      end
    end
  end

  defp follow_redirects(session, url, redirects \\ 0)

  defp follow_redirects(session, url, redirects) when redirects < @max_redirects do
    with {:ok, response, session} <- request(session, :get, url, []) do
      if response.status in 300..399 do
        with {:ok, redirect_url} <- location(response, url) do
          follow_redirects(session, redirect_url, redirects + 1)
        end
      else
        {:ok, response, session}
      end
    end
  end

  defp follow_redirects(_session, _url, _redirects), do: {:error, :unavailable}

  defp html_response?(response) do
    response
    |> Req.Response.get_header("content-type")
    |> Enum.any?(&String.contains?(&1, "text/html"))
  end

  defp file_from_response(%{body: body} = response, activity_id)
       when is_binary(body) and byte_size(body) <= @max_inline_file_size do
    mime =
      response |> Req.Response.get_header("content-type") |> List.first() ||
        "application/octet-stream"

    name = filename(response) || "Arquivo"

    {:ok,
     %ActivityDetail{
       id: activity_id,
       title: name,
       content: "",
       links: [],
       file: %{name: name, mime: mime, data: Base.encode64(body)}
     }}
  end

  defp file_from_response(_response, _activity_id), do: {:error, :unavailable}

  defp filename(response) do
    response
    |> Req.Response.get_header("content-disposition")
    |> List.first()
    |> case do
      nil ->
        nil

      header ->
        case Regex.run(~r/filename\*?=(?:UTF-8''|\")?([^\";]+)/i, header) do
          [_, name] -> URI.decode(name)
          _none -> nil
        end
    end
  end

  defp complete_saml(session, response, base_url, redirects) when redirects < @max_redirects do
    cond do
      response.status in 300..399 ->
        with {:ok, redirect_url} <- location(response, base_url),
             {:ok, response, session} <- request(session, :get, redirect_url, []) do
          complete_saml(session, response, redirect_url, redirects + 1)
        end

      saml_form = saml_form(response.body, base_url) ->
        {url, fields} = saml_form

        with {:ok, response, session} <- request(session, :post, url, form: fields) do
          complete_saml(session, response, url, redirects + 1)
        end

      true ->
        {:ok, session}
    end
  end

  defp complete_saml(_session, _response, _base_url, _redirects), do: {:error, :unavailable}

  defp assignments_from_course(session, course, detail) do
    detail.activities
    |> Enum.filter(&(&1.kind in ["Tarefa", "Questionario"]))
    |> Enum.map(fn activity ->
      due_at =
        case fetch_activity(session, activity.url) do
          {:ok, detail} -> due_at(detail.content)
          {:error, _reason} -> nil
        end

      %Assignment{
        external_ref: "moodle:activity:#{activity.id}",
        title: activity.title,
        course_name: course.title,
        url: activity.url,
        due_at: due_at,
        kind: if(activity.kind == "Questionario", do: "exam", else: "assignment")
      }
    end)
  end

  @doc false
  @spec courses_from_html(String.t()) :: [Course.t()]
  def courses_from_html(html) do
    with {:ok, document} <- Floki.parse_document(html) do
      courses_from_document(document)
    else
      _invalid -> []
    end
  end

  @doc false
  @spec course_from_html(String.t(), pos_integer()) ::
          {:ok, CourseDetail.t()} | {:error, :unavailable}
  def course_from_html(html, course_id) do
    with {:ok, document} <- Floki.parse_document(html),
         title when is_binary(title) and title != "" <- title_from(document) do
      {:ok,
       %CourseDetail{
         id: course_id,
         title: title,
         activities: activities_from_document(document)
       }}
    else
      _invalid -> {:error, :unavailable}
    end
  end

  @doc false
  @spec activity_from_html(String.t(), pos_integer()) ::
          {:ok, ActivityDetail.t()} | {:error, :unavailable}
  def activity_from_html(html, activity_id) do
    with {:ok, document} <- Floki.parse_document(html),
         title when is_binary(title) and title != "" <- title_from(document) do
      {:ok,
       %ActivityDetail{
         id: activity_id,
         title: title,
         content: content_from_document(document),
         links: links_from_document(document),
         file: nil
       }}
    else
      _invalid -> {:error, :unavailable}
    end
  end

  defp courses_from_document(document) do
    course_links =
      document
      |> Floki.find("#unidades h5 a[href*='course/view.php?id=']")
      |> case do
        [] -> Floki.find(document, "h5 a[href*='course/view.php?id=']")
        links -> links
      end

    course_links
    |> Enum.flat_map(fn link ->
      with url when is_binary(url) <- link |> Floki.attribute("href") |> List.first(),
           {:ok, id} <- course_id(url),
           title when title != "" <- clean_text(link) do
        {code, name} = course_identity(title)

        [
          %Course{
            id: id,
            code: code,
            name: name,
            title: title,
            url: absolute_url(url, @moodle_url)
          }
        ]
      else
        _invalid -> []
      end
    end)
    |> Enum.uniq_by(& &1.id)
  end

  defp activities_from_document(document) do
    document
    |> Floki.find("a[href*='/mod/']")
    |> Enum.flat_map(fn link ->
      with url when is_binary(url) <- link |> Floki.attribute("href") |> List.first(),
           absolute_url <- absolute_url(url, @moodle_url),
           {:ok, id} <- valid_activity_url(absolute_url),
           title when title != "" <- clean_text(link) do
        [%Activity{id: id, title: title, kind: activity_kind(absolute_url), url: absolute_url}]
      else
        _invalid -> []
      end
    end)
    |> Enum.uniq_by(& &1.id)
  end

  defp content_from_document(document) do
    document
    |> Floki.find("main")
    |> List.first()
    |> clean_text()
    |> String.slice(0, 50_000)
  end

  defp links_from_document(document) do
    document
    |> Floki.find("main a[href]")
    |> Enum.flat_map(fn link ->
      with url when is_binary(url) <- link |> Floki.attribute("href") |> List.first(),
           label when label != "" <- clean_text(link) do
        [%{label: label, url: absolute_url(url, @moodle_url)}]
      else
        _invalid -> []
      end
    end)
    |> Enum.uniq_by(& &1.url)
    |> Enum.take(100)
  end

  defp title_from(document) do
    document
    |> Floki.find("h1")
    |> List.first()
    |> clean_text()
  end

  defp clean_text(nil), do: ""

  defp clean_text(node) do
    node
    |> Floki.text(sep: " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp course_id(url) do
    query = URI.parse(url).query || ""

    query
    |> URI.decode_query()
    |> Map.get("id")
    |> parse_positive_integer()
  end

  defp valid_activity_url(url) do
    uri = URI.parse(url)

    cond do
      uri.host not in [nil, "edisciplinas.usp.br"] ->
        {:error, :unavailable}

      not String.starts_with?(uri.path || "", "/mod/") ->
        {:error, :unavailable}

      true ->
        (uri.query || "") |> URI.decode_query() |> Map.get("id") |> parse_positive_integer()
    end
  end

  defp parse_positive_integer(nil), do: {:error, :unavailable}

  defp parse_positive_integer(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _invalid -> {:error, :unavailable}
    end
  end

  defp activity_kind(url) do
    url
    |> URI.parse()
    |> Map.get(:path, "")
    |> String.split("/", trim: true)
    |> Enum.at(1)
    |> case do
      "assign" -> "Tarefa"
      "quiz" -> "Questionario"
      "resource" -> "Arquivo"
      "folder" -> "Pasta"
      "forum" -> "Forum"
      "page" -> "Pagina"
      "url" -> "Link"
      _other -> "Atividade"
    end
  end

  defp course_identity(title) do
    case Regex.run(~r/^([A-Z]{2,6}\d{4})\s*[-–]\s*(.+?)(?:\s*\(\d{4}\))?$/u, title) do
      [_, code, name] -> {code, name}
      _other -> {nil, title}
    end
  end

  @months %{
    "janeiro" => 1,
    "fevereiro" => 2,
    "marco" => 3,
    "abril" => 4,
    "maio" => 5,
    "junho" => 6,
    "julho" => 7,
    "agosto" => 8,
    "setembro" => 9,
    "outubro" => 10,
    "novembro" => 11,
    "dezembro" => 12
  }

  defp due_at(content) do
    case Regex.run(
           ~r/(?:data de entrega|due date)\s*:?\s*(?:[^\d]{0,32})?(\d{1,2}) de ([[:alpha:]áéíóúâêôãõç]+) de (\d{4}),?\s*(\d{1,2}):(\d{2})/iu,
           content
         ) do
      [_, day, month, year, hour, minute] ->
        with month_number when is_integer(month_number) <-
               Map.get(@months, normalize_month(month)),
             {day, ""} <- Integer.parse(day),
             {year, ""} <- Integer.parse(year),
             {hour, ""} <- Integer.parse(hour),
             {minute, ""} <- Integer.parse(minute),
             {:ok, date} <- Date.new(year, month_number, day),
             {:ok, time} <- Time.new(hour, minute, 0) do
          date
          |> NaiveDateTime.new!(time)
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.add(3, :hour)
        else
          _invalid -> nil
        end

      _none ->
        nil
    end
  end

  defp normalize_month(month) do
    month
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z]/u, "")
  end

  defp authenticated?(%{body: body}) when is_binary(body) do
    String.contains?(body, "login/logout.php") or String.contains?(body, "data-userid=")
  end

  defp authenticated?(_response), do: false

  defp form_action(body, base_url) do
    case Regex.run(~r/<form\b[^>]*\baction=["']([^"']+)/i, body) do
      [_, action] -> {:ok, absolute_url(html_unescape(action), base_url)}
      _none -> {:error, :unavailable}
    end
  end

  defp saml_form(body, base_url) when is_binary(body) do
    with {:ok, url} <- form_action(body, base_url),
         true <- String.contains?(body, "SAMLResponse"),
         fields when fields != [] <- hidden_fields(body) do
      {url, fields}
    else
      _failure -> nil
    end
  end

  defp saml_form(_body, _base_url), do: nil

  defp hidden_fields(body) do
    Regex.scan(~r/<input\b(?=[^>]*\btype=["']hidden["'])[^>]*>/i, body)
    |> Enum.flat_map(fn [tag] ->
      with [_, name] <- Regex.run(~r/\bname=["']([^"']+)/i, tag),
           [_, value] <- Regex.run(~r/\bvalue=["']([^"']*)/i, tag) do
        [{html_unescape(name), html_unescape(value)}]
      else
        _missing -> []
      end
    end)
  end

  defp location(response, base_url) do
    case Req.Response.get_header(response, "location") do
      [location | _] -> {:ok, location |> html_unescape() |> absolute_url(base_url)}
      _none -> {:error, :unavailable}
    end
  end

  defp request(%Session{} = session, method, url, opts) do
    uri = URI.parse(url)
    host = uri.host || ""

    request =
      Req.new(
        [
          method: method,
          url: url,
          redirect: false,
          retry: false,
          headers: [{"cookie", cookie_header(session.cookies, host)}]
        ] ++ opts ++ Application.get_env(:heidy_api, __MODULE__, [])
      )

    case Req.request(request) do
      {:ok, %Req.Response{} = response} ->
        {:ok, response, %{session | cookies: merge_cookies(session.cookies, host, response)}}

      {:error, _reason} ->
        {:error, :unavailable}
    end
  end

  defp cookie_header(cookies, host) do
    cookies
    |> Map.values()
    |> Enum.filter(&cookie_matches?(&1.domain, host))
    |> Enum.map_join("; ", fn cookie -> "#{cookie.name}=#{cookie.value}" end)
  end

  defp merge_cookies(cookies, host, response) do
    response
    |> Req.Response.get_header("set-cookie")
    |> Enum.reduce(cookies, fn header, acc ->
      case parse_cookie(header, host) do
        nil -> acc
        cookie -> Map.put(acc, {cookie.domain, cookie.name}, cookie)
      end
    end)
  end

  defp parse_cookie(header, host) do
    [first | attributes] = String.split(header, ";")

    with [name, value] <- String.split(first, "=", parts: 2),
         name <- String.trim(name),
         value <- String.trim(value),
         true <- name != "" do
      domain =
        attributes
        |> Enum.find_value(host, fn attribute ->
          case String.split(String.trim(attribute), "=", parts: 2) do
            [key, value] ->
              if String.downcase(key) == "domain" do
                value |> String.trim() |> String.trim_leading(".") |> String.downcase()
              end

            _other ->
              nil
          end
        end)

      %{name: name, value: value, domain: domain}
    else
      _invalid -> nil
    end
  end

  defp cookie_matches?(domain, host), do: host == domain or String.ends_with?(host, ".#{domain}")

  defp absolute_url("http" <> _rest = url, _base_url), do: url
  defp absolute_url(path, base_url), do: URI.merge(base_url, path) |> URI.to_string()

  defp html_unescape(value) do
    value
    |> decode_numeric_entities(~r/&#x([0-9a-fA-F]+);/, 16)
    |> decode_numeric_entities(~r/&#(\d+);/, 10)
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#039;", "'")
    |> String.replace("&#x2F;", "/")
  end

  defp decode_numeric_entities(value, pattern, base) do
    Regex.replace(pattern, value, fn _entity, code ->
      code |> String.to_integer(base) |> codepoint_to_utf8()
    end)
  end

  defp codepoint_to_utf8(codepoint), do: <<codepoint::utf8>>
end
