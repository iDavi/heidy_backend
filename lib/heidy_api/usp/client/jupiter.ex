defmodule HeidyApi.Usp.Client.Jupiter do
  @moduledoc """
  The real `HeidyApi.Usp.Client` for JupiterWeb (`uspdigital.usp.br`).

  JupiterWeb is a classic JSP application: a cookie-authenticated form
  login, pages whose data arrives through DWR remoting, and no stable API
  contract. This module owns all of that mess:

  * `login/2` submits the `autenticar` form and detects success by the
    presence of the student menu (the same signal the browser flow uses).
  * Data reads go through `HeidyApi.Usp.Dwr` against the remoting endpoints
    the student pages themselves call, which return structured records —
    far sturdier than screen-scraping the rendered HTML tables.

  Sessions are in-memory only; nothing USP-side is ever persisted.
  """

  @behaviour HeidyApi.Usp.Client

  alias HeidyApi.Usp.{ClassSlot, Dwr, EnrollmentRecord, Session, Student}

  @base_url "https://uspdigital.usp.br/jupiterweb"
  @schedule_page "/jupiterweb/gradeHoraria?codmnu=4759"
  @results_page "/jupiterweb/listarResultadoConsolidacaoTabs?codmnu=4741"

  # The link that only renders on an authenticated student menu.
  @logged_in_marker "gradeHoraria?codmnu="

  @day_columns [seg: 1, ter: 2, qua: 3, qui: 4, sex: 5, sab: 6, dom: 7]

  @impl true
  def login(username, password) do
    with {:ok, session} <- seed_cookies(%Session{username: username}),
         {:ok, response, session} <-
           post_form(session, "/autenticar", codpes: username, senusu: password) do
      if authenticated?(response), do: start_dwr(session), else: {:error, :invalid_credentials}
    end
  end

  @impl true
  def fetch_student(%Session{} = session) do
    with {:ok, programs} <-
           dwr_call(
             session,
             @schedule_page,
             "ResumoEscolarPdfControleDWR",
             "obterProgramaEmissaoHE",
             [
               session.username
             ]
           ),
         %{} = program <- current_program(programs) do
      {:ok,
       %Student{
         registration: session.username,
         name: program["nompes"],
         course_name: program["nomcur"],
         course_code: program["codcur"],
         program_code: to_string(program["codpgm"]),
         admitted_on: parse_admission(program["dataingresso"])
       }}
    else
      nil -> {:error, :unavailable}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def fetch_schedule(%Session{} = session) do
    with {:ok, program_code} <- program_code(session),
         {:ok, rows} <-
           dwr_call(session, @schedule_page, "GradeHorariaControleDWR", "obterGradeHoraria", [
             session.username,
             program_code
           ]) do
      {:ok, Enum.flat_map(rows, &row_slots/1)}
    end
  end

  @impl true
  def list_periods(%Session{} = session) do
    with {:ok, rows} <-
           dwr_call(
             session,
             @results_page,
             "ResultadoConsolidacaoControleDWR",
             "listarPeriodoAluno",
             [
               session.username
             ]
           ) do
      {:ok, rows |> Enum.map(& &1["anosemmtr"]) |> Enum.filter(&is_binary/1)}
    end
  end

  @impl true
  def fetch_enrollments(%Session{} = session, period) do
    with {:ok, rows} <-
           dwr_call(
             session,
             @results_page,
             "ResultadoConsolidacaoControleDWR",
             "buscarResultadoConsolidacao",
             [session.username, period]
           ) do
      records =
        rows
        # Each enrollment iteration repeats the row; the highest sequence
        # number is the current state of that discipline/class pair.
        |> Enum.group_by(&{&1["coddis"], &1["codtur"]})
        |> Enum.map(fn {_key, versions} -> Enum.max_by(versions, & &1["numseqcsl"]) end)
        |> Enum.filter(&is_binary(&1["coddis"]))
        |> Enum.map(fn row ->
          %EnrollmentRecord{
            period: period,
            discipline_code: row["coddis"],
            discipline_name: row["nomdis"],
            class_code: row["codtur"],
            category: row["discrl"],
            status: row["dtlstamtr"]
          }
        end)

      {:ok, records}
    end
  end

  ## Login plumbing

  defp seed_cookies(session) do
    with {:ok, _response, session} <- request(session, :get, "/webLogin.jsp", []) do
      {:ok, session}
    end
  end

  defp authenticated?(%{body: body}) when is_binary(body),
    do: String.contains?(body, @logged_in_marker)

  defp authenticated?(_response), do: false

  defp start_dwr(session) do
    body = Dwr.call_body("__System", "generateId", [], @schedule_page, nil)

    with {:ok, response, session} <-
           request(session, :post, dwr_path("__System.generateId"), dwr_opts(body)),
         {:ok, dwr_id} when is_binary(dwr_id) <- Dwr.parse(response.body) do
      {:ok, %{session | dwr_id: dwr_id}}
    else
      _failure -> {:error, :unavailable}
    end
  end

  defp program_code(%Session{program_code: code}) when is_binary(code), do: {:ok, code}

  defp program_code(session) do
    with {:ok, student} <- fetch_student(session), do: {:ok, student.program_code}
  end

  # Programs come newest-first only by convention; prefer the active one.
  defp current_program(programs) when is_list(programs) do
    Enum.find(programs, &(&1["stapgm"] == "A")) || List.first(programs)
  end

  defp current_program(_other), do: nil

  defp parse_admission(nil), do: nil

  defp parse_admission(<<day::binary-2, "/", month::binary-2, "/", year::binary-4>> <> _rest) do
    case Date.from_iso8601("#{year}-#{month}-#{day}") do
      {:ok, date} -> date
      _invalid -> nil
    end
  end

  defp parse_admission(_other), do: nil

  ## Schedule plumbing

  defp row_slots(row) do
    with {:ok, starts_at} <- parse_time(row["horent"]),
         {:ok, ends_at} <- parse_time(row["horsai"]) do
      for {column, day_of_week} <- @day_columns,
          slot = parse_cell(row[Atom.to_string(column)]),
          slot != nil do
        %ClassSlot{
          discipline_code: elem(slot, 0),
          class_code: elem(slot, 1),
          day_of_week: day_of_week,
          starts_at: starts_at,
          ends_at: ends_at
        }
      end
    else
      _no_times -> []
    end
  end

  defp parse_time(<<hour::binary-2, ":", minute::binary-2>> <> _rest) do
    Time.new(String.to_integer(hour), String.to_integer(minute), 0)
  rescue
    ArgumentError -> :error
  end

  defp parse_time(_other), do: :error

  # A grid cell reads `$ACH2013-2026294-I` padded with spaces.
  defp parse_cell("$" <> cell) do
    case cell |> String.trim() |> String.split("-") do
      [discipline_code, class_code | _flags] -> {discipline_code, class_code}
      _unexpected -> nil
    end
  end

  defp parse_cell(_other), do: nil

  ## HTTP plumbing

  defp dwr_call(session, page, script, method, params) do
    body = Dwr.call_body(script, method, params, page, session.dwr_id)

    with {:ok, response, _session} <-
           request(session, :post, dwr_path("#{script}.#{method}"), dwr_opts(body)) do
      Dwr.parse(response.body)
    end
  end

  defp dwr_path(call), do: "/dwr/call/plaincall/#{call}.dwr"

  defp dwr_opts(body), do: [headers: [{"content-type", "text/plain"}], body: body]

  defp post_form(session, path, form) do
    request(session, :post, path, form: form)
  end

  defp request(%Session{} = session, method, path, opts) do
    request =
      Req.new(
        [
          method: method,
          url: @base_url <> path,
          redirect: false,
          retry: false,
          headers: [{"cookie", cookie_header(session.cookies)}]
        ] ++ opts ++ Application.get_env(:heidy_api, __MODULE__, [])
      )

    case Req.request(request) do
      {:ok, %Req.Response{} = response} ->
        {:ok, response, %{session | cookies: merge_cookies(session.cookies, response)}}

      {:error, _reason} ->
        {:error, :unavailable}
    end
  end

  defp cookie_header(cookies) do
    Enum.map_join(cookies, "; ", fn {name, value} -> "#{name}=#{value}" end)
  end

  defp merge_cookies(cookies, %Req.Response{} = response) do
    response
    |> Req.Response.get_header("set-cookie")
    |> Enum.reduce(cookies, fn header, acc ->
      case header |> String.split(";", parts: 2) |> hd() |> String.split("=", parts: 2) do
        [name, value] -> Map.put(acc, name, value)
        _malformed -> acc
      end
    end)
  end
end
