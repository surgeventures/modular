defmodule Bar.MyAnotherArea do
  use Modular.{Owner, Mutability}

  @owner "bar"

  @query true
  @callback a() :: [atom()]

  @query true
  @callback b() :: :ok

  @command true
  @callback c() :: :ok
end
