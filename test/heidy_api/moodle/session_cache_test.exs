defmodule HeidyApi.Moodle.SessionCacheTest do
  use ExUnit.Case, async: false

  alias HeidyApi.Moodle.{Session, SessionCache}

  test "keeps a Moodle session only in memory" do
    key = :crypto.strong_rand_bytes(32)
    session = %Session{username: "1234567"}

    assert :miss = SessionCache.fetch(key)
    assert :ok = SessionCache.put(key, session)
    assert {:ok, ^session} = SessionCache.fetch(key)
    assert :ok = SessionCache.delete(key)
    assert :miss = SessionCache.fetch(key)
  end
end
