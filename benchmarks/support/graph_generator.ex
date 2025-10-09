defmodule Grapple.Benchmarks.GraphGenerator do
  @moduledoc """
  Utilities for generating test graphs for benchmarking.

  Provides functions to create various graph structures:
  - Random graphs
  - Linear chains
  - Binary trees
  - Dense/sparse graphs
  - Power-law distributions (social networks)
  """

  @doc """
  Generates a random graph with the specified number of nodes and edges.

  ## Examples

      iex> {nodes, edges} = Grapple.Benchmarks.GraphGenerator.random_graph(100, 200)
      iex> length(nodes)
      100
      iex> length(edges)
      200
  """
  def random_graph(node_count, edge_count) do
    # Create nodes with random properties
    nodes = create_nodes(node_count, fn i ->
      %{
        id: i,
        type: Enum.random(["user", "product", "category", "tag"]),
        value: :rand.uniform(1000),
        label: "Node_#{i}"
      }
    end)

    # Create random edges
    node_ids = Enum.map(nodes, & &1)
    edges = create_random_edges(node_ids, edge_count)

    {nodes, edges}
  end

  @doc """
  Creates a linear chain graph: 1 -> 2 -> 3 -> ... -> n

  Useful for testing path finding and traversal in the worst case.
  """
  def linear_chain(node_count) do
    nodes = create_nodes(node_count, fn i ->
      %{id: i, position: i, type: "chain_node"}
    end)

    edges = for i <- 0..(node_count - 2) do
      {Enum.at(nodes, i), Enum.at(nodes, i + 1), "next", %{position: i}}
    end

    {nodes, edges}
  end

  @doc """
  Creates a complete binary tree with the specified depth.

  Good for testing hierarchical traversal and balanced structures.
  """
  def binary_tree(depth) do
    node_count = :math.pow(2, depth + 1) - 1 |> round()
    nodes = create_nodes(node_count, fn i ->
      level = :math.log2(i + 1) |> floor()
      %{id: i, level: level, type: "tree_node"}
    end)

    edges = for i <- 0..(div(node_count - 1, 2) - 1) do
      parent = Enum.at(nodes, i)
      left_child = Enum.at(nodes, 2 * i + 1)
      right_child = Enum.at(nodes, 2 * i + 2)

      [
        {parent, left_child, "left_child", %{}},
        {parent, right_child, "right_child", %{}}
      ]
    end |> List.flatten() |> Enum.reject(&is_nil/1)

    {nodes, edges}
  end

  @doc """
  Creates a dense graph where each node connects to many others.

  Useful for testing performance with high edge counts.
  """
  def dense_graph(node_count, density \\ 0.5) do
    nodes = create_nodes(node_count, fn i ->
      %{id: i, type: "dense_node"}
    end)

    max_edges = node_count * (node_count - 1)
    target_edge_count = round(max_edges * density)

    edges = create_random_edges(nodes, target_edge_count)

    {nodes, edges}
  end

  @doc """
  Creates a sparse graph with minimal connections.

  Each node connects to only 2-3 other nodes on average.
  """
  def sparse_graph(node_count) do
    nodes = create_nodes(node_count, fn i ->
      %{id: i, type: "sparse_node"}
    end)

    # Each node connects to 2-3 others on average
    avg_degree = 2.5
    edge_count = round(node_count * avg_degree / 2)

    edges = create_random_edges(nodes, edge_count)

    {nodes, edges}
  end

  @doc """
  Creates a social network-like graph with power-law degree distribution.

  A small number of nodes have many connections (hubs), while most have few.
  """
  def social_network(node_count, avg_degree \\ 10) do
    nodes = create_nodes(node_count, fn i ->
      influence = if i < node_count * 0.1 do
        # Top 10% are influencers
        :rand.uniform(50) + 50
      else
        :rand.uniform(20)
      end

      %{id: i, type: "user", influence: influence}
    end)

    # Create edges with preferential attachment
    edges = preferential_attachment_edges(nodes, avg_degree)

    {nodes, edges}
  end

  @doc """
  Creates nodes and edges from a batch of nodes.

  Returns a tuple of {node_ids, edge_records} for easy benchmarking.
  """
  def create_and_link_batch(batch_size) do
    node_ids = for i <- 1..batch_size do
      {:ok, id} = Grapple.create_node(%{
        batch_id: div(i, 100),
        index: i,
        value: :rand.uniform(1000)
      })
      id
    end

    # Create edges between sequential nodes
    edges = for i <- 0..(batch_size - 2) do
      from = Enum.at(node_ids, i)
      to = Enum.at(node_ids, i + 1)
      {:ok, edge_id} = Grapple.create_edge(from, to, "connects", %{weight: :rand.uniform(100)})
      edge_id
    end

    {node_ids, edges}
  end

  # Private helper functions

  defp create_nodes(count, props_fn) do
    for i <- 0..(count - 1) do
      properties = props_fn.(i)
      {:ok, node_id} = Grapple.create_node(properties)
      node_id
    end
  end

  defp create_random_edges(nodes, edge_count) do
    node_list = Enum.to_list(nodes)

    for _ <- 1..edge_count do
      from = Enum.random(node_list)
      to = Enum.random(node_list)

      # Avoid self-loops
      if from != to do
        label = Enum.random(["connects", "relates_to", "links_to", "follows"])
        weight = :rand.uniform(100)
        {:ok, edge_id} = Grapple.create_edge(from, to, label, %{weight: weight})
        {from, to, label, edge_id}
      else
        nil
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  defp preferential_attachment_edges(nodes, avg_degree) do
    # Simple preferential attachment
    # Higher influence nodes get more connections
    for from_node <- nodes do
      # Number of edges based on influence
      {:ok, from_props} = Grapple.get_node(from_node)
      influence = from_props.properties.influence

      num_connections = min(influence * avg_degree div 50, length(nodes) - 1)

      targets = nodes
        |> Enum.reject(&(&1 == from_node))
        |> Enum.take_random(num_connections)

      for to_node <- targets do
        {:ok, edge_id} = Grapple.create_edge(
          from_node,
          to_node,
          "follows",
          %{strength: :rand.uniform(10)}
        )
        {from_node, to_node, "follows", edge_id}
      end
    end
    |> List.flatten()
  end
end
