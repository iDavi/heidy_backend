defmodule HeidyApi.Moodle.Client.Ediciplinas do
  @moduledoc """
  e-Disciplinas client using USP's SAML single-sign-on flow.

  Moodle exposes its own authenticated calendar endpoint. The client performs
  the browser flow in memory, calls that endpoint, and keeps no credential or
  cookie after the sync process ends.
  """

  @behaviour HeidyApi.Moodle.Client

  alias HeidyApi.Moodle.{Assignment, Session}

  @moodle_url "https://edisciplinas.usp.br"
  @login_url @moodle_url <> "/auth/shibboleth"
  @calendar_url @moodle_url <> "/lib/ajax/service.php"
  @max_redirects 8

  @impl true
  def login(username, password) do
    with {:ok, response, session} <- request(%Session{username: username}, :get, @login_url, []),
         {:ok, idp_url} <- location(response),
         {:ok, idp_page, session} <- request(session, :get, idp_url, []),
         {:ok, form_url} <- form_action(idp_page.body, idp_url),
         {:ok, response, session} <-
           request(session, :post, form_url,
             form: [j_username: username, j_password: password, _eventId_proceed: "Login"]
           ),
         {:ok, session} <- complete_saml(session, response, 0),
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
    with {:ok, dashboard, session} <- request(session, :get, @moodle_url <> "/my/", []),
         {:ok, sesskey} <- sesskey(dashboard.body),
         {:ok, response, _session} <-
           request(
             session,
             :post,
             @calendar_url <>
               "?sesskey=#{URI.encode_www_form(sesskey)}&info=core_calendar_get_calendar_events",
             headers: [{"content-type", "application/json"}],
             body: Jason.encode!(calendar_request())
           ),
         {:ok, payload} <- Jason.decode(response.body) do
      {:ok, assignments_from_payload(payload)}
    else
      _failure -> {:error, :unavailable}
    end
  end

  @doc false
  @spec assignments_from_payload(term()) :: [Assignment.t()]
  def assignments_from_payload([%{"error" => false, "data" => %{"events" => events}} | _])
      when is_list(events) do
    events
    |> Enum.map(&assignment_from_event/1)
    |> Enum.reject(&is_nil/1)
  end

  def assignments_from_payload(_payload), do: []

  defp complete_saml(session, response, redirects) when redirects < @max_redirects do
    cond do
      response.status in 300..399 ->
        with {:ok, redirect_url} <- location(response),
             {:ok, response, session} <- request(session, :get, redirect_url, []) do
          complete_saml(session, response, redirects + 1)
        end

      saml_form = saml_form(response.body) ->
        {url, fields} = saml_form

        with {:ok, response, session} <- request(session, :post, url, form: fields) do
          complete_saml(session, response, redirects + 1)
        end

      true ->
        {:ok, session}
    end
  end

  defp complete_saml(_session, _response, _redirects), do: {:error, :unavailable}

  defp calendar_request do
    now = DateTime.utc_now() |> DateTime.to_unix()
    in_six_months = DateTime.add(DateTime.utc_now(), 183, :day) |> DateTime.to_unix()

    [
      %{
        index: 0,
        methodname: "core_calendar_get_calendar_events",
        args: %{
          events: %{eventids: [], courseids: [], groupids: [], userids: []},
          options: %{
            userevents: true,
            siteevents: false,
            timestart: now,
            timeend: in_six_months,
            ignorehidden: true
          }
        }
      }
    ]
  end

  defp assignment_from_event(%{"id" => id, "name" => title} = event)
       when is_integer(id) and is_binary(title) do
    %Assignment{
      external_ref: "moodle:event:#{id}",
      title: title,
      course_name: course_name(event),
      due_at: event_time(event),
      url: Map.get(event, "url"),
      kind: event_kind(event)
    }
  end

  defp assignment_from_event(_event), do: nil

  defp course_name(%{"course" => %{"fullname" => name}}) when is_binary(name), do: name
  defp course_name(%{"coursefullname" => name}) when is_binary(name), do: name
  defp course_name(_event), do: nil

  defp event_time(event) do
    timestamp = Map.get(event, "timesort") || Map.get(event, "timestart")

    if is_integer(timestamp) and timestamp > 0 do
      DateTime.from_unix!(timestamp)
    end
  rescue
    ArgumentError -> nil
  end

  defp event_kind(event) do
    event
    |> Map.get("modulename", Map.get(event, "activityname", ""))
    |> to_string()
    |> String.downcase()
    |> case do
      "assign" -> "assignment"
      "assignment" -> "assignment"
      "quiz" -> "exam"
      "workshop" -> "project"
      "book" -> "reading"
      "page" -> "reading"
      _other -> "other"
    end
  end

  defp authenticated?(%{body: body}) when is_binary(body) do
    String.contains?(body, "login/logout.php") or String.contains?(body, "data-userid=")
  end

  defp authenticated?(_response), do: false

  defp sesskey(body) do
    case Regex.run(~r/["']sesskey["']\s*[:=]\s*["']([^"']+)/, body) do
      [_, key] -> {:ok, html_unescape(key)}
      _none -> {:error, :unavailable}
    end
  end

  defp form_action(body, base_url) do
    case Regex.run(~r/<form\b[^>]*\baction=["']([^"']+)/i, body) do
      [_, action] -> {:ok, absolute_url(html_unescape(action), base_url)}
      _none -> {:error, :unavailable}
    end
  end

  defp saml_form(body) when is_binary(body) do
    with {:ok, url} <- form_action(body, @moodle_url),
         true <- String.contains?(body, "SAMLResponse"),
         fields when fields != [] <- hidden_fields(body) do
      {url, fields}
    else
      _failure -> nil
    end
  end

  defp saml_form(_body), do: nil

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

  defp location(response) do
    case Req.Response.get_header(response, "location") do
      [location | _] -> {:ok, html_unescape(location)}
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
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#039;", "'")
    |> String.replace("&#x2F;", "/")
  end
end
