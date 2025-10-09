# Grapple Web Dashboard

A real-time Phoenix LiveView web dashboard for the Grapple graph database, providing interactive visualization, query building, analytics, and cluster monitoring capabilities.

## Features

### 🎯 Dashboard Home
- **Real-time statistics**: View total nodes, edges, graph density, and average degree
- **Quick actions**: Navigate to different sections of the dashboard
- **Activity monitoring**: Track recent database activity

### 🗺️ Graph Visualization
- **Interactive graph display**: Visualize your entire graph database
- **Node and edge inspection**: View detailed information about nodes and their relationships
- **Cytoscape.js integration**: Pan, zoom, and explore your graph interactively (ready for integration)

### 🔍 Query Builder
- **Cypher query interface**: Execute Cypher queries directly from the browser
- **Syntax highlighting**: Visual query editor with examples
- **Real-time results**: View query results instantly
- **Error handling**: Clear error messages for debugging

### 📈 Analytics Dashboard
- **PageRank**: Calculate node importance scores
- **Betweenness Centrality**: Find bridge nodes in the graph
- **Clustering Coefficient**: Measure local clustering
- **Community Detection**: Discover community structures using label propagation
- **Shortest Path**: Find optimal paths between nodes
- **Connected Components**: Identify disconnected subgraphs

### 🖥️ Cluster Monitoring
- **Node status**: View all nodes in your distributed cluster
- **Health monitoring**: Real-time cluster health status
- **Connection tracking**: See which nodes are connected
- **Standalone mode detection**: Clear indicators when distributed mode is disabled

## Getting Started

### Prerequisites

- Elixir 1.18+
- Erlang/OTP 26+
- Node.js (for asset compilation)

### Installation

1. **Install dependencies**:
   ```bash
   mix deps.get
   cd assets && npm install && cd ..
   ```

2. **Set up assets**:
   ```bash
   mix assets.setup
   mix assets.build
   ```

3. **Start the Phoenix server**:
   ```bash
   mix phx.server
   ```

