defmodule Modular.ModDesc do
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
      ancestor = get_public_ancestor(mod, mod_map)
      Map.put(mod, :public_ancestor, (ancestor && ancestor.name) || get_root_name(mod.name))
    end)
  end

  defp get_public_ancestor(%__MODULE__{public: true} = mod, _mod_map) do
    mod
  end

  defp get_public_ancestor(%__MODULE__{name: name}, mod_map) do
    find_ancestor(name, mod_map, & &1.public)
  end

  defp find_ancestor(name, mod_map, func) do
    with {:p, parent_name} when not is_nil(parent_name) <- {:p, get_parent_name(name)},
         {:ok, parent_mod} <- Map.fetch(mod_map, parent_name),
         true <- func.(parent_mod) do
      parent_mod
    else
      {:p, nil} ->
        nil

      _ ->
        find_ancestor(get_parent_name(name), mod_map, func)
    end
  end

  def get_parent_name(name) do
    if root_name?(name) do
      nil
    else
      String.replace(name, ~r/\.\w+$/, "")
    end
  end

  defp get_root_name(name) do
    String.replace(name, ~r/(\.\w+)+$/, "")
  end

  defp root_name?(name) do
    !String.contains?(name, ".")
  end
end
