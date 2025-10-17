[
  # Mix.Task behavior is not available in PLT as Mix is compile-time only
  {"lib/mix/tasks/bench.ex", :callback_info_missing},

  # MapSet opaque type warnings - these are inherent to Dialyzer's type system
  # and cannot be resolved without modifying MapSet's internal implementation
  {"lib/grapple/search/text_analyzer.ex", :call_without_opaque},
  {"lib/grapple/visualization/ascii_renderer.ex", :call_without_opaque}
]
