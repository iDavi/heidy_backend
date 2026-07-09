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

defmodule HeidyApi.Moodle.Course do
  @moduledoc "A course visible to the student in e-Disciplinas."

  @enforce_keys [:id, :title, :url]
  defstruct [:id, :title, :url]

  @type t :: %__MODULE__{id: pos_integer(), title: String.t(), url: String.t()}
end

defmodule HeidyApi.Moodle.Activity do
  @moduledoc "A read-only item published inside an e-Disciplinas course."

  @enforce_keys [:id, :title, :kind, :url]
  defstruct [:id, :title, :kind, :url]

  @type t :: %__MODULE__{
          id: pos_integer(),
          title: String.t(),
          kind: String.t(),
          url: String.t()
        }
end

defmodule HeidyApi.Moodle.CourseDetail do
  @moduledoc "A Moodle course and its published activities."

  @enforce_keys [:id, :title, :activities]
  defstruct [:id, :title, :activities]

  @type t :: %__MODULE__{id: pos_integer(), title: String.t(), activities: [Activity.t()]}
end

defmodule HeidyApi.Moodle.ActivityDetail do
  @moduledoc "Text content for a Moodle activity, read without write capabilities."

  @enforce_keys [:id, :title, :content]
  defstruct [:id, :title, :content, :links, :file]

  @type t :: %__MODULE__{
          id: pos_integer(),
          title: String.t(),
          content: String.t(),
          links: [%{label: String.t(), url: String.t()}],
          file: %{name: String.t(), mime: String.t(), data: String.t()} | nil
        }
end
