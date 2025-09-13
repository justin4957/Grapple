defmodule Grapple.Distributed.Schema do
  @moduledoc """
  Minimal Mnesia schema for distributed coordination.
  Designed for unfurling - start simple, expand as needed.
  """

  # Core tables for distributed coordination
  def setup_tables do
    # Only create if not already exists - supports hot upgrades
    ensure_table(:cluster_nodes, [
      {:type, :set},
      {:attributes, [:node_id, :status, :join_time, :capabilities]},
      {:disc_copies, [node()]},
      {:index, [:status]}
    ])

    ensure_table(:data_partitions, [
      {:type, :set}, 
      {:attributes, [:partition_id, :primary_node, :replica_nodes, :status]},
      {:disc_copies, [node()]},
      {:index, [:primary_node, :status]}
    ])

    :ok
  end

  def ensure_table(table_name, options) do
    case :mnesia.create_table(table_name, options) do
      {:atomic, :ok} -> 
        :ok
      {:aborted, {:already_exists, ^table_name}} -> 
        :ok
      {:aborted, reason} -> 
        {:error, reason}
    end
  end

  # Minimal records - can be expanded without breaking changes
  defmodule ClusterNode do
    @moduledoc "Cluster node record - expandable"
    defstruct [:node_id, :status, :join_time, :capabilities]
    
    def new(node_id, capabilities \\ %{}) do
      %__MODULE__{
        node_id: node_id,
        status: :joining,
        join_time: DateTime.utc_now(),
        capabilities: Map.merge(%{memory: 0, cpu_cores: 0}, capabilities)
      }
    end
  end

  defmodule DataPartition do
    @moduledoc "Data partition record - expandable"
    defstruct [:partition_id, :primary_node, :replica_nodes, :status]
    
    def new(partition_id, primary_node) do
      %__MODULE__{
        partition_id: partition_id,
        primary_node: primary_node,
        replica_nodes: [],
        status: :active
      }
    end
  end
end