%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ~w{config lib test},
        excluded: ["test/test_helper.exs"]
      },
      strict: true,
      color: true,
      checks: [
        {Credo.Check.Readability.MaxLineLength, max_length: 100}
      ]
    }
  ]
}
