defmodule GrappleWeb.QueryLive.Index do
  use GrappleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Query Builder")
     |> assign(:query, "")
     |> assign(:result, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("run_query", %{"query" => query}, socket) do
    case execute_query(query) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:result, result)
         |> assign(:error, nil)
         |> assign(:query, query)}

      {:error, error} ->
        {:noreply,
         socket
         |> assign(:result, nil)
         |> assign(:error, error)
         |> assign(:query, query)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.header>
        Query Builder
        <:subtitle>
          Execute Cypher queries against your graph database
        </:subtitle>
      </.header>

      <div class="rounded-lg border border-zinc-200 bg-white p-6">
        <form phx-submit="run_query" class="space-y-4">
          <div>
            <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">
              Cypher Query
            </label>
            <textarea
              name="query"
              rows="6"
              class="block w-full rounded-lg border-zinc-300 font-mono text-sm"
              placeholder="MATCH (n) RETURN n LIMIT 10"
            ><%= @query %></textarea>
          </div>

          <div class="flex items-center gap-4">
            <.button type="submit">
              Run Query
            </.button>
            <span class="text-sm text-zinc-600">
              Examples: MATCH (n) RETURN n | MATCH (n)-[r]->(m) RETURN n, r, m
            </span>
          </div>
        </form>
      </div>

      <div :if={@error} class="rounded-lg border border-rose-200 bg-rose-50 p-6">
        <h3 class="text-lg font-semibold text-rose-900 mb-2">Error</h3>
        <pre class="text-sm text-rose-700 overflow-x-auto"><%= @error %></pre>
      </div>

      <div :if={@result} class="rounded-lg border border-zinc-200 bg-white p-6">
        <h3 class="text-lg font-semibold text-zinc-900 mb-4">Results</h3>
        <div class="overflow-x-auto">
          <pre class="text-sm text-zinc-700"><%= inspect(@result, pretty: true) %></pre>
        </div>
      </div>
    </div>
    """
  end

  defp execute_query(query) do
    try do
      # For now, just parse and execute a simple query
      # In a real implementation, you would use Grapple.Query.Executor
      result = Grapple.Query.Executor.execute(query)
      {:ok, result}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
end
