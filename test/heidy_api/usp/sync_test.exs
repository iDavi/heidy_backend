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

    test "a manual enrollment already holding the class's title does not crash the sync" do
      user = user_fixture(%{usp_username: "7654325"})

      semester =
        semester_fixture(user, %{
          label: "2026.1",
          start_date: ~D[2026-02-01],
          end_date: ~D[2026-07-15]
        })

      manual =
        enrollment_fixture(user, %{
          semester: semester,
          title: "ACH2016",
          source: "manual",
          external_ref: "manual-ref"
        })

      {:ok, run} = Sync.start(user, %{credential_blob: "stub-blob", sources: ["schedule"]})

      assert %SyncRun{status: "succeeded", counts: %{"schedule" => 1}} =
               Sync.perform(run, user, "stub-password")

      assert Repo.aggregate(Enrollment, :count) == 1
      assert %Enrollment{source: "manual"} = Repo.get!(Enrollment, manual.id)
    end

    test "perform marks the run failed instead of crashing on an unexpected error" do
      user = user_fixture(%{usp_username: "7654326"})
      {:ok, run} = Sync.start(user, %{credential_blob: "stub-blob", sources: ["schedule"]})

      # A user_id that isn't backed by an actual row makes the semester
      # insert hit an undeclared foreign_key_constraint and raise - the
      # kind of unexpected failure perform/3 must still resolve to a
      # terminal status on, rather than crash and leave the run "running".
      bogus_user = %{user | id: HeidyApi.Ids.generate()}

      assert %SyncRun{status: "failed", error: error} =
               Sync.perform(run, bogus_user, "stub-password")

      assert error =~ "Sync failed"
    end
  end
end
