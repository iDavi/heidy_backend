defmodule HeidyApiWeb.SyncController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Usp.{Sync, SyncRun}

  @create_schema [
    credential_blob: [type: :string, required: true],
    sources: [type: {:array, :enum}, values: SyncRun.sources(), default: SyncRun.sources()],
    semester_id: [type: :uuid]
  ]

  def create(conn, params) do
    with {:ok, attrs} <- Params.validate(params, @create_schema),
         {:ok, run} <- Sync.start(current_user(conn), attrs) do
      data(conn, run, :accepted)
    end
  end

  def index(conn, params) do
    filters_schema = Params.pagination() ++ [status: [type: :enum, values: SyncRun.statuses()]]

    with {:ok, filters} <- Params.validate(params, filters_schema) do
      page(conn, Sync.list(current_user(conn), filters))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, run} <- Sync.fetch(current_user(conn), id) do
      data(conn, run)
    end
  end
end
