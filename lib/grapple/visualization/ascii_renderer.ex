defmodule Grapple.Visualization.AsciiRenderer do
  @moduledoc """
  ASCII-based graph visualization for CLI output.
  Provides immediate visual feedback for graph structure and query results.
  """

  alias Grapple.Storage.EtsGraphStore

  defstruct [:nodes, :edges, :layout, :config]

  @default_config %{
    node_char: "●",
    edge_char: "─",
    vertex_char: "│",
    corner_char: "└",
    max_width: 80,
    max_height: 20,
    show_properties: true,
    show_labels: true
  }

  def render_subgraph(start_node_id, depth \\ 2, config \\ %{}) do
    config = Map.merge(@default_config, config)

    case collect_subgraph(start_node_id, depth) do
      {:ok, {nodes, edges}} ->
        layout = calculate_layout(nodes, edges, config)
        render_layout(layout, config)

      {:error, reason} ->
        "Error rendering subgraph: #{reason}"
    end
  end

  def render_query_result(nodes, edges, config \\ %{}) do
    config = Map.merge(@default_config, config)
    layout = calculate_layout(nodes, edges, config)
    render_layout(layout, config)
  end

  def render_path(path, config \\ %{}) when is_list(path) do
    config = Map.merge(@default_config, config)

    {:ok, {nodes, edges}} = collect_path_data(path)
    layout = calculate_linear_layout(nodes, edges, config)
    render_path_layout(layout, config)
  end

  def render_graph_stats(_config \\ %{}) do
    # Get basic graph statistics
    info = %{
      total_nodes: count_total_nodes(),
      total_edges: count_total_edges(),
      connected_components: count_connected_components()
    }

    """
    Graph Statistics:
    ────────────────
    Total Nodes: #{info.total_nodes}
    Total Edges: #{info.total_edges}
    Connected Components: #{info.connected_components}
    """
  end

  defp collect_subgraph(start_node_id, depth) do
    case traverse_for_visualization(start_node_id, depth) do
      {:ok, nodes} ->
        edges = collect_edges_between_nodes(nodes)
        {:ok, {nodes, edges}}

      error ->
        error
    end
  end

  defp traverse_for_visualization(start_node_id, depth) do
    traverse_recursive([start_node_id], depth, MapSet.new(), [])
  end

  defp traverse_recursive([], _depth, _visited, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp traverse_recursive(_nodes, 0, _visited, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp traverse_recursive([node_id | rest], depth, visited, acc) do
    if MapSet.member?(visited, node_id) do
      traverse_recursive(rest, depth, visited, acc)
    else
      case EtsGraphStore.get_node(node_id) do
        {:ok, node} ->
          new_visited = MapSet.put(visited, node_id)
          new_acc = [node | acc]

          {:ok, edges} = EtsGraphStore.get_edges_from(node_id)
          connected_nodes = edges |> Enum.map(fn {_from, edge} -> edge.to end)

          traverse_recursive(
            connected_nodes ++ rest,
            depth - 1,
            new_visited,
            new_acc
          )

        {:error, :not_found} ->
          traverse_recursive(rest, depth, visited, acc)
      end
    end
  end

  defp collect_edges_between_nodes(nodes) do
    node_ids = MapSet.new(nodes, fn node -> node.id end)

    nodes
    |> Enum.flat_map(fn node ->
      case EtsGraphStore.get_edges_from(node.id) do
        {:ok, edges} ->
          edges
          |> Enum.filter(fn {_from, edge} ->
            MapSet.member?(node_ids, edge.to)
          end)
          |> Enum.map(fn {_from, edge} -> edge end)

        _ ->
          []
      end
    end)
    |> Enum.uniq_by(fn edge -> edge.id end)
  end

  defp collect_path_data(path) do
    nodes =
      path
      |> Enum.map(fn node_id ->
        case EtsGraphStore.get_node(node_id) do
          {:ok, node} -> node
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    edges =
      path
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [from_id, to_id] ->
        find_edge_between(from_id, to_id)
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, {nodes, edges}}
  end

  defp find_edge_between(from_id, to_id) do
    case EtsGraphStore.get_edges_from(from_id) do
      {:ok, edges} ->
        edges
        |> Enum.find(fn {_from, edge} -> edge.to == to_id end)
        |> case do
          {_from, edge} -> edge
          nil -> nil
        end

      _ ->
        nil
    end
  end

  defp calculate_layout(nodes, edges, config) do
    case length(nodes) do
      n when n <= 3 ->
        calculate_linear_layout(nodes, edges, config)

      n when n <= 8 ->
        calculate_circular_layout(nodes, edges, config)

      _ ->
        calculate_grid_layout(nodes, edges, config)
    end
  end

  defp calculate_linear_layout(nodes, _edges, config) do
    max_width = config.max_width - 10
    spacing = max(3, div(max_width, length(nodes)))

    nodes
    |> Enum.with_index()
    |> Enum.map(fn {node, index} ->
      x = min(index * spacing, max_width - 5)
      y = 5
      {node, {x, y}}
    end)
    |> Enum.into(%{})
  end

  defp calculate_circular_layout(nodes, _edges, config) do
    center_x = div(config.max_width, 2)
    center_y = div(config.max_height, 2)
    radius = min(center_x - 5, center_y - 3)

    nodes
    |> Enum.with_index()
    |> Enum.map(fn {node, index} ->
      angle = 2 * :math.pi() * index / length(nodes)
      x = center_x + round(radius * :math.cos(angle))
      # Compress vertically for ASCII
      y = center_y + round(radius * :math.sin(angle) / 2)
      {node, {x, y}}
    end)
    |> Enum.into(%{})
  end

  defp calculate_grid_layout(nodes, _edges, config) do
    cols = round(:math.sqrt(length(nodes)))
    rows = ceil(length(nodes) / cols)

    col_spacing = div(config.max_width - 10, max(cols - 1, 1))
    row_spacing = div(config.max_height - 6, max(rows - 1, 1))

    nodes
    |> Enum.with_index()
    |> Enum.map(fn {node, index} ->
      col = rem(index, cols)
      row = div(index, cols)
      x = 5 + col * col_spacing
      y = 3 + row * row_spacing
      {node, {x, y}}
    end)
    |> Enum.into(%{})
  end

  defp render_layout(layout, config) do
    grid = create_empty_grid(config)

    grid
    |> place_nodes(layout, config)
    |> place_edges(layout, config)
    |> grid_to_string()
  end

  defp render_path_layout(layout, config) do
    nodes = Map.keys(layout)

    if length(nodes) <= 5 do
      # Simple horizontal path
      nodes
      |> Enum.sort_by(fn node -> elem(layout[node], 0) end)
      |> Enum.map(fn node ->
        format_node_inline(node, config)
      end)
      |> Enum.join(" #{config.edge_char}#{config.edge_char}> ")
    else
      # Use grid layout for longer paths
      render_layout(layout, config)
    end
  end

  defp create_empty_grid(config) do
    for _y <- 0..(config.max_height - 1) do
      for _x <- 0..(config.max_width - 1), do: " "
    end
  end

  defp place_nodes(grid, layout, config) do
    Enum.reduce(layout, grid, fn {node, {x, y}}, acc_grid ->
      if x >= 0 and x < config.max_width and y >= 0 and y < config.max_height do
        put_in_grid(acc_grid, x, y, config.node_char)
        |> place_node_label(node, x, y, config)
      else
        acc_grid
      end
    end)
  end

  defp place_node_label(grid, node, x, y, config) do
    if config.show_labels do
      label = format_node_label(node, config)
      place_string_in_grid(grid, label, x + 1, y, config)
    else
      grid
    end
  end

  defp place_edges(grid, _layout, _config) do
    # Simple edge placement - just connect nodes with lines
    # This is a simplified version; real implementation would be more sophisticated
    grid
  end

  defp put_in_grid(grid, x, y, char) do
    List.update_at(grid, y, fn row ->
      List.update_at(row, x, fn _ -> char end)
    end)
  end

  defp place_string_in_grid(grid, string, start_x, y, config) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(grid, fn {char, offset}, acc_grid ->
      x = start_x + offset

      if x < config.max_width do
        put_in_grid(acc_grid, x, y, char)
      else
        acc_grid
      end
    end)
  end

  defp grid_to_string(grid) do
    grid
    |> Enum.map(fn row ->
      row
      |> Enum.join("")
      |> String.trim_trailing()
    end)
    |> Enum.join("\n")
    |> String.trim_trailing("\n")
  end

  defp format_node_label(node, config) do
    base_label = "#{node.id}"

    if config.show_properties and map_size(node.properties) > 0 do
      # Show first property for compactness
      {key, value} = node.properties |> Enum.take(1) |> List.first()
      "#{base_label}(#{key}:#{value})"
    else
      base_label
    end
  end

  defp format_node_inline(node, config) do
    "#{config.node_char}#{format_node_label(node, config)}"
  end

  # Placeholder functions for graph statistics
  # TODO: Implement actual counting
  defp count_total_nodes, do: 0
  # TODO: Implement actual counting
  defp count_total_edges, do: 0
  # TODO: Implement actual analysis
  defp count_connected_components, do: 1
end
