defmodule Modular.Owner do
  @moduledoc """
  Provides ownership annotations for area contracts.

  ## Examples

      defmodule Invoicing do
        use Modular.Owner

        @owner "me@example.com"
      end

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
