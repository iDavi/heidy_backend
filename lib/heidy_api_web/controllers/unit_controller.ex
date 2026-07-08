defmodule HeidyApiWeb.UnitController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Catalog

  def courses(conn, %{"id" => id} = params) do
    with {:ok, unit} <- Catalog.fetch_unit(id),
         {:ok, pagination} <- Params.validate(params, Params.pagination()) do
      page(conn, Catalog.list_courses(unit, pagination))
    end
  end
end
