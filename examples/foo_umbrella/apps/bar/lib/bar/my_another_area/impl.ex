defmodule Bar.MyAnotherArea.Impl do
  @behaviour Bar.MyAnotherArea

  use Modular.AreaAccess, [
    Foo.MyOtherArea
  ]

  @impl true
  def a do
    response_from_my_other_area = impl(Foo.MyOtherArea).a()

    [:hello_from_my_another_area | response_from_my_other_area]
  end

  @impl true
  def b do
    :ok
  end

  @impl true
  def c do
    :ok
  end
end
