defmodule HeidyApi.OpenApi.ReadableContractTest do
  use ExUnit.Case, async: true

  @spec_path Path.expand("../../slop/openapi.json", __DIR__)

  @readable_operations [
    {"GET", "/health", "returns liveness/readiness"},
    {"GET", "/auth/login-key", "returns the current HPKE login public key"},
    {"POST", "/auth/login", "verifies USP credentials and returns a session"},
    {"DELETE", "/auth/logout", "revokes the current bearer token"},
    {"GET", "/me", "returns the current user profile"},
    {"PATCH", "/me", "updates the current user profile"},
    {"DELETE", "/me", "deletes the current account"},
    {"DELETE", "/me/credential", "revokes every credential blob"},
    {"GET", "/usp/sync", "lists recent sync runs"},
    {"POST", "/usp/sync", "starts a USP sync run"},
    {"GET", "/usp/sync/{id}", "polls a USP sync run"},
    {"GET", "/semesters", "lists semesters"},
    {"POST", "/semesters", "creates a semester"},
    {"GET", "/semesters/{id}", "returns a semester"},
    {"PATCH", "/semesters/{id}", "updates a semester"},
    {"DELETE", "/semesters/{id}", "deletes a semester"},
    {"GET", "/enrollments", "lists classes"},
    {"POST", "/enrollments", "adds a class"},
    {"GET", "/enrollments/{id}", "returns class details"},
    {"PATCH", "/enrollments/{id}", "updates a class"},
    {"DELETE", "/enrollments/{id}", "removes a class"},
    {"GET", "/enrollments/{id}/meetings", "lists class meetings"},
    {"POST", "/enrollments/{id}/meetings", "adds a class meeting"},
    {"PATCH", "/meetings/{id}", "updates a class meeting"},
    {"DELETE", "/meetings/{id}", "removes a class meeting"},
    {"GET", "/schedule", "returns a computed weekly schedule"},
    {"GET", "/tasks", "lists tasks"},
    {"POST", "/tasks", "creates a task"},
    {"GET", "/tasks/{id}", "returns a task"},
    {"PATCH", "/tasks/{id}", "updates a task"},
    {"DELETE", "/tasks/{id}", "deletes a task"},
    {"PATCH", "/tasks/{id}/status", "transitions task status"},
    {"GET", "/enrollments/{id}/grades", "lists class grades"},
    {"POST", "/enrollments/{id}/grades", "adds a grade"},
    {"GET", "/enrollments/{id}/grades/summary", "returns grade summary"},
    {"PATCH", "/grades/{id}", "updates a grade"},
    {"DELETE", "/grades/{id}", "deletes a grade"},
    {"GET", "/enrollments/{id}/absences", "lists class absences"},
    {"POST", "/enrollments/{id}/absences", "logs an absence"},
    {"GET", "/enrollments/{id}/absences/summary", "returns attendance summary"},
    {"DELETE", "/absences/{id}", "removes an absence"},
    {"GET", "/universities", "lists/searches universities"},
    {"GET", "/universities/{id}", "returns a university"},
    {"GET", "/universities/{id}/units", "lists university units"},
    {"GET", "/units/{id}/courses", "lists unit courses"},
    {"GET", "/disciplines", "searches disciplines"},
    {"GET", "/disciplines/{id}", "returns a discipline"}
  ]

  test "every OpenAPI operation has a readable route spec" do
    openapi_operations =
      @spec_path
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("paths")
      |> Enum.flat_map(fn {path, operations} ->
        operations
        |> Map.keys()
        |> Enum.reject(&(&1 == "parameters"))
        |> Enum.map(&{String.upcase(&1), path})
      end)
      |> MapSet.new()

    readable_operations =
      @readable_operations
      |> Enum.map(fn {method, path, _description} -> {method, path} end)
      |> MapSet.new()

    assert MapSet.difference(openapi_operations, readable_operations) == MapSet.new()
    assert MapSet.difference(readable_operations, openapi_operations) == MapSet.new()
  end

  test "readable route specs use plain descriptions" do
    for {_method, _path, description} <- @readable_operations do
      assert description =~ ~r/^[a-z]/
      refute description =~ "$ref"
      refute description =~ "operationId"
    end
  end
end
