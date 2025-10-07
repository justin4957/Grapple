# Troubleshooting Guide

This guide helps you diagnose and fix common issues with Grapple.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Compilation Errors](#compilation-errors)
3. [Runtime Errors](#runtime-errors)
4. [Performance Issues](#performance-issues)
5. [Distributed Mode Issues](#distributed-mode-issues)
6. [Testing Issues](#testing-issues)
7. [Memory Issues](#memory-issues)
8. [Getting Help](#getting-help)

## Installation Issues

### Issue: Elixir Version Mismatch

**Error:**
```
You're trying to run :grapple on Elixir v1.16.x but it requires Elixir ~> 1.18
```

**Solution:**
1. Check your Elixir version:
   ```bash
   elixir --version
   ```
2. Install Elixir 1.18 or later:
   ```bash
   # Using asdf
   asdf install elixir 1.18.1

   # Using homebrew (macOS)
   brew upgrade elixir
   ```

### Issue: Dependency Resolution Failures

**Error:**
```
Failed to use "xxx" because
  mix.lock: xxx (version)
  mix.exs:  xxx (version)
```

**Solution:**
```bash
# Clean dependencies and reinstall
mix deps.clean --all
rm -rf _build
mix deps.get
mix compile
```

### Issue: Cannot Find Mix

**Error:**
```
mix: command not found
```

**Solution:**
Ensure Elixir is installed and in your PATH:
```bash
# Check if Elixir is installed
which elixir

# If not installed, install it
# macOS
brew install elixir

# Ubuntu/Debian
sudo apt-get install elixir
```

## Compilation Errors

### Issue: Mnesia Undefined Functions

**Error:**
```
warning: :mnesia.transaction/1 is undefined
```

**Solution:**
Add `:mnesia` to `extra_applications` in `mix.exs`:
```elixir
def application do
  [
    extra_applications: [:logger, :mnesia],
    mod: {Grapple.Application, []}
  ]
end
```

### Issue: Compilation Warnings as Errors

**Error:**
```
warning: unused variable "foo"
** (Mix) Compilation failed
```

**Solution:**
1. Fix the warnings by prefixing unused variables with `_`:
   ```elixir
   # Before
   def function(unused_param) do
     :ok
   end

   # After
   def function(_unused_param) do
     :ok
   end
   ```

2. Or temporarily disable warnings-as-errors:
   ```bash
   mix compile --no-warnings-as-errors
   ```

### Issue: Module Not Found

**Error:**
```
** (UndefinedFunctionError) function Grapple.SomeModule.function/1 is undefined
```

**Solution:**
1. Ensure the module exists and is compiled
2. Check the module name spelling
3. Recompile:
   ```bash
   mix clean
   mix compile
   ```

## Runtime Errors

### Issue: Node Not Found

**Error:**
```elixir
{:error, :node_not_found}
```

**Common Causes:**
1. Node ID doesn't exist
2. Node was deleted
3. Using wrong node ID type

**Solution:**
```elixir
# Verify node exists
case Grapple.get_node(node_id) do
  {:ok, node} -> # Node exists
  {:error, :node_not_found} -> # Create it or handle error
end

# List all nodes to debug
nodes = Grapple.list_nodes()
IO.inspect(nodes, label: "All nodes")
```

### Issue: ETS Table Not Found

**Error:**
```
** (ArgumentError) argument error
    :ets.lookup(:grapple_nodes, id)
```

**Solution:**
Ensure Grapple application is started:
```elixir
# Start the application
{:ok, _} = Application.ensure_all_started(:grapple)

# Or in tests
Application.start(:grapple)
```

### Issue: Process Not Running

**Error:**
```
** (exit) exited in: GenServer.call(Grapple.Storage.EtsGraphStore, ...)
** (EXIT) no process
```

**Solution:**
Start the required GenServers:
```elixir
# Check if process is running
Process.whereis(Grapple.Storage.EtsGraphStore)

# Start the application
Application.ensure_all_started(:grapple)

# Or restart
Application.stop(:grapple)
Application.start(:grapple)
```

## Performance Issues

### Issue: Slow Query Performance

**Symptoms:**
- Queries taking longer than expected
- High CPU usage
- System becomes unresponsive

**Diagnosis:**
```elixir
# Enable performance monitoring
{:ok, session} = Grapple.Performance.Profiler.start_session()

# Run your operations
Grapple.find_nodes_by_property(:category, "test")

# Generate report
{:ok, report} = Grapple.Performance.Profiler.generate_report(session)
IO.inspect(report, pretty: true)
```

**Solutions:**
1. **Add Indexes**: Ensure properties used in queries are indexed
   ```elixir
   # Properties are automatically indexed on creation
   {:ok, node} = Grapple.create_node(%{category: "test"})
   ```

2. **Limit Result Sets**: Use pagination or filters
   ```elixir
   # Instead of getting all nodes
   nodes = Grapple.list_nodes() |> Enum.take(100)
   ```

3. **Optimize Traversals**: Limit depth
   ```elixir
   # Limit traversal depth
   {:ok, nodes} = Grapple.traverse(start_node, :out, max_depth: 3)
   ```

### Issue: Memory Usage Growing

**Symptoms:**
- Application memory usage increases over time
- System runs out of memory
- OOM (Out of Memory) errors

**Diagnosis:**
```elixir
# Analyze memory usage
analysis = Grapple.Performance.Profiler.analyze_memory_usage()
IO.inspect(analysis, pretty: true)

# Check ETS table sizes
:ets.info(:grapple_nodes, :size)
:ets.info(:grapple_edges, :size)
```

**Solutions:**
1. **Clean Up Old Data**:
   ```elixir
   # Delete unused nodes
   Grapple.delete_node(old_node_id)
   ```

2. **Enable Distributed Mode** for larger datasets
3. **Monitor Memory**: Use the profiling tools regularly

See [Memory Issues](#memory-issues) for more details.

## Distributed Mode Issues

### Issue: Nodes Cannot Connect

**Error:**
```
{:error, :connection_failed}
```

**Common Causes:**
1. Cookie mismatch
2. Network issues
3. Firewall blocking EPMD port
4. Node names not configured

**Solutions:**
1. **Check Node Names**:
   ```elixir
   # Ensure nodes have proper names
   # Start with: iex --name node1@hostname
   node()  # Should return something@hostname, not :nonode@nohost
   ```

2. **Verify Cookies Match**:
   ```elixir
   # Check cookie
   Node.get_cookie()

   # Set matching cookie on both nodes
   Node.set_cookie(:my_secret_cookie)
   ```

3. **Test Basic Connectivity**:
   ```elixir
   # Try to ping the other node
   Node.ping(:node2@hostname)  # Should return :pong
   ```

4. **Check Firewall**:
   ```bash
   # EPMD runs on port 4369
   # Erlang distribution uses random high ports
   # Ensure these are open in your firewall
   ```

### Issue: Cluster Health Degraded

**Symptoms:**
```elixir
Grapple.Distributed.HealthMonitor.get_cluster_health()
#=> %{overall_status: :degraded, ...}
```

**Solutions:**
1. **Check Node Status**:
   ```elixir
   info = Grapple.Distributed.ClusterManager.get_cluster_info()
   IO.inspect(info, label: "Cluster Info")
   ```

2. **Force Health Check**:
   ```elixir
   Grapple.Distributed.HealthMonitor.force_health_check()
   ```

3. **Review Logs** for connection errors

### Issue: Data Replication Failures

**Error:**
```
{:error, :replication_failed}
```

**Solutions:**
1. **Verify Node Connectivity**
2. **Check Mnesia Status**:
   ```elixir
   :mnesia.system_info(:running_db_nodes)
   ```

3. **Review Replication Settings**

## Testing Issues

### Issue: Tests Failing Intermittently

**Common Causes:**
1. Async tests with shared state
2. Timing issues
3. ETS tables not cleaned between tests

**Solutions:**
1. **Use `async: false` for tests with shared state**:
   ```elixir
   use ExUnit.Case, async: false
   ```

2. **Clean ETS Tables in Setup**:
   ```elixir
   setup do
     # Clean up before each test
     on_exit(fn ->
       Application.stop(:grapple)
       Application.start(:grapple)
    end)

     :ok
   end
   ```

3. **Add Timeouts**:
   ```elixir
   test "async operation" do
     # Give async operations time to complete
     :timer.sleep(100)
     assert eventually_true_condition()
   end
   ```

### Issue: Coverage Report Not Generated

**Error:**
```
** (Mix) The task "coveralls" could not be found
```

**Solution:**
Ensure excoveralls is installed:
```bash
mix deps.get
MIX_ENV=test mix coveralls.html
```

## Memory Issues

### Issue: ETS Memory Growing Unbounded

**Symptoms:**
- ETS tables consuming excessive memory
- Memory not being reclaimed

**Diagnosis:**
```elixir
# Check ETS table memory
tables = Grapple.Performance.Profiler.get_ets_table_memory()
IO.inspect(tables, pretty: true)

# Check total memory
:erlang.memory()
```

**Solutions:**
1. **Delete Unused Data**:
   ```elixir
   # Remove old nodes and edges
   old_ids = get_old_node_ids()
   Enum.each(old_ids, &Grapple.delete_node/1)
   ```

2. **Enable Lifecycle Management** (distributed mode):
   ```elixir
   # Classify data for automatic cleanup
   Grapple.Distributed.LifecycleManager.classify_data(
     "temp_data",
     :ephemeral
   )
   ```

3. **Restart Application Periodically** (if memory leaks persist)

### Issue: Mnesia Disc Full

**Error:**
```
** (EXIT) {:"system limit", ...}
```

**Solution:**
1. **Check Disc Usage**:
   ```elixir
   :mnesia.system_info(:db_nodes)
   :mnesia.system_info(:tables)
   ```

2. **Clean Up Mnesia**:
   ```bash
   # Stop application
   # Remove Mnesia directory
   rm -rf Mnesia.*
   # Restart application
   ```

3. **Increase Disc Space** or **Enable DETS** for cold storage

## Common Error Patterns

### Pattern: `{:error, :invalid_properties}`

**Cause:** Property validation failed

**Check:**
- Property keys are atoms or strings
- Values are valid types
- No reserved keys used

### Pattern: `{:error, :node_not_found}`

**Cause:** Referenced node doesn't exist

**Check:**
- Node ID is correct
- Node wasn't deleted
- Node was created successfully

### Pattern: `{:error, :edge_not_found}`

**Cause:** Referenced edge doesn't exist

**Check:**
- Edge ID is correct
- Edge wasn't deleted
- Both nodes exist

## Getting Help

If you're still stuck after trying these solutions:

1. **Search Existing Issues**: Check if someone else has encountered the same problem
   - https://github.com/justin4957/Grapple/issues

2. **Check Documentation**:
   - [Complete User Guide](GUIDE.md)
   - [Performance Guide](PERFORMANCE.md)
   - [Testing Guide](TESTING.md)
   - [FAQ](FAQ.md)

3. **Enable Debug Logging**:
   ```elixir
   # In config/config.exs
   config :logger, level: :debug
   ```

4. **Create an Issue**:
   - Include Elixir/Erlang versions
   - Provide minimal reproduction steps
   - Include relevant error messages
   - Show what you've tried

5. **Gather System Information**:
   ```elixir
   # Get versions
   System.version()
   :erlang.system_info(:otp_release)

   # Get stats
   Grapple.get_stats()

   # Get memory info
   :erlang.memory()
   ```

## Debugging Tips

### Enable Verbose Logging

```elixir
# In config/dev.exs or config/test.exs
config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n"
```

### Use IEx for Interactive Debugging

```elixir
# Add to your code
require IEx; IEx.pry()

# Or use IO.inspect with labels
result
|> IO.inspect(label: "After step 1")
|> process_further()
|> IO.inspect(label: "After step 2")
```

### Monitor System Resources

```bash
# In another terminal
watch -n 1 'ps aux | grep beam'

# Or use :observer
iex> :observer.start()
```

---

Still having issues? Don't hesitate to [open an issue](https://github.com/justin4957/Grapple/issues/new) with details about your problem!
