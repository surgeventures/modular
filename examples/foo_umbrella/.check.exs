[
  skipped: false,
  tools: [
    {:compiler_test,
      command: "mix compile --warnings-as-errors --force",
      env: %{"MIX_ENV" => "test"}},
    {:ex_unit, run_after: [:compiler_test]}
  ]
]
