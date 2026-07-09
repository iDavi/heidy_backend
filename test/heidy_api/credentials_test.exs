defmodule HeidyApi.CredentialsTest do
  use HeidyApi.DataCase, async: false

  alias HeidyApi.Credentials
  alias HeidyApi.Credentials.CredentialKey

  describe "credential blobs" do
    setup do
      previous_vault = Application.fetch_env!(:heidy_api, :vault)
      Application.put_env(:heidy_api, :vault, HeidyApi.Credentials.Vault.Local)

      on_exit(fn ->
        Application.put_env(:heidy_api, :vault, previous_vault)
      end)

      :ok
    end

    test "stores per-user key metadata, not the secret, and can reopen issued blobs" do
      user = user_fixture()

      assert {:ok, blob} = Credentials.issue_blob(user, "senha-unica")
      assert {:ok, "senha-unica"} = Credentials.open_blob(user, blob.blob)

      key_record = Repo.get!(CredentialKey, user.id)
      assert key_record.version == 1
      refute key_record.key == "senha-unica"
    end

    test "revoke rotates the per-user key so old blobs fail closed" do
      user = user_fixture()
      {:ok, blob} = Credentials.issue_blob(user, "senha-unica")
      old_key = Repo.get!(CredentialKey, user.id)

      assert :ok = Credentials.revoke(user)

      rotated_key = Repo.get!(CredentialKey, user.id)
      assert rotated_key.version == old_key.version + 1
      refute rotated_key.key == old_key.key
      assert {:error, :invalid} = Credentials.open_blob(user, blob.blob)
    end
  end
end
