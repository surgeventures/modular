defmodule Foo.MyAreaTest do
  use Foo.TestCase

  test "a/0" do
    assert Foo.MyArea.Impl.a() == :hello_from_my_area
  end
end
