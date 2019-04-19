defmodule Modular.ContractTests do
  @moduledoc """
  Ensures that public contracts are always covered with tests.

  Tests dedicated to contracts serve as living documentation for them. They present a complete
  sample usage along with prerequisites required for all functions to succeed. As such, they have a
  great advantage over textual documentation by always being up to date (as long as tests are being
  run as they should be). Besides that, as entry points for all the code inside their areas, testing
  them is a reasonable choice anyway for the purpose of validating the integration.

  The convention in Elixir is to name specific module's test the same as the module itself, just
  with the `Test` suffix and that's exactly the convention that this check verifies.

  ## Usage

  Include the check in your `.credo.exs`:

      %{
        configs: [
          %{
            name: "default",
            checks: [
              {Modular.ContractTests, []}
            ]
          }
        ]
      }

  You can specify the following options:

  - `ignore_names` - all modules matching this regex (or list of regexes) will be ignored

  ## Notes

  1. This check doesn't measure the test coverage, nor does it ensure that all public functions are
     indeed tested - it simply makes sure that developer looking for specific contract's test suite
     will have something to find.

  2. This check ignores modules that have undefined publicity, so it's recommended to complement it
     with Credo's own `Credo.Check.Readability.ModuleDoc` in order to ensure that all modules are
     forced to define it via the `@moduledoc` attribute.

  2. In current implementation, test module is required even for modules that don't provide any
     public functions (eg. structs). They should have a corresponding empty test modules for the
     check to pass. This helps to facilitate tests for structs, exceptions and DSLs that don't
     define functions but may need testing either way.

  """

  @checkdoc @moduledoc

  @explanation [
    check: @checkdoc,
    params: [
      ignore_names: "All modules matching this regex (or list of regexes) will be ignored"
    ]
  ]

  @default_params [
    ignore_names: []
  ]

  use Credo.Check, category: :design, run_on_all: true

  alias Credo.Execution.ExecutionIssues
  alias Modular.ModDesc

  def run(source_files, exec, params \\ []) do
    source_files
    |> ModDesc.from_source()
    |> ModDesc.put_public()
    |> find_modules_without_tests(params)
    |> append_issues(exec, params)
  end

  defp find_modules_without_tests(modules, params) do
    ignore_names = Params.get(params, :ignore_names, @default_params)

    checkable_modules =
      modules
      |> ModDesc.reject_names(ignore_names)
      |> ModDesc.reject_names(~r/Test$/)
      |> filter_public()

    test_modules =
      modules
      |> Enum.map(& &1.name)
      |> Enum.filter(&String.match?(&1, ~r/Test$/))

    Enum.reject(checkable_modules, &Enum.member?(test_modules, "#{&1.name}Test"))
  end

  defp filter_public(modules) do
    Enum.filter(modules, fn
      %{public: true} -> true
      _ -> false
    end)
  end

  defp append_issues(modules_without_tests, exec, params) do
    Enum.each(modules_without_tests, fn mod ->
      source_file = mod.source_file

      issue =
        format_issue(
          IssueMeta.for(source_file, params),
          message: "#{mod.name} has no test module #{mod.name}Test",
          trigger: mod.name,
          line_no: mod.line
        )

      ExecutionIssues.append(exec, source_file, issue)
    end)
  end
end
