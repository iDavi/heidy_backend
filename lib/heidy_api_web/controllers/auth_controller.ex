defmodule HeidyApiWeb.AuthController do
  use HeidyApiWeb, :controller

  alias HeidyApi.{Accounts, Credentials}
  alias HeidyApiWeb.Serializer

  @login_schema [
    usp_username: [
      type: :string,
      required: true,
      format: {~r/^\d{6,10}$/, "must be a USP number"}
    ],
    envelope: [type: :map, required: true]
  ]

  @envelope_schema [
    key_id: [type: :string, required: true, max: 32],
    enc: [type: :string, required: true, max: 128],
    ciphertext: [type: :string, required: true, max: 512],
    encrypted_at: [type: :datetime, required: true]
  ]

  def login_key(conn, _params) do
    data(conn, Credentials.login_key())
  end

  def login(conn, params) do
    with {:ok, %{usp_username: username, envelope: envelope}} <- validate_login(params),
         {:ok, session} <- Accounts.login(username, envelope) do
      json(conn, %{
        data: %{
          user: Serializer.render(session.user),
          token: session.token,
          credential_blob: Serializer.render(session.credential_blob)
        }
      })
    end
  end

  def logout(conn, _params) do
    :ok = Accounts.logout(conn.assigns.current_token)
    no_content(conn)
  end

  defp validate_login(params) do
    with {:ok, %{envelope: envelope_params} = casted} <- Params.validate(params, @login_schema),
         {:ok, envelope} <- validate_envelope(envelope_params) do
      {:ok, %{casted | envelope: envelope}}
    end
  end

  defp validate_envelope(envelope_params) do
    case Params.validate(envelope_params, @envelope_schema) do
      {:ok, envelope} -> {:ok, envelope}
      {:error, _fields} = error -> Params.prefix_errors(error, "envelope")
    end
  end
end
