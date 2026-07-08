defmodule HeidyApi.Usp.Session do
  @moduledoc """
  A live, in-memory JupiterWeb session: the authentication cookies plus the
  ids DWR calls need. Never persisted — it exists only for the duration of
  one login or sync run.
  """

  @enforce_keys [:username]
  defstruct [:username, :dwr_id, :program_code, cookies: %{}]

  @type t :: %__MODULE__{
          username: String.t(),
          dwr_id: String.t() | nil,
          program_code: String.t() | nil,
          cookies: %{optional(String.t()) => String.t()}
        }
end

defmodule HeidyApi.Usp.Student do
  @moduledoc "What USP tells us about the logged-in student."

  @enforce_keys [:registration, :name]
  defstruct [:registration, :name, :course_name, :course_code, :program_code, :admitted_on]

  @type t :: %__MODULE__{
          registration: String.t(),
          name: String.t(),
          course_name: String.t() | nil,
          course_code: String.t() | nil,
          program_code: String.t() | nil,
          admitted_on: Date.t() | nil
        }
end

defmodule HeidyApi.Usp.ClassSlot do
  @moduledoc "One cell of the JupiterWeb schedule grid, already normalized."

  @enforce_keys [:discipline_code, :class_code, :day_of_week, :starts_at, :ends_at]
  defstruct [:discipline_code, :class_code, :day_of_week, :starts_at, :ends_at]

  @type t :: %__MODULE__{
          discipline_code: String.t(),
          class_code: String.t(),
          day_of_week: 1..7,
          starts_at: Time.t(),
          ends_at: Time.t()
        }
end

defmodule HeidyApi.Usp.EnrollmentRecord do
  @moduledoc "One discipline the student is (or was) enrolled in for a period."

  @enforce_keys [:period, :discipline_code, :discipline_name]
  defstruct [:period, :discipline_code, :discipline_name, :class_code, :category, :status]

  @type t :: %__MODULE__{
          period: String.t(),
          discipline_code: String.t(),
          discipline_name: String.t(),
          class_code: String.t() | nil,
          category: String.t() | nil,
          status: String.t() | nil
        }
end
