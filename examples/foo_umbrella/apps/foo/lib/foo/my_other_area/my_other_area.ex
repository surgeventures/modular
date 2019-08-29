defmodule Foo.MyOtherArea do
  use Modular.{Owner, Mutability}

  @owner "foo"

  @query true
  @callback a() :: [atom()]
end
