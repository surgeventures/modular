defmodule Foo.MyOtherAreaTest do
  use Foo.TestCase

  test "a/0 (normal)" do
    assert impl(Foo.MyOtherArea).a() == [
      :hello_from_my_other_area,
      :hello_from_my_area
    ]
  end

  test "a/0 (mocked)" do
    Mox.expect(impl(Foo.MyArea), :a, fn -> :my_area_mocked end)

    assert impl(Foo.MyOtherArea).a() == [
      :hello_from_my_other_area,
      :my_area_mocked
    ]
  end
end
