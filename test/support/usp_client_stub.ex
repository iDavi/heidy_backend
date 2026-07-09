defmodule HeidyApi.UspClientStub do
  @moduledoc """
  A `HeidyApi.Usp.Client` for the contract suite. Accepts any credential
  except the reserved registration `000000`, and answers canned records
  shaped like real JupiterWeb data.
  """

  @behaviour HeidyApi.Usp.Client

  alias HeidyApi.Usp.{ClassSlot, EnrollmentRecord, Session, Student}

  @rejected_username "000000"

  @impl true
  def login(@rejected_username, _password), do: {:error, :invalid_credentials}
  def login(username, _password), do: {:ok, %Session{username: username, dwr_id: "stub-dwr"}}

  @impl true
  def fetch_student(%Session{username: username}) do
    {:ok,
     %Student{
       registration: username,
       name: "Estudante de Teste",
       course_name: "Bacharelado em Sistemas de Informação",
       course_code: "86200",
       program_code: "1",
       admitted_on: ~D[2024-01-26]
     }}
  end

  @impl true
  def fetch_schedule(%Session{}) do
    {:ok,
     [
       %ClassSlot{
         discipline_code: "ACH2016",
         class_code: "2026104",
         day_of_week: 2,
         starts_at: ~T[19:00:00],
         ends_at: ~T[20:45:00]
       }
     ]}
  end

  @impl true
  def list_periods(%Session{}), do: {:ok, ["20252", "20261"]}

  @impl true
  def fetch_enrollments(%Session{}, period) do
    {:ok,
     [
       %EnrollmentRecord{
         period: period,
         discipline_code: "ACH2016",
         discipline_name: "Inteligência Artificial",
         class_code: "2026104",
         category: "Obrigatória",
         status: "Matriculado"
       }
     ]}
  end
end