4. **Access the dashboard**:
   Open your browser and navigate to [`http://localhost:4000`](http://localhost:4000)

### For Distributed Mode

To enable cluster monitoring features, start the application in distributed mode:

```bash
iex --name node1@localhost --cookie secret -S mix phx.server
```

Then connect additional nodes:

```bash
iex --name node2@localhost --cookie secret -S mix
```

Inside the IEx shell of node2:
```elixir
Node.connect(:"node1@localhost")
```

## Dashboard Routes

- `/` - Dashboard home with statistics and quick actions
- `/graph` - Interactive graph visualization
- `/query` - Cypher query builder and executor
- `/analytics` - Graph analytics and algorithms
- `/cluster` - Cluster status and monitoring

## Architecture

### Frontend Stack
- **Phoenix LiveView**: Real-time, server-rendered UI
- **TailwindCSS**: Utility-first CSS framework for styling
- **Cytoscape.js**: Graph visualization library (ready for integration)
- **Heroicons**: Beautiful hand-crafted SVG icons

### Backend Integration
The dashboard integrates directly with:
- `Grapple` - Core graph database API
- `Grapple.Analytics.*` - Graph analytics modules
- `Grapple.Query.Executor` - Query execution engine
- `Grapple.Distributed.*` - Distributed coordination modules

## Development

### Project Structure

```
lib/grapple_web/
├── components/
│   ├── core_components.ex      # Reusable UI components
│   ├── layouts.ex              # Layout templates
│   └── layouts/
│       ├── root.html.heex      # Root layout
│       └── app.html.heex       # App layout with navigation
├── controllers/
│   ├── error_html.ex           # HTML error handling
│   └── error_json.ex           # JSON error handling
├── live/
│   ├── dashboard_live/
│   │   └── index.ex            # Dashboard home
│   ├── graph_live/
│   │   └── index.ex            # Graph visualization
│   ├── query_live/
│   │   └── index.ex            # Query builder
│   ├── analytics_live/
│   │   └── index.ex            # Analytics page
│   └── cluster_live/
│       └── index.ex            # Cluster monitoring
├── endpoint.ex                  # Phoenix endpoint
├── gettext.ex                   # Internationalization
├── router.ex                    # Route definitions
└── telemetry.ex                 # Metrics and monitoring

assets/
├── css/
│   └── app.css                 # Main stylesheet
├── js/
│   └── app.js                  # Main JavaScript
├── vendor/
│   └── topbar.js               # Progress bar
└── tailwind.config.js          # Tailwind configuration

config/
├── config.exs                  # Main configuration
├── dev.exs                     # Development config
├── prod.exs                    # Production config
├── test.exs                    # Test config
└── runtime.exs                 # Runtime configuration
```

### Adding Custom Visualizations

To add custom graph visualizations using Cytoscape.js:

1. Create a LiveView hook in `assets/js/app.js`:
   ```javascript
   let Hooks = {}
   Hooks.CytoscapeGraph = {
     mounted() {
       // Initialize Cytoscape
       const cy = cytoscape({
         container: this.el,
         elements: JSON.parse(this.el.dataset.elements)
       })
     }
   }

   let liveSocket = new LiveSocket("/live", Socket, {
     params: {_csrf_token: csrfToken},
     hooks: Hooks
   })
   ```

2. Pass graph data from your LiveView:
   ```elixir
   <div id="graph" phx-hook="CytoscapeGraph" data-elements={Jason.encode!(@graph_data)} />
   ```

### Customizing Styles

The dashboard uses TailwindCSS. Customize colors and styles in `assets/tailwind.config.js`:

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        'graph-node': '#3B82F6',
        'graph-edge': '#6B7280',
      }
    },
  },
}
```

## API Integration

The dashboard calls these Grapple API functions:

### Core API
- `Grapple.list_nodes/0` - List all nodes
- `Grapple.list_edges/0` - List all edges
- `Grapple.get_node/1` - Get a specific node
- `Grapple.Query.Executor.execute/1` - Execute a query

### Analytics API
- `Grapple.Analytics.Centrality.pagerank/0`
- `Grapple.Analytics.Centrality.betweenness_centrality/0`
- `Grapple.Analytics.Metrics.clustering_coefficient/0`
- `Grapple.Analytics.Community.label_propagation/0`
- `Grapple.Analytics.Community.connected_components/0`

### Distributed API
- `Node.self/0` - Current node name
- `Node.list/0` - List connected nodes

## Performance Considerations

- **LiveView Benefits**: No need for a separate API, reduced complexity, automatic handling of WebSocket connections
- **Efficient Rendering**: Only changed parts of the page are updated
- **Lazy Loading**: Large graphs can be paginated or filtered
- **Caching**: Consider implementing caching for expensive analytics operations

## Future Enhancements

- [ ] Full Cytoscape.js integration for interactive graph visualization
- [ ] Real-time graph updates via PubSub
- [ ] Query history and favorites
- [ ] Export functionality (CSV, JSON, GraphML)
- [ ] Advanced filtering and search
- [ ] Custom analytics dashboard builder
- [ ] Performance profiling tools
- [ ] Graph diff visualization
- [ ] Multi-tenant support
- [ ] Dark mode

## Troubleshooting

### Dashboard not loading?
- Ensure Phoenix is running: `mix phx.server`
- Check that port 4000 is not in use
- Verify assets are compiled: `mix assets.build`

### Cluster page shows "Not Enabled"?
- Start Elixir in distributed mode with `--name` and `--cookie` flags
- Ensure nodes can discover each other

### Analytics not working?
- Verify the graph has data (nodes and edges)
- Check that analytics modules are compiled
- Review compilation warnings for missing functions

## Contributing

Contributions are welcome! Please ensure:
- Code follows Elixir style guidelines
- LiveView best practices are followed
- UI is responsive and accessible
- Changes are documented

## License

Apache 2.0 License - See LICENSE file for details

## Support

For issues and feature requests, please file an issue on GitHub.
