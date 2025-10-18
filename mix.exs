defmodule Grapple.MixProject do
  use Mix.Project

  def project do
    [
      app: :grapple,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      aliases: aliases(),
      compilers: Mix.compilers()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia, :crypto, :ssl],
      mod: {Grapple.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 0.20.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:plug_cowboy, "~> 2.6"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:gettext, "~> 0.20"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      # Authentication & Authorization
      {:joken, "~> 2.6"},
      {:bcrypt_elixir, "~> 3.0"},
      {:comeonin, "~> 5.4"},
      {:guardian, "~> 2.3"},
      {:bodyguard, "~> 2.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:benchee_html, "~> 1.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      list_unused_filters: true,
      # Only treat errors as failures, not warnings
      flags: [:error_handling, :underspecs]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind grapple", "esbuild grapple"],
      "assets.deploy": [
        "tailwind grapple --minify",
        "esbuild grapple --minify",
        "phx.digest"
      ],
      bench: [
        "run benchmarks/core/node_operations_bench.exs",
        "run benchmarks/core/edge_operations_bench.exs",
        "run benchmarks/core/traversal_bench.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Grapple Graph Database",
      source_url: "https://github.com/anthropics/grapple",
      homepage_url: "https://github.com/anthropics/grapple",
      extras: [
        "README.md",
        "README_DISTRIBUTED.md": [title: "Distributed Mode Guide"],
        "GUIDE.md": [title: "Complete User Guide"],
        "DISTRIBUTED_ROADMAP.md": [title: "Distributed Development Roadmap"],
        "guides/tutorials/onboarding.md": [title: "Onboarding Tutorial"],
        "guides/tutorials/quick-start.md": [title: "5-Minute Quick Start"],
        "guides/examples/social-network.md": [title: "Social Network Example"],
        "guides/advanced/performance.md": [title: "Performance Guide"],
        "guides/advanced/architecture.md": [title: "Architecture Overview"]
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md",
          "guides/tutorials/quick-start.md",
          "guides/tutorials/onboarding.md"
        ],
        "User Guides": [
          "GUIDE.md",
          "guides/examples/social-network.md"
        ],
        "Distributed Features": [
          "README_DISTRIBUTED.md",
          "DISTRIBUTED_ROADMAP.md"
        ],
        "Advanced Topics": [
          "guides/advanced/performance.md",
          "guides/advanced/architecture.md"
        ]
      ],
      groups_for_modules: [
        "Core API": [
          Grapple,
          Grapple.Storage.EtsGraphStore
        ],
        "Query Engine": [
          Grapple.Query.Executor,
          Grapple.Query.Parser
        ],
        "CLI Interface": [
          Grapple.CLI.Shell,
          Grapple.CLI.Autocomplete
        ],
        Visualization: [
          Grapple.Visualization.AsciiRenderer
        ],
        "Basic Clustering": [
          Grapple.Cluster.NodeManager
        ],
        "Distributed Coordination": [
          Grapple.Distributed.ClusterManager,
          Grapple.Distributed.HealthMonitor,
          Grapple.Distributed.Discovery,
          Grapple.Distributed.Schema
        ],
        "Data Lifecycle Management": [
          Grapple.Distributed.LifecycleManager,
          Grapple.Distributed.PlacementEngine,
          Grapple.Distributed.PersistenceManager
        ],
        "Replication & Consistency": [
          Grapple.Distributed.ReplicationEngine
        ],
        Orchestration: [
          Grapple.Distributed.Orchestrator
        ],
        "Web Dashboard": [
          GrappleWeb.Endpoint,
          GrappleWeb.Router
        ]
      ]
    ]
  end
end
