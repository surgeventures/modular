defmodule Modular.Mutability do
  @moduledoc """
  Provides command/query annotations for functions within area contracts.

  ## Examples

      defmodule Invoicing do
        use Modular.Mutability

        @command true
        def create_user, do: :error

        @query true
        def get_users, do: []
      end

  """

  defmacro __using__(_) do
    quote do
      require unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      Module.register_attribute(__MODULE__, :queries, accumulate: true)

      @before_compile unquote(__MODULE__)
      @on_definition unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def __mutability__(:commands), do: @commands
      def __mutability__(:queries), do: @queries
    end
  end

  def __on_definition__(env, kind, name, _args, _guards, _body) do
    command = Module.delete_attribute(env.module, :command)
    query = Module.delete_attribute(env.module, :query)

    validate_kind(env, command, query, kind)
    validate_mutex(env, command, query)
    validate_value(env, command, query)

    if command do
      Module.put_attribute(env.module, :commands, name)
    end

    if query do
      Module.put_attribute(env.module, :queries, name)
    end
  end

  defp validate_kind(env, command, query, kind) do
    if (command || query) && kind != :def do
      raise_compile_error(env, "@command/@query can only be set for public functions")
    end
  end

  defp validate_mutex(env, command, query) do
    if command != nil && query != nil do
      raise_compile_error(env, "@command/@query cannot be both set at the same time")
    end
  end

  defp validate_value(env, command, query) do
    if (command != nil && command != true) || (query != nil && query != true) do
      raise_compile_error(env, "@command/@query can only be set to true")
    end
  end

  defp raise_compile_error(env, description) when is_binary(description) do
    raise(
      CompileError,
      description: description,
      file: env.file,
      line: env.line
    )
  end
end
