defmodule Grapple.Analytics do
  @moduledoc """
  Advanced graph analytics and algorithm implementations.

  This module provides a comprehensive suite of graph algorithms for:
  - Centrality analysis (PageRank, betweenness, closeness)
  - Community detection (connected components, clustering)
  - Graph metrics (density, diameter, degree distribution)

  ## Examples

      iex> Grapple.Analytics.pagerank()
      {:ok, %{node_id => score}}

      iex> Grapple.Analytics.connected_components()
      {:ok, [component1, component2]}

      iex> Grapple.Analytics.graph_density()
      {:ok, 0.45}
  """

  alias Grapple.Analytics.Centrality
  alias Grapple.Analytics.Community
  alias Grapple.Analytics.Metrics

  # Centrality Algorithms

  @doc """
  Calculate PageRank scores for all nodes in the graph.

  PageRank is a link analysis algorithm that assigns a numerical weighting
  to each node based on the structure of incoming edges.

  ## Options
    * `:damping_factor` - Probability of following an edge (default: 0.85)
    * `:max_iterations` - Maximum iterations to converge (default: 100)
    * `:tolerance` - Convergence threshold (default: 0.0001)

  ## Examples

      iex> Grapple.Analytics.pagerank()
      {:ok, %{1 => 0.35, 2 => 0.25, 3 => 0.40}}

      iex> Grapple.Analytics.pagerank(damping_factor: 0.9)
      {:ok, %{1 => 0.38, 2 => 0.22, 3 => 0.40}}
  """
  @spec pagerank(keyword()) :: {:ok, map()} | {:error, atom()}
  defdelegate pagerank(opts \\ []), to: Centrality

  @doc """
  Calculate betweenness centrality for all nodes.

  Betweenness centrality measures how often a node appears on the shortest
  paths between other nodes.

  ## Examples

      iex> Grapple.Analytics.betweenness_centrality()
      {:ok, %{1 => 5.0, 2 => 8.0, 3 => 2.0}}
  """
  @spec betweenness_centrality() :: {:ok, map()} | {:error, atom()}
  defdelegate betweenness_centrality(), to: Centrality

  @doc """
  Calculate closeness centrality for a specific node.

  Closeness centrality is the reciprocal of the average shortest path
  distance to all other nodes.

  ## Examples

      iex> Grapple.Analytics.closeness_centrality(1)
      {:ok, 0.67}
  """
  @spec closeness_centrality(integer()) :: {:ok, float()} | {:error, atom()}
  defdelegate closeness_centrality(node_id), to: Centrality

  # Community Detection

  @doc """
  Find all connected components in the graph.

  A connected component is a maximal set of nodes where each pair is
  connected by a path.

  ## Examples

      iex> Grapple.Analytics.connected_components()
      {:ok, [[1, 2, 3], [4, 5], [6]]}
  """
  @spec connected_components() :: {:ok, list(list(integer()))} | {:error, atom()}
  defdelegate connected_components(), to: Community

  @doc """
  Calculate clustering coefficient for the entire graph.

  The clustering coefficient measures the degree to which nodes tend
  to cluster together.

  ## Examples

      iex> Grapple.Analytics.clustering_coefficient()
      {:ok, 0.34}
  """
  @spec clustering_coefficient() :: {:ok, float()} | {:error, atom()}
  defdelegate clustering_coefficient(), to: Community

  @doc """
  Calculate local clustering coefficient for a specific node.

  ## Examples

      iex> Grapple.Analytics.local_clustering_coefficient(1)
      {:ok, 0.5}
  """
  @spec local_clustering_coefficient(integer()) :: {:ok, float()} | {:error, atom()}
  defdelegate local_clustering_coefficient(node_id), to: Community

  # Graph Metrics

  @doc """
  Calculate the density of the graph.

  Graph density is the ratio of actual edges to possible edges.

  ## Examples

      iex> Grapple.Analytics.graph_density()
      {:ok, 0.42}
  """
  @spec graph_density() :: {:ok, float()} | {:error, atom()}
  defdelegate graph_density(), to: Metrics

  @doc """
  Calculate the diameter of the graph.

  The diameter is the longest shortest path between any pair of nodes.

  ## Examples

      iex> Grapple.Analytics.graph_diameter()
      {:ok, 5}
  """
  @spec graph_diameter() :: {:ok, integer()} | {:error, atom()}
  defdelegate graph_diameter(), to: Metrics

  @doc """
  Calculate degree distribution statistics.

  Returns min, max, mean, and median degree values.

  ## Examples

      iex> Grapple.Analytics.degree_distribution()
      {:ok, %{min: 1, max: 10, mean: 4.5, median: 4}}
  """
  @spec degree_distribution() :: {:ok, map()} | {:error, atom()}
  defdelegate degree_distribution(), to: Metrics

  @doc """
  Get comprehensive analytics summary for the graph.

  Returns a map with all major metrics and statistics.

  ## Examples

      iex> Grapple.Analytics.summary()
      {:ok, %{
        density: 0.42,
        diameter: 5,
        components: 3,
        clustering: 0.34,
        degree_stats: %{...}
      }}
  """
  @spec summary() :: {:ok, map()} | {:error, atom()}
  def summary do
    with {:ok, density} <- graph_density(),
         {:ok, diameter} <- graph_diameter(),
         {:ok, components} <- connected_components(),
         {:ok, clustering} <- clustering_coefficient(),
         {:ok, degree_stats} <- degree_distribution() do
      {:ok,
       %{
         density: density,
         diameter: diameter,
         component_count: length(components),
         components: components,
         clustering_coefficient: clustering,
         degree_distribution: degree_stats
       }}
    end
  end
end
