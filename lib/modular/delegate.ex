defmodule Modular.Delegate do
  @moduledoc """
  Defines thin contracts with convention-driven call delegation to internal implementations.

  ## Example

      iex> defmodule Invoicing.CreateUser do
      iex>   def call(name), do: {:ok, name}
      iex> end
      iex>
      iex> defmodule Invoicing do
      iex>   use Modular.Delegate
      iex>
      iex>   defcall create_user(name)
      iex> end
      iex>
      iex> Invoicing.create_user("Mike")
      {:ok, "Mike"}

  """

  defmodule Helpers do
    @moduledoc false

    def get_impl_mod(fun_name, contracted_impl_mod) do
      case contracted_impl_mod do
        callback when is_function(callback) ->
          callback.(fun_name)

        name when is_binary(name) ->
          name
      end
    end

    def get_target_func(fun_name, contracted_impl_func) do
      case contracted_impl_func do
        atom when is_atom(atom) ->
          atom

        callback when is_function(callback) ->
          case callback.(fun_name) do
            name_string when is_binary(name_string) ->
              String.to_atom(name_string)

            other ->
              other
          end
      end
    end
  end

  defmacro __using__(opts) do
    impl_mod = Keyword.get(opts, :impl_mod, &Macro.camelize/1)
    impl_func = Keyword.get(opts, :impl_func, :call)

    quote do
      import unquote(__MODULE__), only: :macros

      def __contracted_interface__, do: true

      @contracted_impl_mod unquote(impl_mod)
      @contracted_impl_func unquote(impl_func)
    end
  end

  defmacro defcall(fun) do
    fun = Macro.escape(fun, unquote: true)
    interface_mod = __CALLER__.module

    quote bind_quoted: [fun: fun, interface_mod: interface_mod] do
      alias Contracted.Interface.Helpers
      alias Kernel.Utils

      {fun_name_atom, _, _} = fun
      fun_name = to_string(fun_name_atom)

      impl_mod = Helpers.get_impl_mod(fun_name, @contracted_impl_mod)
      target_func = Helpers.get_target_func(fun_name, @contracted_impl_func)
      target = :"#{interface_mod}.#{impl_mod}"
      {name, args, as, as_args} = Utils.defdelegate(fun, to: target, as: target_func)

      @doc delegate_to: {target, as, :erlang.length(as_args)}
      def unquote(name)(unquote_splicing(args)) do
        unquote(target).unquote(as)(unquote_splicing(as_args))
      end
    end
  end
end
