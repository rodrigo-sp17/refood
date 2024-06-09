defmodule RefoodWeb.Router do
  use RefoodWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RefoodWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RefoodWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/storages/:storage_id/items/download", ExportController, :download_storage_csv
  end

  live_session :authenticated,
    on_mount: [
      RefoodWeb.Nav
    ] do
    scope "/shift", RefoodWeb do
      pipe_through :browser

      live "/", ShiftLive, :index
    end

    scope "/products", RefoodWeb do
      pipe_through :browser

      live "/", ProductsLive, :index
      live "/new", ProductsLive, :new
    end

    scope "/storages", RefoodWeb do
      pipe_through :browser

      live "/", StoragesLive, :index
      live "/new", StoragesLive, :new
      live "/:id", StorageLive, :show
      live "/:id/items/new", StorageLive.NewItemLive, :new_item
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

  # Window with daily families -> UI only
  # Authentication
  # Family register (name, number, quantity, restrictions)
  # Day exchange
  # Fault register
  # New family solicitation -> add a new one (can't remove, only admins)
  # Family queue -> check who is there
  # Queue status ->
  # Authentication and log in (a token, admin accounts)
  # What kind of users? we have managers, shifts, rounds
  # Family and register -> For managers -> (name, number, quantity, absency register, )
  # Family Register -> For managers
  # Queue
end
