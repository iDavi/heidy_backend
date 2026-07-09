defmodule HeidyApi.Repo.Migrations.CreatePersistence do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :usp_username, :string, null: false
      add :name, :string
      add :email, :string
      add :course_id, :uuid

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:usp_username])

    create table(:sessions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sessions, [:token_hash])
    create index(:sessions, [:user_id])
    create index(:sessions, [:expires_at])

    create table(:credential_keys, primary_key: false) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), primary_key: true
      add :key, :binary, null: false
      add :version, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create table(:semesters, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :label, :string, null: false
      add :start_date, :date
      add :end_date, :date
      add :active, :boolean, null: false, default: true
      add :source, :string, null: false, default: "manual"
      add :external_ref, :string

      timestamps(type: :utc_datetime)
    end

    create index(:semesters, [:user_id])
    create unique_index(:semesters, [:user_id, :external_ref], where: "external_ref IS NOT NULL")

    create table(:enrollments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :semester_id, references(:semesters, type: :uuid, on_delete: :delete_all), null: false
      add :discipline_id, :uuid
      add :title, :string
      add :professor, :string
      add :credits, :integer
      add :color, :string
      add :absence_limit, :integer
      add :source, :string, null: false, default: "manual"
      add :external_ref, :string

      timestamps(type: :utc_datetime)
    end

    create index(:enrollments, [:user_id])
    create index(:enrollments, [:semester_id])
    create unique_index(:enrollments, [:user_id, :external_ref], where: "external_ref IS NOT NULL")

    create table(:meetings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :enrollment_id, references(:enrollments, type: :uuid, on_delete: :delete_all), null: false
      add :day_of_week, :integer, null: false
      add :starts_at, :time, null: false
      add :ends_at, :time, null: false
      add :location, :string

      timestamps(type: :utc_datetime)
    end

    create index(:meetings, [:enrollment_id])

    create table(:tasks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :enrollment_id, references(:enrollments, type: :uuid, on_delete: :nilify_all)
      add :title, :string, null: false
      add :notes, :text
      add :due_at, :utc_datetime
      add :kind, :string, null: false, default: "assignment"
      add :status, :string, null: false, default: "todo"
      add :priority, :string, null: false, default: "normal"
      add :source, :string, null: false, default: "manual"

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:user_id])
    create index(:tasks, [:enrollment_id])

    create table(:grades, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :enrollment_id, references(:enrollments, type: :uuid, on_delete: :delete_all), null: false
      add :label, :string, null: false
      add :score, :float
      add :max_score, :float, null: false, default: 10.0
      add :weight, :float, null: false, default: 1.0
      add :source, :string, null: false, default: "manual"
      add :external_ref, :string

      timestamps(type: :utc_datetime)
    end

    create index(:grades, [:enrollment_id])

    create table(:absences, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :enrollment_id, references(:enrollments, type: :uuid, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :count, :integer, null: false, default: 1
      add :note, :string
      add :source, :string, null: false, default: "manual"
      add :external_ref, :string

      timestamps(type: :utc_datetime)
    end

    create index(:absences, [:enrollment_id])

    create table(:sync_runs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :sources, {:array, :string}, null: false
      add :semester_id, references(:semesters, type: :uuid, on_delete: :nilify_all)
      add :status, :string, null: false, default: "pending"
      add :counts, :map, null: false, default: %{}
      add :error, :string
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:sync_runs, [:user_id])
  end
end
