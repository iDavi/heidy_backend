defmodule HeidyApi.AccountsTest do
  use HeidyApi.DataCase, async: true

  alias HeidyApi.Accounts
  alias HeidyApi.Accounts.{Session, User}
  alias HeidyApi.Credentials.CredentialKey

  describe "login/2" do
    test "creates or updates a user, returns an opaque token, and stores only its hash" do
      assert {:ok, session} = Accounts.login("1234567", login_envelope())

      assert %User{usp_username: "1234567", name: "Estudante de Teste"} = session.user
      assert is_binary(session.token)
      assert {:ok, %User{id: user_id}} = Accounts.fetch_user_by_token(session.token)
      assert user_id == session.user.id

      stored_session = Repo.one!(Session)
      refute stored_session.token_hash == session.token
      assert String.length(stored_session.token_hash) == 64
    end

    test "rejects invalid USP credentials without creating a user" do
      assert {:error, :unauthorized} = Accounts.login("000000", login_envelope())
      refute Repo.get_by(User, usp_username: "000000")
    end
  end

  describe "sessions" do
    test "logout deletes the hashed session token" do
      {:ok, session} = Accounts.login("1234568", login_envelope())

      assert :ok = Accounts.logout(session.token)
      assert {:error, :unauthorized} = Accounts.fetch_user_by_token(session.token)
      assert Repo.aggregate(Session, :count) == 0
    end

    test "demo token resolves to a persisted demo user" do
      assert {:ok, user} = Accounts.fetch_user_by_token("test-token")
      assert user.usp_username == "1234567"
      assert Repo.get(User, user.id)
    end
  end

  describe "profile and account lifecycle" do
    test "profile updates are validated by the user changeset" do
      user = user_fixture()

      assert {:error, {:validation, fields}} =
               Accounts.update_profile(user, %{
                 email: "not-an-email",
                 name: String.duplicate("x", 121)
               })

      assert Map.has_key?(fields, :email)
      assert Map.has_key?(fields, :name)
    end

    test "delete_account removes the user and dependent persistence state" do
      {:ok, session} = Accounts.login("1234569", login_envelope())
      {:ok, user} = Accounts.fetch_user_by_token(session.token)
      assert Repo.get(CredentialKey, user.id)

      assert :ok = Accounts.delete_account(user)

      refute Repo.get(User, user.id)
      refute Repo.get(CredentialKey, user.id)
      assert Repo.aggregate(Session, :count) == 0
    end
  end

  defp login_envelope do
    %{
      key_id: "k1",
      enc: "base64enc",
      ciphertext: "base64ciphertext",
      encrypted_at: ~U[2026-07-08 12:00:00Z]
    }
  end
end
