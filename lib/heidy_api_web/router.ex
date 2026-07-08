defmodule HeidyApiWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug HeidyApiWeb.Auth
  end

  scope "/api/v1", HeidyApiWeb do
    pipe_through :api

    get "/health", HealthController, :show
    get "/auth/login-key", AuthController, :login_key
    post "/auth/login", AuthController, :login

    scope "/" do
      pipe_through :authenticated

      delete "/auth/logout", AuthController, :logout

      get "/me", UserController, :show
      patch "/me", UserController, :update
      delete "/me", UserController, :delete
      delete "/me/credential", UserController, :delete_credential

      post "/usp/sync", SyncController, :create
      get "/usp/sync", SyncController, :index
      get "/usp/sync/:id", SyncController, :show

      get "/universities", UniversityController, :index
      get "/universities/:id", UniversityController, :show
      get "/universities/:id/units", UniversityController, :units
      get "/units/:id/courses", UnitController, :courses
      get "/disciplines", DisciplineController, :index
      get "/disciplines/:id", DisciplineController, :show

      get "/schedule", ScheduleController, :show

      resources "/semesters", SemesterController, except: [:new, :edit]

      resources "/enrollments", EnrollmentController, except: [:new, :edit] do
        post "/meetings", MeetingController, :create
        get "/meetings", MeetingController, :index
        post "/grades", GradeController, :create
        get "/grades", GradeController, :index
        get "/grades/summary", GradeController, :summary
        post "/absences", AbsenceController, :create
        get "/absences", AbsenceController, :index
        get "/absences/summary", AbsenceController, :summary
      end

      patch "/meetings/:id", MeetingController, :update
      delete "/meetings/:id", MeetingController, :delete
      patch "/grades/:id", GradeController, :update
      delete "/grades/:id", GradeController, :delete
      delete "/absences/:id", AbsenceController, :delete

      resources "/tasks", TaskController, except: [:new, :edit]
      patch "/tasks/:id/status", TaskController, :update_status
    end
  end
end
