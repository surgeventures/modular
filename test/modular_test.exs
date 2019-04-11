defmodule ModularTest do
  use ExUnit.Case
  doctest Modular

  test "greets the world" do
    assert Modular.hello() == :world
  end
end
