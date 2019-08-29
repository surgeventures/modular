defmodule Foo.MyArea.Impl do
  @behaviour Foo.MyArea

  @impl true
  def a do
    :hello_from_my_area
  end
end
