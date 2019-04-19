defmodule Modular.ModDesc do
  @moduledoc false

  defstruct [:source_file, :line, :ast, :name, :deps, :public, :public_ancestor]

  alias Credo.Code
  alias Credo.Code.Module

  def from_source(source_files) do
    Enum.flat_map(source_files, fn source_file ->
      modules = Code.prewalk(source_file, &traverse(&1, &2), [])
      Enum.map(modules, &Map.put(&1, :source_file, source_file))
    end)
  end

  defp traverse({:defmodule, meta, _arguments} = ast, modules) do
    mod = %__MODULE__{
      name: Module.name(ast),
      line: Keyword.fetch!(meta, :line),
      ast: ast
    }

    {ast, [mod | modules]}
  end

  defp traverse(ast, modules) do
    {ast, modules}
  end

  def put_deps(modules) when is_list(modules) do
    Enum.map(modules, &put_deps/1)
  end

  def put_deps(%__MODULE__{} = mod) do
    Map.put(mod, :deps, get_deps(mod))
  end

  def get_deps(%__MODULE__{name: name, ast: ast}) do
    ast
    |> get_deps_from_ast()
    |> resolve_current_module_forms(name)
  end

  defp get_deps_from_ast(ast) do
    aliases = Module.aliases(ast)
    modules = Module.modules(ast)

    Enum.reduce(modules, aliases, fn mod, aliases ->
      if Enum.find(aliases, &String.ends_with?(&1, mod)) do
        aliases
      else
        [mod | aliases]
      end
    end)
  end

  defp resolve_current_module_forms(modules, current_module) do
    Enum.map(modules, &String.replace(&1, ~r/^__MODULE__/, current_module))
  end

  def put_public(modules) when is_list(modules) do
    Enum.map(modules, &put_public/1)
  end

  def put_public(%__MODULE__{name: name, ast: ast} = mod) do
    cond do
      root_name?(name) ->
        Map.put(mod, :public, true)

      not is_nil(doc = Module.attribute(ast, :moduledoc)) ->
        Map.put(mod, :public, !!doc)

      true ->
        mod
    end
  end

  def put_public_ancestor(modules) do
    mod_map = Enum.map(modules, &{&1.name, &1}) |> Map.new()

    Enum.map(modules, fn mod ->
      Map.put(mod, :public_ancestor, get_public_ancestor(mod, mod_map))
    end)
  end

  defp get_public_ancestor(%__MODULE__{name: name}, mod_map) do
    Enum.find(get_ancestor_names(name), fn ancestor_name ->
      cond do
        root_name?(ancestor_name) ->
          true

        ancestor_mod = Map.get(mod_map, ancestor_name) ->
          ancestor_mod.public

        true ->
          false
      end
    end)
  end

  defp get_ancestor_names(name) do
    name
    |> String.split(".")
    |> Enum.reduce([], fn
      part, [] -> [part]
      part, [last_name | _] = results -> [last_name <> "." <> part | results]
    end)
  end

  def get_parent_name(name) do
    if root_name?(name) do
      nil
    else
      String.replace(name, ~r/\.\w+$/, "")
    end
  end

  defp root_name?(name) do
    !String.contains?(name, ".")
  end

  def reject_names(modules, ignore_deps) do
    Enum.filter(modules, fn %__MODULE__{name: name} ->
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
end
