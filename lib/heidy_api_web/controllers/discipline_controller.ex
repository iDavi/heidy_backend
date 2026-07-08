defmodule HeidyApiWeb.DisciplineController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Catalog

  def index(conn, params) do
    schema = Params.pagination() ++ [q: [type: :string, max: 80], unit_id: [type: :uuid]]

    with {:ok, filters} <- Params.validate(params, schema) do
      page(conn, Catalog.search_disciplines(filters, filters))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, discipline} <- Catalog.fetch_discipline(id) do
      data(conn, discipline)
    end
  end
end
