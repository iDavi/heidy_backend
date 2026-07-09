defmodule HeidyApi.Usp.SyncTest do
  use HeidyApi.DataCase, async: true

  alias HeidyApi.Planner.{Enrollment, Meeting, Semester}
  alias HeidyApi.Usp.{Sync, SyncRun}

  describe "sync runs" do
    test "start persists a pending run that can be fetched and listed" do
      user = user_fixture(%{usp_username: "7654321"})

      assert {:ok, %SyncRun{} = run} =
               Sync.start(user, %{credential_blob: "stub-blob", sources: ["schedule"]})

      assert run.status == "pending"
      assert {:ok, fetched} = Sync.fetch(user, run.id)
      assert fetched.id == run.id

      page = Sync.list(user, %{page: 1, page_size: 10})
      assert Enum.map(page.items, & &1.id) == [run.id]
    end

    test "start rejects a second active run for the same user" do
      user = user_fixture(%{usp_username: "7654322"})

      assert {:ok, _run} =
               Sync.start(user, %{credential_blob: "stub-blob", sources: ["schedule"]})

      assert {:error, {:conflict, detail}} =
               Sync.start(user, %{credential_blob: "stub-blob", sources: ["schedule"]})

      assert detail =~ "already running"
    end

    test "perform imports schedule rows and re-syncs without duplicating external refs" do
      user = user_fixture(%{usp_username: "7654323"})
      {:ok, run} = Sync.start(user, %{credential_blob: "stub-blob", sources: ["schedule"]})

      assert %SyncRun{status: "succeeded", counts: %{"schedule" => 1}} =
               Sync.perform(run, user, "stub-password")

      assert Repo.aggregate(Semester, :count) == 1
      assert Repo.aggregate(Enrollment, :count) == 1
      assert Repo.aggregate(Meeting, :count) == 1

      assert %Enrollment{source: "usp", external_ref: "ACH2016-2026104"} = Repo.one!(Enrollment)

      assert %SyncRun{status: "succeeded", counts: %{"schedule" => 1}} =
               Sync.perform(Repo.get!(SyncRun, run.id), user, "stub-password")

      assert Repo.aggregate(Semester, :count) == 1
      assert Repo.aggregate(Enrollment, :count) == 1
      assert Repo.aggregate(Meeting, :count) == 1
    end

    test "manual enrollments with the same external_ref are not overwritten by sync" do
      user = user_fixture(%{usp_username: "7654324"})
      semester = semester_fixture(user)

      manual =
        enrollment_fixture(user, %{
          semester: semester,
          title: "Manual title",
          source: "manual",
          external_ref: "ACH2016-2026104"
        })

      {:ok, run} = Sync.start(user, %{credential_blob: "stub-blob", sources: ["schedule"]})
      Sync.perform(run, user, "stub-password")

      assert Repo.get!(Enrollment, manual.id).title == "Manual title"
      assert Repo.aggregate(Enrollment, :count) == 1
    end
  end
end
