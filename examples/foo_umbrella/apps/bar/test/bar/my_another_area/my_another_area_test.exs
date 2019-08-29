defmodule Bar.MyAnotherAreaTest do
  use Bar.TestCase

  test "a/0 (integration)" do
    assert impl(Bar.MyAnotherArea).a() == [
      :hello_from_my_another_area,
      :hello_from_my_other_area,
      :hello_from_my_area
    ]
  end

  test "a/0 (semi-mocked)" do
    Mox.expect(impl(Foo.MyArea), :a, fn -> :my_area_mocked end)

    assert impl(Bar.MyAnotherArea).a() == [
      :hello_from_my_another_area,
      :hello_from_my_other_area,
      :my_area_mocked
    ]
  end

  test "a/0 (mocked)" do
    Mox.expect(impl(Foo.MyOtherArea), :a, fn -> [:my_other_area_mocked, :my_area_mocked] end)

    assert impl(Bar.MyAnotherArea).a() == [
      :hello_from_my_another_area,
      :my_other_area_mocked,
      :my_area_mocked
    ]
  end
end
