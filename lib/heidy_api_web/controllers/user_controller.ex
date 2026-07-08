defmodule HeidyApiWeb.UserController do
  use HeidyApiWeb, :controller

  alias HeidyApi.{Accounts, Credentials}

  @profile_fields [:name, :email, :course_id]

  @update_schema [
    name: [type: :string, max: 80],
    email: [
      type: :string,
      max: 160,
      format: {~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, "must be a valid email"}
    ],
    course_id: [type: :uuid]
  ]

  def show(conn, _params) do
    data(conn, current_user(conn))
  end

  def update(conn, params) do
    with {:ok, attrs} <-
           params
           |> Params.validate(@update_schema)
           |> Params.require_any(@profile_fields, "profile"),
         {:ok, user} <- Accounts.update_profile(current_user(conn), attrs) do
      data(conn, user)
    end
  end

  def delete(conn, _params) do
    :ok = Accounts.delete_account(current_user(conn))
    no_content(conn)
  end

  def delete_credential(conn, _params) do
    :ok = Credentials.revoke(current_user(conn))
    no_content(conn)
  end
end
