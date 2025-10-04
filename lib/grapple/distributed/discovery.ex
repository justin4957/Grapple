defmodule Grapple.Distributed.Discovery do
  @moduledoc """
  Minimal auto-discovery for cluster formation.
  Supports multiple protocols with unfurling architecture.
  """

  @discovery_port 45_000
  @discovery_interval 5_000

  def start_discovery(opts \\ []) do
    discovery_methods = opts[:methods] || [:erlang_nodes, :broadcast]
    
    # Start discovery processes for each method
    Enum.each(discovery_methods, fn method ->
      spawn_discovery_process(method, opts)
    end)
  end

  def discover_peers(_timeout \\ 10_000) do
    # Collect discoveries from all methods
    discoveries = [
      discover_via_erlang_nodes(),
      discover_via_broadcast(),
      discover_via_environment()
    ]
    
    peers = discoveries
    |> Enum.flat_map(fn
      {:ok, nodes} -> nodes
      {:error, _} -> []
    end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == node()))
    
    {:ok, peers}
  end

  # Erlang distribution discovery - find already connected nodes
  defp discover_via_erlang_nodes do
    connected_nodes = Node.list()
    potential_grapple_nodes = Enum.filter(connected_nodes, &is_grapple_node?/1)
    {:ok, potential_grapple_nodes}
  end

  # Simple UDP broadcast discovery for local networks
  defp discover_via_broadcast do
    case :gen_udp.open(@discovery_port, [:binary, {:active, false}, {:broadcast, true}]) do
      {:ok, socket} ->
        try do
          # Send discovery broadcast
          broadcast_msg = create_discovery_message()
          :gen_udp.send(socket, {255, 255, 255, 255}, @discovery_port, broadcast_msg)
          
          # Listen for responses
          peers = collect_broadcast_responses(socket, 2000)
          {:ok, peers}
        after
          :gen_udp.close(socket)
        end
      
      {:error, reason} ->
        {:error, {:broadcast_failed, reason}}
    end
  end

  # Environment-based discovery (for containers/k8s)
  defp discover_via_environment do
    case System.get_env("GRAPPLE_CLUSTER_NODES") do
      nil -> 
        {:ok, []}
      
      nodes_string ->
        nodes = nodes_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.to_atom/1)
        |> Enum.filter(&is_atom/1)
        
        {:ok, nodes}
    end
  end

  defp spawn_discovery_process(:erlang_nodes, _opts) do
    # Minimal process - just log connections
    spawn(fn -> 
      :net_kernel.monitor_nodes(true)
      monitor_node_changes()
    end)
  end

  defp spawn_discovery_process(:broadcast, _opts) do
    # Start UDP listener for discovery broadcasts
    spawn(fn -> 
      case :gen_udp.open(@discovery_port, [:binary, {:active, true}]) do
        {:ok, socket} ->
          listen_for_discoveries(socket)
        {:error, _} ->
          :ok  # Fail silently if can't bind - another instance might be running
      end
    end)
  end

  defp spawn_discovery_process(_unknown, _opts), do: :ok

  defp monitor_node_changes do
    receive do
      {:nodeup, node} ->
        if is_grapple_node?(node) do
          attempt_cluster_join(node)
        end
        monitor_node_changes()
      
      {:nodedown, _node} ->
        # Just continue monitoring
        monitor_node_changes()
    after
      @discovery_interval ->
        # Periodic discovery
        discover_peers()
        monitor_node_changes()
    end
  end

  defp listen_for_discoveries(socket) do
    receive do
      {:udp, ^socket, _address, _port, data} ->
        case decode_discovery_message(data) do
          {:ok, %{node_name: remote_node}} ->
            # Attempt to connect to discovered node
            attempt_cluster_join(remote_node)
          
          {:error, _} ->
            :ok  # Ignore malformed messages
        end
        
        listen_for_discoveries(socket)
    after
      30_000 ->
        # Send periodic discovery broadcast
        broadcast_msg = create_discovery_message()
        :gen_udp.send(socket, {255, 255, 255, 255}, @discovery_port, broadcast_msg)
        listen_for_discoveries(socket)
    end
  end

  defp create_discovery_message do
    discovery_info = %{
      node_name: node(),
      grapple_version: Application.spec(:grapple, :vsn) || "dev",
      timestamp: System.system_time(:second),
      capabilities: get_basic_capabilities()
    }
    
    :erlang.term_to_binary(discovery_info)
  end

  defp decode_discovery_message(binary_data) do
    try do
      data = :erlang.binary_to_term(binary_data)
      if is_map(data) and Map.has_key?(data, :node_name) do
        {:ok, data}
      else
        {:error, :invalid_format}
      end
    rescue
      _ -> {:error, :decode_failed}
    end
  end

  defp collect_broadcast_responses(socket, timeout) do
    start_time = System.monotonic_time(:millisecond)
    collect_responses(socket, start_time, timeout, [])
  end

  defp collect_responses(socket, start_time, timeout, acc) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    
    if elapsed >= timeout do
      acc
    else
      case :gen_udp.recv(socket, 0, timeout - elapsed) do
        {:ok, {_address, _port, data}} ->
          case decode_discovery_message(data) do
            {:ok, %{node_name: node_name}} ->
              collect_responses(socket, start_time, timeout, [node_name | acc])
            
            {:error, _} ->
              collect_responses(socket, start_time, timeout, acc)
          end
        
        {:error, :timeout} ->
          acc
        
        {:error, _} ->
          acc
      end
    end
  end

  defp is_grapple_node?(node) do
    # Simple heuristic - check if node name contains 'grapple'
    # Can be enhanced with proper service discovery
    node_string = Atom.to_string(node)
    String.contains?(node_string, "grapple")
  end

  defp attempt_cluster_join(remote_node) do
    case Grapple.Distributed.ClusterManager.join_cluster(remote_node) do
      {:ok, :joined} ->
        :ok
      
      {:error, _reason} ->
        # Silently fail - discovery is best effort
        :ok
    end
  end

  defp get_basic_capabilities do
    %{
      memory: :erlang.memory(:total),
      processes: :erlang.system_info(:process_count)
    }
  end
end