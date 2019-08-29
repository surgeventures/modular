defmodule Foo.MyOtherArea.Impl do
  @behaviour Foo.MyOtherArea

  use Modular.AreaAccess, [
    Foo.MyArea
  ]

  @impl true
  def a do
    response_from_my_area = impl(Foo.MyArea).a()

    [:hello_from_my_other_area, response_from_my_area]
  end
end
