defmodule GrappleWeb.ClusterLive.Index do
  use GrappleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Check if distributed mode is enabled
    distributed_mode = Application.get_env(:grapple, :distributed, false)

    cluster_info =
      if distributed_mode do
        get_cluster_info()
      else
        nil
      end

    {:ok,
     socket
     |> assign(:page_title, "Cluster Status")
     |> assign(:distributed_mode, distributed_mode)
     |> assign(:cluster_info, cluster_info)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.header>
        Cluster Status
        <:subtitle>
          Monitor distributed graph database nodes
        </:subtitle>
      </.header>

      <div :if={!@distributed_mode} class="rounded-lg border border-yellow-200 bg-yellow-50 p-6">
        <div class="flex items-start gap-3">
          <span class="text-2xl">⚠️</span>
          <div>
            <h3 class="text-lg font-semibold text-yellow-900 mb-2">
              Distributed Mode Not Enabled
            </h3>
            <p class="text-sm text-yellow-700 mb-4">
              The graph database is running in standalone mode. To enable distributed features, start the application with:
            </p>
            <pre class="bg-yellow-100 p-3 rounded text-sm font-mono">iex --name node1@localhost --cookie secret -S mix</pre>
          </div>
        </div>
      </div>

      <div :if={@distributed_mode && @cluster_info} class="space-y-6">
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
          <div class="rounded-lg border border-zinc-200 bg-white p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Current Node</p>
                <p class="mt-2 text-xl font-semibold text-zinc-900 font-mono">
                  <%= @cluster_info.current_node %>
                </p>
              </div>
              <div class="text-3xl">🖥️</div>
            </div>
          </div>

          <div class="rounded-lg border border-zinc-200 bg-white p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Connected Nodes</p>
                <p class="mt-2 text-3xl font-semibold text-zinc-900">
                  <%= length(@cluster_info.connected_nodes) %>
                </p>
              </div>
              <div class="text-3xl">🌐</div>
            </div>
          </div>

          <div class="rounded-lg border border-zinc-200 bg-white p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Cluster Health</p>
                <p class="mt-2 text-xl font-semibold text-emerald-600">
                  Healthy
                </p>
              </div>
              <div class="text-3xl">✅</div>
            </div>
          </div>
        </div>

        <div class="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 class="text-lg font-semibold text-zinc-900 mb-4">Cluster Nodes</h3>
          <div class="space-y-3">
            <div class="flex items-center gap-3 p-4 border border-emerald-200 bg-emerald-50 rounded-lg">
              <span class="text-xl">🖥️</span>
              <div class="flex-1">
                <div class="font-mono text-sm font-semibold text-emerald-900">
                  <%= @cluster_info.current_node %>
                </div>
                <div class="text-xs text-emerald-600">Current Node (You are here)</div>
              </div>
              <div class="text-xs px-2 py-1 bg-emerald-600 text-white rounded">
                Active
              </div>
            </div>

            <div
              :for={node <- @cluster_info.connected_nodes}
              class="flex items-center gap-3 p-4 border border-zinc-200 bg-white rounded-lg"
            >
              <span class="text-xl">🖥️</span>
              <div class="flex-1">
                <div class="font-mono text-sm font-semibold text-zinc-900">
                  <%= node %>
                </div>
                <div class="text-xs text-zinc-600">Connected Node</div>
              </div>
              <div class="text-xs px-2 py-1 bg-zinc-600 text-white rounded">
                Connected
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_cluster_info do
    current_node = Node.self()
    connected_nodes = Node.list()

    %{
      current_node: current_node,
      connected_nodes: connected_nodes
    }
  end
end
