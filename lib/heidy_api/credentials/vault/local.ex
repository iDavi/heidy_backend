defmodule HeidyApi.Credentials.Vault.Local do
  @moduledoc """
  A single-node `HeidyApi.Credentials.Vault` built on OTP `:crypto`.

  * Login envelopes: HPKE-style — X25519 ECDH against the node keypair,
    HKDF-SHA256, AES-256-GCM.
  * Credential blobs: a fresh content key (CEK) encrypts the credential;
    the CEK is wrapped under the per-user vault key. User id, key version
    and issue time are bound into the AAD, so a blob is useless for any
    other user and expires after #{90} days.

  The node keypair lives only in memory (`:persistent_term`), which is the
  right shape for a dev/single-node deployment. The production hardening —
  a KMS-held decapsulation key as the outer wrap — replaces this module
  behind the same behaviour.
  """

  @behaviour HeidyApi.Credentials.Vault

  alias HeidyApi.Credentials.{Blob, LoginKey}

  @hkdf_info "heidy-login-v1"
  @blob_version 1
  @max_age_days 90

  @impl true
  def login_key do
    {public, _private} = keypair()

    %LoginKey{
      key_id: key_id(public),
      alg: "HPKE-Base(X25519, HKDF-SHA256, AES-256-GCM)",
      public_key: Base.encode64(public)
    }
  end

  @impl true
  def open_envelope(%{enc: enc, ciphertext: ciphertext}) do
    {_public, private} = keypair()

    with {:ok, ephemeral_public} <- Base.decode64(enc),
         {:ok, <<nonce::binary-12, sealed::binary>>} <- Base.decode64(ciphertext),
         shared = :crypto.compute_key(:ecdh, ephemeral_public, private, :x25519),
         key = hkdf(shared, @hkdf_info),
         {:ok, secret} <- aes_gcm_decrypt(key, nonce, sealed, @hkdf_info) do
      {:ok, secret}
    else
      _mismatch -> {:error, :invalid_envelope}
    end
  end

  @impl true
  def seal(user_key, context, secret) do
    issued_at = DateTime.utc_now(:second)
    aad = aad(context, issued_at)
    cek = :crypto.strong_rand_bytes(32)

    payload = %{
      v: @blob_version,
      iat: DateTime.to_iso8601(issued_at),
      ct: aes_gcm_encrypt(cek, secret, aad) |> Base.encode64(),
      wck: aes_gcm_encrypt(user_key, cek, aad) |> Base.encode64()
    }

    blob = payload |> Jason.encode!() |> Base.url_encode64(padding: false)
    {:ok, %Blob{blob: blob, expires_at: DateTime.add(issued_at, @max_age_days, :day)}}
  end

  @impl true
  def unseal(user_key, context, blob) do
    with {:ok, json} <- Base.url_decode64(blob, padding: false),
         {:ok, %{"v" => @blob_version, "iat" => iat, "ct" => ct, "wck" => wck}} <-
           Jason.decode(json),
         {:ok, issued_at, _offset} <- DateTime.from_iso8601(iat),
         :ok <- check_age(issued_at),
         aad = aad(context, issued_at),
         {:ok, encoded_wck} <- Base.decode64(wck),
         {:ok, encoded_ct} <- Base.decode64(ct),
         {:ok, cek} <- open_gcm(user_key, encoded_wck, aad),
         {:ok, secret} <- open_gcm(cek, encoded_ct, aad) do
      {:ok, secret}
    else
      {:error, :expired} -> {:error, :expired}
      _mismatch -> {:error, :invalid}
    end
  end

  defp check_age(issued_at) do
    if DateTime.diff(DateTime.utc_now(), issued_at, :day) < @max_age_days,
      do: :ok,
      else: {:error, :expired}
  end

  defp aad(%{user_id: user_id, key_version: version}, issued_at) do
    "#{user_id}:#{version}:#{DateTime.to_iso8601(issued_at)}"
  end

  defp aes_gcm_encrypt(key, plaintext, aad) do
    nonce = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, aad, true)

    nonce <> ciphertext <> tag
  end

  defp open_gcm(key, <<nonce::binary-12, rest::binary>>, aad) when byte_size(rest) >= 16 do
    aes_gcm_decrypt(key, nonce, rest, aad)
  end

  defp open_gcm(_key, _sealed, _aad), do: {:error, :invalid}

  defp aes_gcm_decrypt(key, nonce, sealed, aad) do
    payload_size = byte_size(sealed) - 16
    <<ciphertext::binary-size(payload_size), tag::binary-16>> = sealed

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, aad, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :invalid}
    end
  end

  defp hkdf(ikm, info) do
    prk = :crypto.mac(:hmac, :sha256, <<0::256>>, ikm)
    :crypto.mac(:hmac, :sha256, prk, info <> <<1>>)
  end

  defp key_id(public) do
    :sha256 |> :crypto.hash(public) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  defp keypair do
    case :persistent_term.get({__MODULE__, :keypair}, nil) do
      nil ->
        keypair = :crypto.generate_key(:ecdh, :x25519)
        :persistent_term.put({__MODULE__, :keypair}, keypair)
        keypair

      keypair ->
        keypair
    end
  end
end
