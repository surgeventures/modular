[
  tools: [
    {:dialyzer, false},
    {:sobelow, false},
    {:umbrella_root,
      command: "mix do clean, check",
      cd: "examples/foo_umbrella"},
    {:umbrella_foo,
      command: "mix do clean, check",
      cd: "examples/foo_umbrella/apps/foo",
      run_after: [:umbrella_root]},
    {:umbrella_bar,
      command: "mix do clean, check",
      cd: "examples/foo_umbrella/apps/bar",
      run_after: [:umbrella_foo]},
  ]
]
