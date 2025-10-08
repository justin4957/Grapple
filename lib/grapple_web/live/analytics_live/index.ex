defmodule GrappleWeb.AnalyticsLive.Index do
  use GrappleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Analytics")
     |> assign(:algorithm, nil)
     |> assign(:results, nil)}
  end

  @impl true
  def handle_event("run_algorithm", %{"algorithm" => algorithm}, socket) do
    results = execute_algorithm(algorithm)

    {:noreply,
     socket
     |> assign(:algorithm, algorithm)
     |> assign(:results, results)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.header>
        Graph Analytics
        <:subtitle>
          Run advanced graph algorithms and view analytics
        </:subtitle>
      </.header>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <button
          phx-click="run_algorithm"
          phx-value-algorithm="pagerank"
          class="rounded-lg border border-zinc-200 bg-white p-6 hover:bg-zinc-50 transition text-left"
        >
          <div class="flex items-center gap-3 mb-2">
            <span class="text-2xl">📊</span>
            <h3 class="text-lg font-semibold text-zinc-900">PageRank</h3>
          </div>
          <p class="text-sm text-zinc-600">Calculate node importance scores</p>
        </button>

        <button
          phx-click="run_algorithm"
          phx-value-algorithm="betweenness"
          class="rounded-lg border border-zinc-200 bg-white p-6 hover:bg-zinc-50 transition text-left"
        >
          <div class="flex items-center gap-3 mb-2">
            <span class="text-2xl">🔗</span>
            <h3 class="text-lg font-semibold text-zinc-900">Betweenness</h3>
          </div>
          <p class="text-sm text-zinc-600">Find bridge nodes in the graph</p>
        </button>

        <button
          phx-click="run_algorithm"
          phx-value-algorithm="clustering"
          class="rounded-lg border border-zinc-200 bg-white p-6 hover:bg-zinc-50 transition text-left"
        >
          <div class="flex items-center gap-3 mb-2">
            <span class="text-2xl">🎯</span>
            <h3 class="text-lg font-semibold text-zinc-900">Clustering</h3>
          </div>
          <p class="text-sm text-zinc-600">Measure local clustering coefficient</p>
        </button>

        <button
          phx-click="run_algorithm"
          phx-value-algorithm="communities"
          class="rounded-lg border border-zinc-200 bg-white p-6 hover:bg-zinc-50 transition text-left"
        >
          <div class="flex items-center gap-3 mb-2">
            <span class="text-2xl">👥</span>
            <h3 class="text-lg font-semibold text-zinc-900">Communities</h3>
          </div>
          <p class="text-sm text-zinc-600">Detect community structures</p>
        </button>

        <button
          phx-click="run_algorithm"
          phx-value-algorithm="shortest_path"
          class="rounded-lg border border-zinc-200 bg-white p-6 hover:bg-zinc-50 transition text-left"
        >
          <div class="flex items-center gap-3 mb-2">
            <span class="text-2xl">🛤️</span>
            <h3 class="text-lg font-semibold text-zinc-900">Shortest Path</h3>
          </div>
          <p class="text-sm text-zinc-600">Find shortest paths between nodes</p>
        </button>

        <button
          phx-click="run_algorithm"
          phx-value-algorithm="connected_components"
          class="rounded-lg border border-zinc-200 bg-white p-6 hover:bg-zinc-50 transition text-left"
        >
          <div class="flex items-center gap-3 mb-2">
            <span class="text-2xl">🔀</span>
            <h3 class="text-lg font-semibold text-zinc-900">Connected Components</h3>
          </div>
          <p class="text-sm text-zinc-600">Find disconnected subgraphs</p>
        </button>
      </div>

      <div :if={@results} class="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 class="text-lg font-semibold text-zinc-900 mb-4">
          Results: <%= String.capitalize(@algorithm) %>
        </h3>
        <div class="overflow-x-auto">
          <pre class="text-sm text-zinc-700"><%= inspect(@results, pretty: true, limit: :infinity) %></pre>
        </div>
      </div>
    </div>
    """
  end

  defp execute_algorithm("pagerank") do
    try do
      Grapple.Analytics.Centrality.pagerank()
    rescue
      _ -> %{error: "Failed to calculate PageRank"}
    end
  end

  defp execute_algorithm("betweenness") do
    try do
      Grapple.Analytics.Centrality.betweenness_centrality()
    rescue
      _ -> %{error: "Failed to calculate betweenness centrality"}
    end
  end

  defp execute_algorithm("clustering") do
    try do
      Grapple.Analytics.Metrics.clustering_coefficient()
    rescue
      _ -> %{error: "Failed to calculate clustering coefficient"}
    end
  end

  defp execute_algorithm("communities") do
    try do
      Grapple.Analytics.Community.label_propagation()
    rescue
      _ -> %{error: "Failed to detect communities"}
    end
  end

  defp execute_algorithm("shortest_path") do
    nodes = Grapple.list_nodes()

    case nodes do
      [node1, node2 | _] ->
        try do
          case Grapple.shortest_path(node1.id, node2.id) do
            {:ok, path} -> %{path: path, from: node1.id, to: node2.id}
            {:error, reason} -> %{error: reason}
          end
        rescue
          _ -> %{error: "Failed to find shortest path"}
        end

      _ ->
        %{error: "Need at least 2 nodes in the graph"}
    end
  end

  defp execute_algorithm("connected_components") do
    try do
      Grapple.Analytics.Community.connected_components()
    rescue
      _ -> %{error: "Failed to find connected components"}
    end
  end

  defp execute_algorithm(_), do: %{error: "Unknown algorithm"}
end
