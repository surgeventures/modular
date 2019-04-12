defmodule Modular.Check.AreaAccess do
  @moduledoc """
  Ensures that module access is limited to given area's public contract.

  You want to divide your code into cohesive areas* that group common functionalities. These areas
  should provide external interfaces that act as contracts with clients and they should encapsulate
  implementation details inside their private parts so that it is impossible (and just unsuggested)
  for any of the clients to know about or depend upon these details.

  > _*_ We could replace the word "area" with "bucket", "context", "component", "package",
  > "assembly" or... "module" - but not as in "Elixir module defined via `defmodule`" but rather as
  > "separate software unit that implements related functionality, expresses external interface and
  > encapsulates implementation details". We'll stick to the word "area" though.

  In Elixir, we organize and encapsulate code into modules with `defp` as a tool for hiding the
  in-module private implementations. It's useful as long as the code fits into single module, but
  there's no means of access control across multiple modules ([at least not
  yet](https://elixirforum.com/t/proposal-private-modules-general-discussion/19374)). There's also a
  convention to differentiate modules as either public APIs or private implementations by filling
  the `@moduledoc` attribute with contract documentation or `false` respectively (as explained in
  [official Elixir guidelines about writing
  docs](https://hexdocs.pm/elixir/writing-documentation.html#documentation-code-comments)). It's
  better than nothing, but as all modules are equally accessible and the meaning of `@moduledoc` is
  often misinterpreted, there's no out-of-the-box solution for implementing areas formed out of
  multiple modules and ensuring that no client will cross the boundary of area interface.

  This check aims to solve these problems by mapping dependencies among modules and verifying that
  the boundary of area is not abused. It applies the following ground rules:

  1. Areas are formed from a root module that has `@moduledoc` string filled and that acts as
     interface and from arbitrary number of implementation submodules with `@moduledoc false`.

  2. Area interfaces are globally accessible while area implementations are only accessible by
     modules within the same area (ie. that share the same area root module).

  3. Areas may be nested within other areas in which case they are also globally accessible and they
     are stil considered independent from their parent areas (ie. they can only reference parent
     interface and the parent can only reference their interface).

  ## Usage

  Include the check in your `.credo.exs`:

      %{
        configs: [
          %{
            name: "default",
            checks: [
              {Modular.Check.AreaAccess, ignore_callers: [~r/Test$/]}
            ]
          }
        ]
      }

  You can specify the following options:

  - `ignore_callers` - all caller modules matching this regex (or list of regexes) will be ignored
  - `ignore_deps` - all references to modules matching this regex (or list of regexes) will be
    ignored

  ## Example

  Let's consider the following application:

      defmodule Invoicing do
        @moduledoc "Issues and manages client invoices."

        @doc "Create new invoice with specified items."
        def create_invoice(items), do: __MODULE__.CreateInvoice.call(items)

        @doc "Send specified invoice to specified e-mail address."
        def create_invoice(invoice_id, email), do: __MODULE__.SendInvoice.call(invoice_id, email)
      end

      defmodule Invoicing.Repo do
        @moduledoc false

        # ...
      end

      defmodule Invoicing.CreateInvoice do
        @moduledoc false

        def call(items) do
          invoice = Invoicing.Invoice.build(items)
          Invoicing.Repo.insert!(invoice)
          Invoicing.SendInvoice.call(invoice.id, "invoices@backoffice.com")

          invoice
        end
      end

      defmodule Invoicing.SendInvoice do
        @moduledoc false

        def call(invoice_id, email), do: # ...
      end

      defmodule Invoicing.Invoice do
        @moduledoc "Represents an issued invoice."

        defstruct [:id, :items, :number]

        def build(items) do
          %__MODULE__{
            id: UUID.uuid4(),
            items: items,
            number: __MODULE__.GenerateNumber.call()
          }
        end
      end

      defmodule Invoicing.Invoice.GenerateNumber do
        @moduledoc false

        def call do
          # ...
        end
      end

  Here's how the check applies to the example above:

  1. `Invoicing` is the main publicly accessible area so it fills `@moduledoc`.

  2. `Invoicing` puts its implementation into private services `CreateInvoice` and `SendInvoice`.

  3. `Invoicing` returns `Invoice` to external clients therefore `Invoice` is also public.

  4. `Invoice` as separate area also has its own private service `GenerateNumber`.

  5. `Invoicing` can't directly use `GenerateNumber` and `Invoice` can't use eg. `SendInvoice`.

  ## Notes

  1. It's impossible to map all dependencies of modules in Elixir due to dynamic nature of the
     language (eg. the `apply/3` function). Credo check is further limited by executing static AST
     analysis without compilation and only on a set of linted files. It's a best effort solution.

  2. This check ignores deps that have undefined publicity, so it's recommended to complement it
     with Credo's own `Credo.Check.Readability.ModuleDoc` in order to ensure that all modules are
     forced to define it via the `@moduledoc` attribute.

  3. Current implementation of this check follows idiomatic Elixir with a supoort for just one
     global level of publicity indicated via `@moduledoc` string - there's no concept of "public
     within an app or within specific parent area" although [there are discussions about adding it
     to Elixir
     language](https://elixirforum.com/t/proposal-private-modules-general-discussion/19374). Right
     now, you must choose between eg. making app-wide modules public for sake of accessing them in
     nested areas or wrapping them in single larger area.

  4. In current implementation, usage of dependencies is not tracked down to specific points inside
     the caller module, but rather to its `defmodule`. This may be an inconvenience but it also
     reduces the number of duplicate issues for multiple references to the same dep within a single
     caller module.

  5. For unit testing purposes, access to private modules is allowed for callers with the same name,
     just with `Test` suffix appended. Of course, you may just as well decide to exclude all test
     files from the check by setting `ignore_callers: [~r/Test$/]`.

  """

  @explanation [
    check: @moduledoc,
    params: [
      ignore_callers:
        "All caller modules matching this regex (or list of regexes) will be ignored",
      ignore_deps:
        "All references to modules matching this regex (or list of regexes) will be ignored."
    ]
  ]

  @default_params [
    ignore_callers: [],
    ignore_deps: []
  ]

  use Credo.Check, base_priority: :high, category: :design, run_on_all: true

  alias Credo.Execution.ExecutionIssues
  alias Modular.ModDesc

  def run(source_files, exec, params \\ []) do
    source_files
    |> ModDesc.from_source()
    |> ModDesc.put_deps()
    |> ModDesc.put_public()
    |> ModDesc.put_public_ancestor()
    |> find_forbidden_deps(params)
    |> append_issues(exec, params)
  end

  defp find_forbidden_deps(modules, params) do
    ignore_callers = Params.get(params, :ignore_callers, @default_params)
    ignore_deps = Params.get(params, :ignore_deps, @default_params)
    checkable_callers = filter_module_names(modules, ignore_callers)

    checkable_deps =
      modules
      |> filter_module_names(ignore_deps)
      |> filter_with_publicity()

    Enum.flat_map(checkable_callers, fn %ModDesc{deps: deps} = mod ->
      deps
      |> Enum.map(&Enum.find(checkable_deps, fn %ModDesc{name: name} -> &1 == name end))
      |> Enum.filter(& &1)
      |> Enum.filter(&(not allowed_dep?(mod, &1)))
      |> Enum.map(&{mod, &1})
    end)
  end

  defp filter_module_names(modules, ignore_deps) do
    Enum.filter(modules, fn %ModDesc{name: name} ->
      not matches_any?(name, ignore_deps)
    end)
  end

  defp matches_any?(name, list) when is_list(list) do
    Enum.any?(list, &matches_any?(name, &1))
  end

  defp matches_any?(name, string) when is_binary(string) do
    String.contains?(name, string)
  end

  defp matches_any?(name, regex) do
    String.match?(name, regex)
  end

  defp filter_with_publicity(modules) do
    Enum.filter(modules, fn
      %{public: _} -> true
      _ -> false
    end)
  end

  defp allowed_dep?(caller, dep) do
    cond do
      dep.public ->
        true

      dep.public_ancestor == caller.public_ancestor ->
        true

      dep.name <> "Test" == caller.name ->
        true

      true ->
        false
    end
  end

  defp append_issues(forbidden_deps, exec, params) do
    Enum.each(forbidden_deps, fn {caller, dep} ->
      source_file = caller.source_file

      issue =
        format_issue(
          IssueMeta.for(source_file, params),
          message: "Reference to #{dep.name} violates area #{dep.public_ancestor}",
          trigger: caller.name,
          line_no: caller.line
        )

      ExecutionIssues.append(exec, source_file, issue)
    end)
  end
end
