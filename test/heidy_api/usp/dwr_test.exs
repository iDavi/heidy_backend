defmodule HeidyApi.Usp.DwrTest do
  use ExUnit.Case, async: true

  alias HeidyApi.Usp.Dwr

  test "builds plaincall request bodies with encoded page and DWR session" do
    body = Dwr.call_body("Aluno", "listar", ["123", "abc"], "/jupiter?x=1", "server-session")

    assert body =~ "callCount=1"
    assert body =~ "c0-scriptName=Aluno"
    assert body =~ "c0-methodName=listar"
    assert body =~ "c0-param0=string:123"
    assert body =~ "c0-param1=string:abc"
    assert body =~ "page=%2Fjupiter%3Fx%3D1"
    assert body =~ "scriptSessionId=server-session/heidy-"
  end

  test "parses DWR callback object literals into Elixir data" do
    body = ~S"""
    //#DWR-INSERT
    (function(){
    handleCallback("0","0",{nome:"Ana",ativo:true,notas:[{valor:8.5,data:new Date(42)}]});
    })();
    """

    assert {:ok,
            %{"nome" => "Ana", "ativo" => true, "notas" => [%{"valor" => 8.5, "data" => 42}]}} =
             Dwr.parse(body)
  end

  test "reports remote exceptions and unrecognized replies" do
    assert {:error, {:dwr, "remote exception"}} = Dwr.parse("handleException()")
    assert {:error, {:dwr, "unrecognized reply"}} = Dwr.parse("plain text")
  end
end
