defmodule Modular.AreaAccessTest do
  use ExUnit.Case
  doctest Modular.AreaAccess

  describe "define_mocks/0" do
    test "defines mock modules for behaviours" do
      Modular.AreaAccess.define_mocks()
      assert Code.ensure_loaded?(Modular.Test.Area.Mock)
    end

    test "is idempotent" do
      Modular.AreaAccess.define_mocks()
      Modular.AreaAccess.define_mocks()
    end
  end

  describe "install_stubs/0" do
    test "stubs all functions with real implementations" do
      Modular.AreaAccess.define_mocks()
      Modular.AreaAccess.install_stubs()
      assert Code.ensure_loaded?(Modular.Test.Area.Mock)
      assert Modular.Test.Area.Mock.greet("Bob") == "Hello, Bob"
      assert Modular.Test.Area.Mock.incr(5) == 6
    end
  end
end
