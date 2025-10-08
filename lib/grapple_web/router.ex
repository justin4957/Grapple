defmodule GrappleWeb.Router do
  use GrappleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GrappleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GrappleWeb do
    pipe_through :browser

    live "/", DashboardLive.Index, :index
    live "/graph", GraphLive.Index, :index
    live "/query", QueryLive.Index, :index
    live "/analytics", AnalyticsLive.Index, :index
    live "/cluster", ClusterLive.Index, :index
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:grapple, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GrappleWeb.Telemetry
    end
  end
end
