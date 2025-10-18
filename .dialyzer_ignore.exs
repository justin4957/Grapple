[
  # Mix.Task behavior is not available in PLT as Mix is compile-time only
  {"lib/mix/tasks/bench.ex", :callback_info_missing},

  # Analytics module: Type specs include error cases that aren't reached in practice
  {"lib/grapple/analytics.ex", :extra_range},

  # Profiler module: Type specs are supertypes of actual return values
  {"lib/grapple/performance/profiler.ex", :contract_supertype}
]
