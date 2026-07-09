defmodule HeidyApi.Repo.Migrations.AddMoodleTaskProvenance do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :external_ref, :string
    end

    create unique_index(:tasks, [:user_id, :external_ref],
             where: "external_ref IS NOT NULL"
           )
  end
end
