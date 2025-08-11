defmodule RefoodWeb.Router do
  use RefoodWeb, :router

  import RefoodWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RefoodWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RefoodWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  live_session :authenticated,
    on_mount: [
      {RefoodWeb.UserAuth, :ensure_authenticated}
    ] do
    scope "/shift", RefoodWeb do
      pipe_through :browser

      live "/", ShiftLive
      live "/:family_id", ShiftLive
    end

    scope "/help-queue", RefoodWeb do
      pipe_through :browser

      live "/", HelpQueueLive
    end

    scope "/families", RefoodWeb do
      pipe_through :browser

      live "/", FamiliesLive, :index
    end
  end

  live_session :authenticated_admin,
    on_mount: [
      {RefoodWeb.UserAuth, :ensure_authenticated},
      {RefoodWeb.UserAuth, :ensure_admin}
    ] do
    scope "/user-management", RefoodWeb do
      pipe_through :browser

      live "/", UsersLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", RefoodWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:refood, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RefoodWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", RefoodWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{RefoodWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", RefoodWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{RefoodWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", RefoodWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{RefoodWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
