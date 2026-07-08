defmodule HeidyApiWeb.Responses do
  @moduledoc "The three response envelopes of the API, plus 204."

  import Plug.Conn, only: [put_status: 2, send_resp: 3]
  import Phoenix.Controller, only: [json: 2]

  alias HeidyApi.Page
  alias HeidyApiWeb.Serializer

  @doc "Renders a single resource: `{\"data\": {...}}`."
  @spec data(Plug.Conn.t(), term(), atom() | pos_integer()) :: Plug.Conn.t()
  def data(conn, resource, status \\ :ok) do
    conn |> put_status(status) |> json(%{data: Serializer.render(resource)})
  end

  @doc "Renders a paginated list: `{\"data\": [...], \"meta\": {...}}`."
  @spec page(Plug.Conn.t(), Page.t()) :: Plug.Conn.t()
  def page(conn, %Page{} = page) do
    json(conn, %{
      data: Serializer.render(page.items),
      meta: %{page: page.page, page_size: page.page_size, total: page.total}
    })
  end

  @doc "Renders a small, non-paginated collection: `{\"data\": [...]}`."
  @spec collection(Plug.Conn.t(), [term()]) :: Plug.Conn.t()
  def collection(conn, items) when is_list(items) do
    json(conn, %{data: Serializer.render(items)})
  end

  @spec no_content(Plug.Conn.t()) :: Plug.Conn.t()
  def no_content(conn), do: send_resp(conn, :no_content, "")
end
