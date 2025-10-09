defmodule GrappleWeb.GraphLive.Index do
  use GrappleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()
    {:ok, edges} = Grapple.Storage.EtsGraphStore.list_edges()

    {:ok,
     socket
     |> assign(:page_title, "Graph Visualization")
     |> assign(:nodes, nodes)
     |> assign(:edges, edges)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.header>
        Graph Visualization
        <:subtitle>
          Interactive visualization of your graph database
        </:subtitle>
      </.header>

      <div class="rounded-lg border border-zinc-200 bg-white p-6">
        <div id="graph-container" class="w-full" style="height: 600px; border: 1px solid #e4e4e7;" phx-hook="CytoscapeGraph">
          <div class="flex items-center justify-center h-full text-zinc-400">
            <div class="text-center">
              <p class="text-lg mb-2">Graph visualization will appear here</p>
              <p class="text-sm">Using Cytoscape.js for interactive rendering</p>
              <p class="text-xs mt-4">Nodes: <%= length(@nodes) %> | Edges: <%= length(@edges) %></p>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div class="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 class="text-lg font-semibold text-zinc-900 mb-4">Nodes (<%= length(@nodes) %>)</h3>
          <div class="space-y-2 max-h-96 overflow-y-auto">
            <div :for={node <- Enum.take(@nodes, 10)} class="p-3 border border-zinc-100 rounded">
              <div class="font-mono text-sm text-zinc-900">ID: <%= node.id %></div>
              <div class="text-xs text-zinc-600">Labels: <%= inspect(node.labels) %></div>
            </div>
            <p :if={length(@nodes) > 10} class="text-xs text-zinc-400 text-center">
              ... and <%= length(@nodes) - 10 %> more
            </p>
          </div>
        </div>

        <div class="rounded-lg border border-zinc-200 bg-white p-6">
          <h3 class="text-lg font-semibold text-zinc-900 mb-4">Edges (<%= length(@edges) %>)</h3>
          <div class="space-y-2 max-h-96 overflow-y-auto">
            <div :for={edge <- Enum.take(@edges, 10)} class="p-3 border border-zinc-100 rounded">
              <div class="font-mono text-sm text-zinc-900">
                <%= edge.source_id %> → <%= edge.target_id %>
              </div>
              <div class="text-xs text-zinc-600">Type: <%= edge.type %></div>
            </div>
            <p :if={length(@edges) > 10} class="text-xs text-zinc-400 text-center">
              ... and <%= length(@edges) - 10 %> more
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
