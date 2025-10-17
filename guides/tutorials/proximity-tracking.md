# Proximity Tracking with Grapple: Bluetooth/MAC Address Networks

This tutorial demonstrates how to use Grapple to build and analyze large-scale ephemeral proximity tracking databases for Bluetooth and MAC addresses, scaling from small deployments to city-wide networks.

## Table of Contents

1. [Overview](#overview)
2. [Use Cases](#use-cases)
3. [Basic Setup](#basic-setup)
4. [Data Model](#data-model)
5. [Small-Scale Deployment](#small-scale-deployment)
6. [City-Scale Deployment](#city-scale-deployment)
7. [Analytics & Insights](#analytics--insights)
8. [Performance Optimization](#performance-optimization)
9. [Privacy Considerations](#privacy-considerations)

## Overview

Proximity tracking captures devices that are in radio range of each other, creating a dynamic graph of physical proximity relationships. Grapple's graph database architecture is ideal for this use case because:

- **Dynamic graphs**: Proximity relationships change constantly
- **Ephemeral data**: Short-lived connections for privacy/storage
- **Fast queries**: Real-time proximity lookups
- **Analytics**: Community detection, contact tracing, traffic patterns
- **Scalability**: Handles millions of devices and billions of proximity events

## Use Cases

### Contact Tracing
Track potential exposure chains during disease outbreaks.

### Crowd Analytics
Understand foot traffic patterns, dwell times, and movement flows in public spaces.

### Asset Tracking
Monitor valuable equipment proximity relationships in warehouses or facilities.

### Smart City Infrastructure
Analyze pedestrian/vehicle movement patterns for urban planning.

### Retail Analytics
Measure customer journey patterns, store section popularity, and queue detection.

## Basic Setup

### Installation

```elixir
# mix.exs
def deps do
  [
    {:grapple, "~> 0.1.0"}
  ]
end
```

### Start Grapple

```elixir
# Start the application
{:ok, _} = Application.ensure_all_started(:grapple)

# For distributed/city-scale deployments
Application.put_env(:grapple, :distributed, true)
```

## Data Model

### Device Nodes

Each Bluetooth/MAC address is represented as a node with properties:

```elixir
%{
  device_id: "AA:BB:CC:DD:EE:FF",        # MAC/Bluetooth address
  device_type: "bluetooth",              # bluetooth | wifi | ble
  first_seen: ~U[2025-10-17 10:00:00Z],
  last_seen: ~U[2025-10-17 14:30:00Z],
  signal_strength_avg: -65,              # dBm
  encounter_count: 42,
  location_zone: "zone_downtown_01"      # Optional: sector/zone identifier
}
```

### Proximity Edges

Edges represent proximity relationships with temporal and signal data:

```elixir
# Edge label: "proximity"
# Edge properties:
%{
  timestamp: ~U[2025-10-17 12:15:30Z],
  duration_seconds: 180,                 # How long devices were in range
  signal_strength: -72,                  # RSSI in dBm
  distance_estimate: 5.2,                # Estimated meters (from RSSI)
  sensor_id: "sensor_001",               # Which sensor detected this
  location: "building_a_floor_2"
}
```

## Small-Scale Deployment

### Scenario: Office Building (100-500 devices)

```elixir
defmodule ProximityTracker do
  @moduledoc """
  Proximity tracking for a single building with multiple sensors.
  """

  # Record a device detection
  def record_detection(device_id, sensor_id, signal_strength, location) do
    timestamp = DateTime.utc_now()

    # Create or update device node
    case Grapple.find_nodes_by_property(:device_id, device_id) do
      {:ok, []} ->
        # New device
        Grapple.create_node(%{
          device_id: device_id,
          device_type: detect_device_type(device_id),
          first_seen: timestamp,
          last_seen: timestamp,
          signal_strength_avg: signal_strength,
          encounter_count: 0,
          location_zone: location
        })

      {:ok, [existing_node]} ->
        # Update existing device
        Grapple.update_node(existing_node.id, %{
          last_seen: timestamp,
          signal_strength_avg:
            (existing_node.properties.signal_strength_avg + signal_strength) / 2,
          location_zone: location
        })
    end
  end

  # Record proximity between two devices
  def record_proximity(device1_id, device2_id, signal_strength, sensor_id, location) do
    with {:ok, [node1]} <- Grapple.find_nodes_by_property(:device_id, device1_id),
         {:ok, [node2]} <- Grapple.find_nodes_by_property(:device_id, device2_id) do

      # Estimate distance from signal strength (simplified)
      distance = estimate_distance(signal_strength)

      # Create proximity edge (bidirectional relationship)
      Grapple.create_edge(node1.id, node2.id, "proximity", %{
        timestamp: DateTime.utc_now(),
        signal_strength: signal_strength,
        distance_estimate: distance,
        sensor_id: sensor_id,
        location: location
      })

      # Increment encounter count
      Grapple.update_node(node1.id, %{
        encounter_count: node1.properties.encounter_count + 1
      })
    end
  end

  # Clean up old proximity data (ephemeral)
  def cleanup_old_data(max_age_hours \\ 24) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_hours * 3600, :second)

    {:ok, edges} = Grapple.Storage.EtsGraphStore.list_edges()

    # Remove edges older than cutoff
    Enum.each(edges, fn edge ->
      if edge.properties[:timestamp] &&
         DateTime.compare(edge.properties.timestamp, cutoff) == :lt do
        Grapple.delete_edge(edge.id)
      end
    end)

    # Remove devices not seen recently
    {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()

    Enum.each(nodes, fn node ->
      if node.properties[:last_seen] &&
         DateTime.compare(node.properties.last_seen, cutoff) == :lt do
        Grapple.delete_node(node.id)
      end
    end)
  end

  # Helper: Estimate distance from RSSI
  defp estimate_distance(rssi) do
    # Simplified path loss model: d = 10^((TxPower - RSSI) / (10 * n))
    # Assuming TxPower = -59 dBm at 1m, n = 2 (free space)
    tx_power = -59
    path_loss_exponent = 2.0

    distance = :math.pow(10, (tx_power - rssi) / (10 * path_loss_exponent))
    Float.round(distance, 2)
  end

  # Helper: Detect device type from address
  defp detect_device_type(address) do
    cond do
      String.contains?(address, ":") -> "bluetooth"
      String.contains?(address, "-") -> "wifi"
      true -> "unknown"
    end
  end
end
```

### Query Examples

```elixir
# Find all devices currently in proximity to a specific device
def find_nearby_devices(device_id, max_age_seconds \\ 300) do
  with {:ok, [device]} <- Grapple.find_nodes_by_property(:device_id, device_id),
       {:ok, nodes} <- Grapple.Query.Executor.traverse(device.id, :out, 1) do

    # Filter to recent proximity only
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_seconds, :second)

    recent_neighbors =
      nodes
      |> Enum.filter(fn node ->
        node.properties[:last_seen] &&
        DateTime.compare(node.properties.last_seen, cutoff) == :gt
      end)

    {:ok, recent_neighbors}
  end
end

# Find proximity chains (contact tracing)
def find_proximity_chain(device_id, depth \\ 2) do
  with {:ok, [device]} <- Grapple.find_nodes_by_property(:device_id, device_id) do
    Grapple.Query.Executor.traverse(device.id, :out, depth)
  end
end

# Find devices in a specific location zone
def devices_in_zone(zone_name) do
  Grapple.find_nodes_by_property(:location_zone, zone_name)
end
```

## City-Scale Deployment

### Architecture Overview

For city-scale networks (100K+ devices, 1M+ proximity events/hour):

```
┌─────────────────────────────────────────────────────────┐
│                    Load Balancer                        │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼────────┐ ┌───────▼────────┐ ┌──────▼─────────┐
│  Grapple Node  │ │  Grapple Node  │ │  Grapple Node  │
│   (Zone 1-10)  │ │  (Zone 11-20)  │ │  (Zone 21-30)  │
└────────────────┘ └────────────────┘ └────────────────┘
         │                 │                  │
         └─────────────────┴──────────────────┘
                           │
                  ┌────────▼────────┐
                  │   Mnesia        │
                  │ (Distributed DB)│
                  └─────────────────┘
```

### Distributed Setup

```elixir
defmodule CityScaleProximity do
  @moduledoc """
  City-scale proximity tracking with distributed Grapple cluster.
  """

  # Start distributed cluster
  def start_cluster(node_name, cluster_nodes \\ []) do
    # Set node name
    Node.start(node_name, :longnames)

    # Enable distributed mode
    Application.put_env(:grapple, :distributed, true)
    Application.ensure_all_started(:grapple)

    # Join cluster
    Enum.each(cluster_nodes, fn node ->
      Node.connect(node)
    end)

    # Configure data lifecycle for ephemeral data
    if Process.whereis(Grapple.Distributed.LifecycleManager) do
      # Classify proximity data as ephemeral (short-lived)
      Grapple.Distributed.LifecycleManager.classify_data(
        "proximity_edges",
        :ephemeral
      )

      # Classify device nodes as session data (medium-lived)
      Grapple.Distributed.LifecycleManager.classify_data(
        "device_nodes",
        :session
      )
    end
  end

  # Partition devices by geographical zone
  def assign_zone_partition(device_id, location) do
    # Hash device to partition based on location zone
    zone_partition = :erlang.phash2(location, 100)

    # Use partition-aware node selection
    partition_node = select_partition_node(zone_partition)

    # Store device on appropriate node
    :rpc.call(partition_node, Grapple, :create_node, [%{
      device_id: device_id,
      location_zone: location,
      partition: zone_partition
    }])
  end

  # Batch import proximity events for performance
  def batch_import_proximity_events(events) do
    # Group events by partition for efficient insertion
    events_by_partition =
      events
      |> Enum.group_by(fn event ->
        :erlang.phash2(event.location, 100)
      end)

    # Parallel insert across partitions
    tasks =
      Enum.map(events_by_partition, fn {partition, partition_events} ->
        Task.async(fn ->
          node = select_partition_node(partition)
          :rpc.call(node, __MODULE__, :insert_proximity_batch, [partition_events])
        end)
      end)

    # Wait for all inserts
    Enum.map(tasks, &Task.await(&1, 30_000))
  end

  def insert_proximity_batch(events) do
    Enum.each(events, fn event ->
      record_proximity(
        event.device1_id,
        event.device2_id,
        event.signal_strength,
        event.sensor_id,
        event.location
      )
    end)
  end

  # Query across distributed cluster
  def find_city_wide_proximity_chain(device_id, max_depth \\ 3) do
    # Query across all nodes in cluster
    nodes = [Node.self() | Node.list()]

    # Parallel search across cluster
    results =
      nodes
      |> Task.async_stream(fn node ->
        :rpc.call(node, __MODULE__, :local_proximity_search, [device_id, max_depth])
      end, timeout: 30_000)
      |> Enum.flat_map(fn {:ok, result} -> result || [] end)
      |> Enum.uniq_by(& &1.id)

    {:ok, results}
  end

  def local_proximity_search(device_id, max_depth) do
    case Grapple.find_nodes_by_property(:device_id, device_id) do
      {:ok, [device]} ->
        {:ok, nodes} = Grapple.Query.Executor.traverse(device.id, :out, max_depth)
        nodes

      _ ->
        []
    end
  end

  # Helper: Select node for partition
  defp select_partition_node(partition) do
    nodes = [Node.self() | Node.list()]
    node_count = length(nodes)
    node_index = rem(partition, node_count)
    Enum.at(nodes, node_index)
  end

  # Record proximity event (optimized for high throughput)
  defp record_proximity(device1_id, device2_id, signal_strength, sensor_id, location) do
    # Same as small-scale but with async processing
    Task.start(fn ->
      ProximityTracker.record_proximity(
        device1_id,
        device2_id,
        signal_strength,
        sensor_id,
        location
      )
    end)
  end
end
```

### Ingestion Pipeline

```elixir
defmodule ProximityIngestion do
  @moduledoc """
  High-throughput ingestion pipeline for sensor data.
  """
  use GenServer

  # Buffer for batch processing
  defstruct buffer: [], buffer_size: 0, max_buffer_size: 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Ingest sensor reading
  def ingest(sensor_reading) do
    GenServer.cast(__MODULE__, {:ingest, sensor_reading})
  end

  def init(opts) do
    max_buffer_size = Keyword.get(opts, :max_buffer_size, 1000)

    # Schedule periodic flush
    :timer.send_interval(5_000, :flush_buffer)

    {:ok, %__MODULE__{max_buffer_size: max_buffer_size}}
  end

  def handle_cast({:ingest, reading}, state) do
    new_buffer = [reading | state.buffer]
    new_size = state.buffer_size + 1

    if new_size >= state.max_buffer_size do
      # Flush immediately if buffer full
      flush_buffer(new_buffer)
      {:noreply, %{state | buffer: [], buffer_size: 0}}
    else
      {:noreply, %{state | buffer: new_buffer, buffer_size: new_size}}
    end
  end

  def handle_info(:flush_buffer, state) do
    if state.buffer_size > 0 do
      flush_buffer(state.buffer)
      {:noreply, %{state | buffer: [], buffer_size: 0}}
    else
      {:noreply, state}
    end
  end

  defp flush_buffer(readings) do
    # Process readings in parallel batches
    readings
    |> Enum.chunk_every(100)
    |> Enum.each(fn batch ->
      Task.start(fn ->
        process_batch(batch)
      end)
    end)
  end

  defp process_batch(batch) do
    Enum.each(batch, fn reading ->
      # Extract proximity pairs from sensor reading
      proximity_pairs = extract_proximity_pairs(reading)

      Enum.each(proximity_pairs, fn {dev1, dev2, rssi} ->
        ProximityTracker.record_proximity(
          dev1,
          dev2,
          rssi,
          reading.sensor_id,
          reading.location
        )
      end)
    end)
  end

  defp extract_proximity_pairs(reading) do
    # Example: sensor detected multiple devices simultaneously
    # Create proximity edges for all pairs
    devices = reading.detected_devices

    for dev1 <- devices,
        dev2 <- devices,
        dev1.address < dev2.address do
      {dev1.address, dev2.address, min(dev1.rssi, dev2.rssi)}
    end
  end
end
```

## Analytics & Insights

### Contact Tracing

```elixir
defmodule ProximityAnalytics do
  # Find all potential contacts within time window
  def trace_contacts(device_id, start_time, end_time, max_hops \\ 2) do
    with {:ok, [device]} <- Grapple.find_nodes_by_property(:device_id, device_id),
         {:ok, contact_nodes} <- Grapple.Query.Executor.traverse(device.id, :out, max_hops) do

      # Filter by time window
      contacts =
        contact_nodes
        |> Enum.filter(fn node ->
          last_seen = node.properties[:last_seen]
          last_seen &&
          DateTime.compare(last_seen, start_time) != :lt &&
          DateTime.compare(last_seen, end_time) != :gt
        end)

      # Annotate with proximity duration and distance
      annotated =
        Enum.map(contacts, fn contact ->
          edge_info = get_proximity_edge_info(device.id, contact.id)
          Map.put(contact, :proximity_info, edge_info)
        end)

      {:ok, annotated}
    end
  end

  defp get_proximity_edge_info(from_id, to_id) do
    {:ok, edges} = Grapple.Storage.EtsGraphStore.list_edges()

    edges
    |> Enum.filter(fn e ->
      (e.from == from_id && e.to == to_id) ||
      (e.from == to_id && e.to == from_id)
    end)
    |> Enum.map(& &1.properties)
  end
end
```

### Community Detection

```elixir
# Find communities (groups that spend time together)
def detect_communities do
  # Use Louvain algorithm
  {:ok, communities} = Grapple.Analytics.Community.louvain_communities()

  # Group devices by community
  community_groups =
    communities
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))

  # Annotate with community metadata
  Enum.map(community_groups, fn {community_id, device_node_ids} ->
    devices = get_devices_info(device_node_ids)

    %{
      community_id: community_id,
      size: length(devices),
      devices: devices,
      common_locations: find_common_locations(devices),
      active_time_range: find_time_range(devices)
    }
  end)
end

# Find traffic hotspots
def detect_hotspots(time_window_minutes \\ 60) do
  cutoff = DateTime.add(DateTime.utc_now(), -time_window_minutes * 60, :second)

  {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()

  # Group by location zone
  nodes
  |> Enum.filter(fn n ->
    DateTime.compare(n.properties.last_seen, cutoff) == :gt
  end)
  |> Enum.group_by(& &1.properties[:location_zone])
  |> Enum.map(fn {zone, devices} ->
    %{
      zone: zone,
      device_count: length(devices),
      density: calculate_density(devices),
      avg_signal_strength: avg_signal_strength(devices)
    }
  end)
  |> Enum.sort_by(& &1.device_count, :desc)
end

# Movement flow analysis
def analyze_movement_flows(start_time, end_time) do
  {:ok, edges} = Grapple.Storage.EtsGraphStore.list_edges()

  # Find edges in time window with location changes
  movement_edges =
    edges
    |> Enum.filter(fn edge ->
      ts = edge.properties[:timestamp]
      ts &&
      DateTime.compare(ts, start_time) != :lt &&
      DateTime.compare(ts, end_time) != :gt
    end)

  # Group by location transitions
  movement_edges
  |> Enum.group_by(fn edge ->
    # Extract origin and destination zones
    {get_device_zone(edge.from), get_device_zone(edge.to)}
  end)
  |> Enum.map(fn {{from_zone, to_zone}, edges} ->
    %{
      from: from_zone,
      to: to_zone,
      flow_count: length(edges),
      avg_duration: avg_duration(edges)
    }
  end)
  |> Enum.sort_by(& &1.flow_count, :desc)
end
```

### Centrality Analysis

```elixir
# Find most connected devices (super spreaders, popular locations)
def find_super_connectors do
  # PageRank to find influential nodes
  {:ok, pagerank} = Grapple.Analytics.Centrality.pagerank()

  {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()

  nodes
  |> Enum.map(fn node ->
    rank = Map.get(pagerank, node.id, 0.0)
    Map.put(node, :influence_score, rank)
  end)
  |> Enum.sort_by(& &1.influence_score, :desc)
  |> Enum.take(20)
end

# Betweenness centrality to find bridge devices
def find_bridge_devices do
  {:ok, betweenness} = Grapple.Analytics.Centrality.betweenness_centrality()

  {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()

  nodes
  |> Enum.map(fn node ->
    score = Map.get(betweenness, node.id, 0.0)
    Map.put(node, :bridge_score, score)
  end)
  |> Enum.filter(& &1.bridge_score > 0)
  |> Enum.sort_by(& &1.bridge_score, :desc)
end
```

## Performance Optimization

### Memory Management

```elixir
# Configure lifecycle management for ephemeral data
defmodule ProximityLifecycle do
  def configure_lifecycle do
    # Proximity edges: ephemeral (delete after 6 hours)
    configure_ephemeral_edges()

    # Device nodes: session (delete after 24 hours of inactivity)
    configure_session_nodes()

    # Analytics results: computational (cache for 1 hour)
    configure_computational_cache()
  end

  defp configure_ephemeral_edges do
    # Run cleanup every 30 minutes
    :timer.apply_interval(30 * 60 * 1000, __MODULE__, :cleanup_old_edges, [6])
  end

  def cleanup_old_edges(max_age_hours) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_hours * 3600, :second)

    {:ok, edges} = Grapple.Storage.EtsGraphStore.list_edges()

    old_edges =
      edges
      |> Enum.filter(fn edge ->
        ts = edge.properties[:timestamp]
        ts && DateTime.compare(ts, cutoff) == :lt
      end)

    # Delete in batches
    old_edges
    |> Enum.chunk_every(1000)
    |> Enum.each(fn batch ->
      Enum.each(batch, &Grapple.delete_edge(&1.id))
    end)

    IO.puts("Cleaned up #{length(old_edges)} old proximity edges")
  end

  defp configure_session_nodes do
    # Run cleanup every hour
    :timer.apply_interval(60 * 60 * 1000, __MODULE__, :cleanup_inactive_devices, [24])
  end

  def cleanup_inactive_devices(max_inactive_hours) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_inactive_hours * 3600, :second)

    {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()

    inactive_nodes =
      nodes
      |> Enum.filter(fn node ->
        last_seen = node.properties[:last_seen]
        last_seen && DateTime.compare(last_seen, cutoff) == :lt
      end)

    Enum.each(inactive_nodes, &Grapple.delete_node(&1.id))

    IO.puts("Cleaned up #{length(inactive_nodes)} inactive devices")
  end
end
```

### Query Optimization

```elixir
# Create indexes for common queries
defmodule ProximityIndexing do
  def create_indexes do
    # Index by location zone for spatial queries
    Grapple.Storage.EtsGraphStore.create_property_index(:location_zone)

    # Index by device_id for lookups
    Grapple.Storage.EtsGraphStore.create_property_index(:device_id)

    # Index by timestamp for temporal queries
    Grapple.Storage.EtsGraphStore.create_property_index(:last_seen)
  end
end
```

### Batch Processing

```elixir
# Process analytics in background
defmodule BackgroundAnalytics do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Schedule analytics every 10 minutes
    :timer.send_interval(10 * 60 * 1000, :run_analytics)
    {:ok, state}
  end

  def handle_info(:run_analytics, state) do
    Task.start(fn ->
      # Run analytics asynchronously
      communities = detect_communities()
      hotspots = detect_hotspots()
      flows = analyze_movement_flows(
        DateTime.add(DateTime.utc_now(), -3600, :second),
        DateTime.utc_now()
      )

      # Store results for quick access
      :ets.insert(:analytics_cache, {
        :communities, communities, DateTime.utc_now()
      })
      :ets.insert(:analytics_cache, {
        :hotspots, hotspots, DateTime.utc_now()
      })
      :ets.insert(:analytics_cache, {
        :flows, flows, DateTime.utc_now()
      })
    end)

    {:noreply, state}
  end
end
```

## Privacy Considerations

### Data Anonymization

```elixir
defmodule PrivacyProtection do
  @moduledoc """
  Privacy-preserving proximity tracking.
  """

  # Hash device addresses for anonymization
  def anonymize_device_id(device_id) do
    :crypto.hash(:sha256, device_id)
    |> Base.encode16(case: :lower)
    |> String.slice(0..15)
  end

  # Store only hashed addresses
  def record_anonymous_detection(device_id, sensor_id, signal_strength, location) do
    anonymous_id = anonymize_device_id(device_id)

    ProximityTracker.record_detection(
      anonymous_id,
      sensor_id,
      signal_strength,
      location
    )
  end

  # Aggregate location data to prevent tracking
  def generalize_location(precise_location) do
    # Convert precise coordinates to zone
    # Example: "lat:40.7128,lon:-74.0060" -> "zone_downtown_grid_A5"
    parse_and_zone(precise_location)
  end

  # Implement k-anonymity: only store if k devices present
  def record_if_k_anonymous(device_id, location, k \\ 5) do
    current_devices = count_devices_in_location(location)

    if current_devices >= k do
      record_anonymous_detection(device_id, location)
      :ok
    else
      # Don't store - not enough devices for anonymity
      :skipped
    end
  end

  # Differential privacy: add noise to aggregate counts
  def get_noisy_count(location, epsilon \\ 1.0) do
    true_count = count_devices_in_location(location)
    noise = laplace_noise(1.0 / epsilon)
    max(0, round(true_count + noise))
  end

  defp laplace_noise(scale) do
    u = :rand.uniform() - 0.5
    -scale * sign(u) * :math.log(1 - 2 * abs(u))
  end

  defp sign(x) when x >= 0, do: 1
  defp sign(_), do: -1

  # Automatic data retention limits
  def configure_gdpr_compliance do
    # Maximum data retention: 7 days
    max_retention_days = 7

    :timer.apply_interval(
      24 * 60 * 60 * 1000,  # Daily
      ProximityLifecycle,
      :cleanup_old_edges,
      [max_retention_days * 24]
    )
  end
end
```

### Consent Management

```elixir
defmodule ConsentManagement do
  # Only track devices that have opted in
  def record_with_consent(device_id, consent_token) do
    if verify_consent(device_id, consent_token) do
      # Proceed with tracking
      {:ok, :tracking_enabled}
    else
      {:error, :no_consent}
    end
  end

  # Allow users to request data deletion
  def delete_user_data(device_id, consent_token) do
    if verify_consent(device_id, consent_token) do
      # Find and delete all data for this device
      {:ok, nodes} = Grapple.find_nodes_by_property(:device_id, device_id)

      Enum.each(nodes, fn node ->
        Grapple.delete_node(node.id)
      end)

      {:ok, :data_deleted}
    else
      {:error, :unauthorized}
    end
  end

  defp verify_consent(_device_id, _token) do
    # Implement consent verification
    # Could check against consent database, JWT token, etc.
    true
  end
end
```

## Example: City-Wide Deployment

### Scenario: Smart City with 500K Devices

```elixir
defmodule SmartCityDeployment do
  @moduledoc """
  Full city-scale proximity tracking system.

  Network topology:
  - 30 geographical zones
  - 3 Grapple cluster nodes
  - 500+ Bluetooth sensors
  - 500,000 tracked devices
  - 10M proximity events/day
  """

  def deploy_city_network do
    # 1. Start distributed cluster
    start_cluster()

    # 2. Configure lifecycle management
    configure_lifecycle()

    # 3. Start ingestion pipeline
    start_ingestion()

    # 4. Configure analytics
    start_analytics()

    # 5. Setup monitoring
    setup_monitoring()
  end

  defp start_cluster do
    nodes = [
      :"grapple1@city-analytics-01.local",
      :"grapple2@city-analytics-02.local",
      :"grapple3@city-analytics-03.local"
    ]

    CityScaleProximity.start_cluster(hd(nodes), tl(nodes))
  end

  defp configure_lifecycle do
    ProximityLifecycle.configure_lifecycle()
    PrivacyProtection.configure_gdpr_compliance()
  end

  defp start_ingestion do
    # Start multiple ingestion workers
    for i <- 1..10 do
      ProximityIngestion.start_link(
        name: :"ingestion_worker_#{i}",
        max_buffer_size: 5000
      )
    end
  end

  defp start_analytics do
    BackgroundAnalytics.start_link([])

    # Create indexes
    ProximityIndexing.create_indexes()
  end

  defp setup_monitoring do
    # Monitor cluster health
    :timer.apply_interval(60_000, __MODULE__, :log_cluster_stats, [])
  end

  def log_cluster_stats do
    {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()
    {:ok, edges} = Grapple.Storage.EtsGraphStore.list_edges()

    IO.puts("""
    === Cluster Stats ===
    Nodes: #{Node.list() |> length() + 1}
    Devices: #{length(nodes)}
    Proximity Events: #{length(edges)}
    Memory: #{:erlang.memory(:total) |> div(1024 * 1024)} MB
    """)
  end

  # Example query: Find all proximity chains for contact tracing
  def citywide_contact_trace(device_id, time_window_hours \\ 48) do
    start_time = DateTime.add(DateTime.utc_now(), -time_window_hours * 3600, :second)
    end_time = DateTime.utc_now()

    # Search across distributed cluster
    {:ok, contacts} = CityScaleProximity.find_city_wide_proximity_chain(device_id, 3)

    # Filter by time window
    recent_contacts =
      contacts
      |> Enum.filter(fn contact ->
        last_seen = contact.properties[:last_seen]
        last_seen &&
        DateTime.compare(last_seen, start_time) != :lt
      end)

    # Organize by proximity level
    %{
      direct_contacts: Enum.filter(recent_contacts, & &1.depth == 1),
      secondary_contacts: Enum.filter(recent_contacts, & &1.depth == 2),
      tertiary_contacts: Enum.filter(recent_contacts, & &1.depth == 3),
      total_count: length(recent_contacts),
      time_window: %{start: start_time, end: end_time}
    }
  end
end
```

## Performance Benchmarks

### Expected Performance (City-Scale)

| Metric | Small Scale | City Scale |
|--------|-------------|------------|
| Devices | 100-500 | 100K-500K |
| Proximity Events/sec | 10-100 | 1,000-10,000 |
| Query Latency (p95) | <10ms | <100ms |
| Memory Usage | 10-50 MB | 5-20 GB |
| Storage per Day | 1-10 MB | 100-500 MB |

### Tuning Parameters

```elixir
# config/config.exs
config :grapple,
  distributed: true,
  partition_count: 100,
  replication_factor: 2,
  batch_size: 1000,
  cleanup_interval_minutes: 30,
  max_retention_hours: 168  # 7 days
```

## CLI Commands

```bash
# Start Grapple shell
iex -S mix

# View current devices
Grapple> {:ok, nodes} = Grapple.Storage.EtsGraphStore.list_nodes()

# Find proximity chain
Grapple> ProximityAnalytics.trace_contacts("AA:BB:CC:DD:EE:FF",
  ~U[2025-10-17 10:00:00Z],
  ~U[2025-10-17 14:00:00Z])

# Detect communities
Grapple> communities = ProximityAnalytics.detect_communities()

# Find hotspots
Grapple> hotspots = ProximityAnalytics.detect_hotspots(60)

# Run analytics
Grapple> {:ok, pagerank} = Grapple.Analytics.Centrality.pagerank()
```

## Conclusion

This tutorial demonstrated how to build a scalable proximity tracking system using Grapple, from small office deployments to city-wide networks. Key takeaways:

1. **Graph Structure**: Devices as nodes, proximity as edges
2. **Ephemeral Data**: Use lifecycle management for automatic cleanup
3. **Distributed Scale**: Partition data geographically across cluster nodes
4. **Analytics**: Leverage built-in graph algorithms for insights
5. **Privacy**: Implement anonymization, k-anonymity, and consent management
6. **Performance**: Batch processing, indexing, and async operations

For production deployments, consider:
- Load balancing and failover
- Persistent storage for long-term analytics
- Real-time alerting and monitoring
- Integration with sensor networks and IoT platforms
- Compliance with GDPR, CCPA, and other privacy regulations

## Further Reading

- [Grapple Analytics Guide](./graph-analytics.md)
- [Distributed Features](../advanced/distributed-features.md)
- [Performance Optimization](../advanced/performance.md)
- [Privacy Best Practices](../advanced/privacy.md)
