defmodule Modular.Mutability do
  @moduledoc """
  Provides command/query annotations for functions within area contracts.

  ## Examples

      iex> defmodule Invoicing do
      iex>   use Modular.Mutability
      iex>
      iex>   @command true
      iex>   def create_user, do: :error
      iex>
      iex>   @query true
      iex>   def get_users, do: []
      iex> end

  """

  defmacro __using__(_) do
    quote do
      require unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      Module.delete_attribute(__MODULE__, :query)
      Module.delete_attribute(__MODULE__, :command)
    end
  end
end
