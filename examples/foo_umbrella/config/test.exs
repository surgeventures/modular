import Config

config :modular,
  area_mocking_enabled: true,
  areas: [
    Foo.MyArea,
    Foo.MyOtherArea,
    Bar.MyAnotherArea
  ]
