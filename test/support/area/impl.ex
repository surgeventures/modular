defmodule Modular.Test.Area.Impl do
  @moduledoc false

  @behaviour Modular.Test.Area

  @impl true
  def greet(name), do: "Hello, #{name}"

  @impl true
  def incr(num), do: num + 1
end
