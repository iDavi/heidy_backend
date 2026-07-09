defmodule HeidyApi.Moodle.Session do
  @moduledoc """
  A live e-Disciplinas browser session.

  Cookies are scoped by host and only exist while a sync task is running.
  """

  @enforce_keys [:username]
  defstruct [:username, cookies: %{}]

  @type cookie :: %{value: String.t(), domain: String.t()}
  @type t :: %__MODULE__{username: String.t(), cookies: %{optional(String.t()) => cookie()}}
end

defmodule HeidyApi.Moodle.Assignment do
  @moduledoc "A dated e-Disciplinas calendar event normalized for the planner."

  @enforce_keys [:external_ref, :title]
  defstruct [:external_ref, :title, :course_name, :due_at, :url, kind: "assignment"]

  @type kind :: String.t()
  @type t :: %__MODULE__{
          external_ref: String.t(),
          title: String.t(),
          course_name: String.t() | nil,
          due_at: DateTime.t() | nil,
          url: String.t() | nil,
          kind: kind()
        }
end
