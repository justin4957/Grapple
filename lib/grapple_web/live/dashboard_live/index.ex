defmodule GrappleWeb.DashboardLive.Index do
  use GrappleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Get graph statistics
    stats = get_graph_stats()

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:stats, stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.header>
        Grapple Dashboard
        <:subtitle>
          Real-time graph database monitoring and visualization
        </:subtitle>
      </.header>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card title="Total Nodes" value={@stats.total_nodes} icon="🔵" />
        <.stat_card title="Total Edges" value={@stats.total_edges} icon="🔗" />
        <.stat_card title="Graph Density" value={format_density(@stats.density)} icon="📊" />
        <.stat_card
          title="Avg Degree"
          value={Float.round(@stats.average_degree, 2)}
          icon="🔀"
        />
      </div>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div class="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 class="text-lg font-semibold text-zinc-900 mb-4">Quick Actions</h3>
          <div class="space-y-3">
            <.link navigate={~p"/graph"} class="block">
              <div class="rounded-lg border border-zinc-200 p-4 hover:bg-zinc-50 transition">
                <div class="flex items-center gap-3">
                  <span class="text-2xl">🗺️</span>
                  <div>
                    <h4 class="font-semibold text-zinc-900">Visualize Graph</h4>
                    <p class="text-sm text-zinc-600">Interactive graph visualization</p>
                  </div>
                </div>
              </div>
            </.link>

            <.link navigate={~p"/query"} class="block">
              <div class="rounded-lg border border-zinc-200 p-4 hover:bg-zinc-50 transition">
                <div class="flex items-center gap-3">
                  <span class="text-2xl">🔍</span>
                  <div>
                    <h4 class="font-semibold text-zinc-900">Query Builder</h4>
                    <p class="text-sm text-zinc-600">Execute Cypher queries</p>
                  </div>
                </div>
              </div>
            </.link>

            <.link navigate={~p"/analytics"} class="block">
              <div class="rounded-lg border border-zinc-200 p-4 hover:bg-zinc-50 transition">
                <div class="flex items-center gap-3">
                  <span class="text-2xl">📈</span>
                  <div>
                    <h4 class="font-semibold text-zinc-900">Analytics</h4>
                    <p class="text-sm text-zinc-600">Graph algorithms and metrics</p>
                  </div>
                </div>
              </div>
            </.link>

            <.link navigate={~p"/cluster"} class="block">
              <div class="rounded-lg border border-zinc-200 p-4 hover:bg-zinc-50 transition">
                <div class="flex items-center gap-3">
                  <span class="text-2xl">🖥️</span>
                  <div>
                    <h4 class="font-semibold text-zinc-900">Cluster Status</h4>
                    <p class="text-sm text-zinc-600">Monitor distributed nodes</p>
                  </div>
                </div>
              </div>
            </.link>
          </div>
        </div>

        <div class="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 class="text-lg font-semibold text-zinc-900 mb-4">Recent Activity</h3>
          <div class="text-sm text-zinc-600">
            <p class="mb-2">Graph database is running</p>
            <p class="text-xs text-zinc-400">
              Last updated: <%= Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC") %>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-zinc-600"><%= @title %></p>
          <p class="mt-2 text-3xl font-semibold text-zinc-900"><%= @value %></p>
        </div>
        <div class="text-4xl"><%= @icon %></div>
      </div>
    </div>
    """
  end

  defp get_graph_stats do
    # Get all nodes and edges from the graph store
    nodes = Grapple.list_nodes()
    edges = Grapple.list_edges()

    total_nodes = length(nodes)
    total_edges = length(edges)

    # Calculate density (actual edges / possible edges)
    max_edges = if total_nodes > 1, do: total_nodes * (total_nodes - 1) / 2, else: 0
    density = if max_edges > 0, do: total_edges / max_edges, else: 0.0

    # Calculate average degree
    average_degree = if total_nodes > 0, do: 2 * total_edges / total_nodes, else: 0.0

    %{
      total_nodes: total_nodes,
      total_edges: total_edges,
      density: density,
      average_degree: average_degree
    }
  end

  defp format_density(density) do
    "#{Float.round(density * 100, 2)}%"
  end
end
