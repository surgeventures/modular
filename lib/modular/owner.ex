defmodule Modular.Owner do
  @moduledoc """
  Provides ownership annotations for area contracts.

  ## Examples

      iex> defmodule Invoicing do
      iex>   use Modular.Owner
      iex>
      iex>   @owner "me@example.com"
      iex> end
      iex>
      iex> Invoicing.__owner__()
      "me@example.com"
  """

  defmacro __using__(_) do
    quote do
      require unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def __owner__, do: @owner
    end
  end
end
