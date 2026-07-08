defmodule HeidyApiWeb.UniversityController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Catalog

  def index(conn, params) do
    schema = Params.pagination() ++ [q: [type: :string, max: 80]]

    with {:ok, filters} <- Params.validate(params, schema) do
      page(conn, Catalog.search_universities(filters[:q], filters))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, university} <- Catalog.fetch_university(id) do
      data(conn, university)
    end
  end

  def units(conn, %{"id" => id} = params) do
    with {:ok, university} <- Catalog.fetch_university(id),
         {:ok, pagination} <- Params.validate(params, Params.pagination()) do
      page(conn, Catalog.list_units(university, pagination))
    end
  end
end
