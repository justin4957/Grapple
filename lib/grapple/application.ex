defmodule Grapple.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Determine if we're running in distributed mode
    distributed_mode = Application.get_env(:grapple, :distributed, false)
    
    children = base_children() ++ distributed_children(distributed_mode)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Grapple.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  defp base_children do
    [
      Grapple.Storage.EtsGraphStore,
      Grapple.Cluster.NodeManager
    ]
  end
  
  defp distributed_children(false), do: []
  
  defp distributed_children(true) do
    [
      # Phase 1: Basic distributed coordination
      Grapple.Distributed.ClusterManager,
      Grapple.Distributed.HealthMonitor,
      {Task, fn -> Grapple.Distributed.Discovery.start_discovery() end},
      
      # Phase 2: Data lifecycle management
      Grapple.Distributed.LifecycleManager,
      Grapple.Distributed.PlacementEngine,
      Grapple.Distributed.ReplicationEngine,
      Grapple.Distributed.Orchestrator,
      Grapple.Distributed.PersistenceManager
    ]
  end
end
