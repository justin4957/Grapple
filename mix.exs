defmodule Grapple.MixProject do
  use Mix.Project

  def project do
    [
      app: :grapple,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Grapple.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:benchee_html, "~> 1.0", only: :dev, runtime: false}
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
        "Visualization": [
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
        "Orchestration": [
          Grapple.Distributed.Orchestrator
        ]
      ]
    ]
  end
end
