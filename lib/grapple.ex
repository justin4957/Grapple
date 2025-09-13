defmodule Grapple do
  @moduledoc """
  Grapple - A distributed graph database built with Elixir and DETS.
  
  Provides a simple interface for graph operations and cluster management.
  """

  alias Grapple.CLI.Shell
  alias Grapple.Storage.EtsGraphStore
  alias Grapple.Cluster.NodeManager
  alias Grapple.Query.Executor

  def start_shell do
    Shell.start()
  end

  def create_node(properties \\ %{}) do
    EtsGraphStore.create_node(properties)
  end

  def create_edge(from_node, to_node, label, properties \\ %{}) do
    EtsGraphStore.create_edge(from_node, to_node, label, properties)
  end

  def get_node(node_id) do
    EtsGraphStore.get_node(node_id)
  end

  def find_nodes_by_property(key, value) do
    EtsGraphStore.find_nodes_by_property(key, value)
  end

  def find_edges_by_label(label) do
    EtsGraphStore.find_edges_by_label(label)
  end

  def get_stats do
    EtsGraphStore.get_stats()
  end

  def query(query_string) do
    Executor.execute(query_string)
  end

  def traverse(start_node, direction \\ :out, depth \\ 1) do
    Executor.traverse(start_node, direction, depth)
  end

  def find_path(from_node, to_node, max_depth \\ 10) do
    Executor.find_path(from_node, to_node, max_depth)
  end

  def join_cluster(node_name) do
    NodeManager.join_cluster(node_name)
  end

  def cluster_info do
    NodeManager.get_cluster_info()
  end
end
