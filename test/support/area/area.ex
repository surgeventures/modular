defmodule Modular.Test.Area do
  @moduledoc false

  @callback greet(String.t()) :: String.t()
  @callback incr(integer()) :: integer()
end
