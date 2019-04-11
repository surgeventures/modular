defmodule Modular.Check.AreaAccess do
  @moduledoc """
  Module references should be limited to specific area's public interfaces.

  You want to divide your code into cohesive areas that group common functionalities. These areas
  should provide external interfaces that act as contracts with clients and they should encapsulate
  implementation details inside their private parts so that it is impossible (and just unsuggested)
  for any of the clients to know about or depend upon these details.

  In Elixir, we organize and encapsulate code into modules with `defp` as a tool for hiding the
  in-module private implementations. It's useful as long as the code fits into single module, but
  there's no means of access control across multiple modules. There's also a convention to
  differentiate modules as either public APIs or private implementations by filling the `@moduledoc`
  attribute with contract documentation or `false` respectively. It's better than nothing, but as
  all modules are equally accessible and the meaning of `@moduledoc` is often misinterpreted,
  there's no out-of-the-box solution for implementing areas formed out of multiple modules and
  ensuring that no client will cross the boundary of area interface.

  This check aims to solve these problems by mapping dependencies among modules and verifying that
  the boundary of area is not abused. It follows the following ground rules:

  1. Areas are formed from a root module that has `@moduledoc` string filled and that acts as
     interface and from arbitrary number of implementation submodules with `@moduledoc false`.

  2. Area interfaces are globally accessible while area implementations are only accessible by
     modules within the same area (ie. that share the same root module).

  3. Areas may be nested within other areas in which case they are also globally accessible and they
     are stil considered independent from their parent areas (ie. they can only reference parent
     interface and the parent can only reference their interface).

  ## Notes

  1. It's impossible to map all dependencies of modules in Elixir due to dynamic nature of the
     language (eg. the `apply/3` function). Credo check is further limited by executing static AST
     analysis without compilation and only on a set of linted files. It's a best effort solution.

  2. This check ignores deps that have undefined publicity, so it's recommended to complement it
     with Credo's own `Credo.Check.Readability.ModuleDoc` in order to ensure that all modules are
     forced to define it via the `@moduledoc` attribute.

  3. In current implementation, usage of dependencies is not tracked down to specific points inside
     the caller module, but rather to its `defmodule`. This may be an inconvenience but it also
     reduces the number of duplicate issues for multiple references to the same dep within a single
     caller module.

  """

  @explanation [
    check: @moduledoc,
    params: [
      ignore_deps:
        "All references to modules matching this regex (or list of regexes) will be ignored."
    ]
  ]
  @default_params [
    ignore_deps: [],
    ignore_callers: [~r/Test$/]
  ]

  use Credo.Check, base_priority: :high, category: :design, run_on_all: true

  alias Credo.Code
  alias Credo.Code.Module
  alias Credo.Execution.ExecutionIssues

  def run(source_files, exec, params \\ []) do
    issues =
      source_files
      |> extract_modules(params)
      |> get_modules_deps()
      |> mark_publicity()
      |> find_public_ancestors()
      |> find_issues(params)

    Enum.each(issues, &ExecutionIssues.append(exec, &1.source_file, &1.issue))
  end

  ## Generic data preparation

  defp extract_modules(source_files, params) do
    Enum.flat_map(source_files, fn source_file ->
      issue_meta = IssueMeta.for(source_file, params)
      modules = Code.prewalk(source_file, &traverse_modules(&1, &2), [])

      Enum.map(modules, &Map.merge(&1, %{issue_meta: issue_meta, source_file: source_file}))
    end)
  end

  defp traverse_modules({:defmodule, meta, _arguments} = ast, modules) do
    {ast, [%{name: Module.name(ast), meta: meta, ast: ast} | modules]}
  end

  defp traverse_modules(ast, modules) do
    {ast, modules}
  end

  defp get_modules_deps(modules) do
    Enum.map(modules, fn %{ast: ast, name: name} = mod ->
      deps =
        ast
        |> get_module_deps_from_ast()
        |> resolve_current_module_forms(name)

      Map.put(mod, :deps, deps)
    end)
  end

  defp get_module_deps_from_ast(ast) do
    aliases = Module.aliases(ast)
    modules = Module.modules(ast)

    Enum.reduce(modules, aliases, fn m, acc ->
      if Enum.find(acc, fn alia -> String.ends_with?(alia, m) end) do
        acc
      else
        [m | acc]
      end
    end)
  end

  defp resolve_current_module_forms(modules, current_module) do
    Enum.map(modules, &String.replace(&1, ~r/^__MODULE__/, current_module))
  end

  ## Contextual data preparation

  defp mark_publicity(modules) do
    Enum.map(modules, fn %{name: name, ast: ast} = mod ->
      cond do
        root_module?(name) ->
          Map.put(mod, :public, true)

        not is_nil(doc = Module.attribute(ast, :moduledoc)) ->
          Map.put(mod, :public, !!doc)

        true ->
          mod
      end
    end)
  end

  defp find_public_ancestors(modules) do
    mod_map = Enum.map(modules, &{&1.name, &1}) |> Map.new()

    Enum.map(modules, fn mod ->
      ancestor = find_public_ancestor(mod, mod_map)
      Map.put(mod, :public_ancestor, (ancestor && ancestor.name) || get_root_module(mod.name))
    end)
  end

  defp find_public_ancestor(%{public: true} = mod, _mod_map) do
    mod
  end

  defp find_public_ancestor(%{name: name}, mod_map) do
    find_module_ancestor(name, mod_map, & &1.public)
  end

  defp find_module_ancestor(name, mod_map, func) do
    with {:p, parent_name} when not is_nil(parent_name) <- {:p, get_parent_module(name)},
         {:ok, parent_mod} <- Map.fetch(mod_map, parent_name),
         true <- func.(parent_mod) do
      parent_mod
    else
      {:p, nil} ->
        nil

      _ ->
        find_module_ancestor(get_parent_module(name), mod_map, func)
    end
  end

  ## Issue identification - high level

  defp find_issues(modules, params) do
    ignore_callers = Params.get(params, :ignore_callers, @default_params)
    ignore_deps = Params.get(params, :ignore_deps, @default_params)
    checkable_callers = filter_module_names(modules, ignore_callers)

    checkable_deps =
      modules
      |> filter_module_names(ignore_deps)
      |> filter_with_publicity()

    forbidden_deps = find_forbidden_deps(checkable_callers, checkable_deps)

    Enum.map(
      forbidden_deps,
      &%{
        source_file: &1.caller.source_file,
        issue:
          format_issue(
            &1.caller.issue_meta,
            message:
              "Forbidden reference to #{&1.dep.name} private to area #{&1.dep.public_ancestor}",
            trigger: &1.caller.name,
            line_no: &1.caller.meta[:line]
          )
      }
    )
  end

  defp filter_module_names(modules, ignore_deps) do
    Enum.filter(modules, fn %{name: name} ->
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

  defp find_forbidden_deps(modules, checkable_deps) do
    Enum.flat_map(modules, fn %{deps: deps} = mod ->
      deps
      |> Enum.map(&Enum.find(checkable_deps, fn %{name: name} -> &1 == name end))
      |> Enum.filter(& &1)
      |> Enum.filter(&(not allowed_dep?(&1, mod)))
      |> Enum.map(&%{caller: mod, dep: &1})
    end)
  end

  ## Issue identification - core logic

  defp allowed_dep?(dep, caller) do
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

  ## Module name helpers

  defp get_parent_module(name) do
    if root_module?(name) do
      nil
    else
      String.replace(name, ~r/\.\w+$/, "")
    end
  end

  defp get_root_module(name) do
    String.replace(name, ~r/(\.\w+)+$/, "")
  end

  defp root_module?(name) do
    name_parts =
      name
      |> String.split(".")
      |> length()

    name_parts == 1
  end
end
