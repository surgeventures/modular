defmodule Modular.AreaAccess do
  @moduledoc """
  Allows to declare external deps and optionally resolve them to mocks.

  ## Usage

  Define area behaviours and implementations:

      defmodule MyApp.First do
        @callback some() :: :ok
      end

      defmodule MyApp.Second do
        @callback other() :: :ok
      end

      defmodule MyApp.First.Impl do
        @behaviour MyApp.First

        def some do
          :ok
        end
      end

      defmodule MyApp.Second.Impl do
        @behaviour MyApp.Second

        def other do
          :ok
        end
      end

  Declare dependencies and call other areas:

      defmodule MyApp.First.Impl do
        @behaviour MyApp.First

        use Modular.AreaAccess, [
          MyApp.Second
        ]

        def some do
          impl(MyApp.Second).other()
        end
      end

  ## Mocking

  Enable mocking and configure areas that are viable for it in `config/test.exs`:

      config :modular,
        area_mocking_enabled: true,
        areas: [
          MyApp.First,
          MyApp.Second
        ]

  Setup mocks for `Mox` in`test/suport/mocks.ex` (follow `Mox` docs on including the `test/support`
  directory in compile paths):

      Modular.AreaAccess.define_mocks()

  Then allow usage of any areas from test cases and stub them back to real implementations:

      defmodule MyCase do
        use ExUnit.CaseTemplate

        using do
          quote do
            use Modular.AreaAccess, :all
          end
        end

        setup do
          Modular.AreaAccess.install_stubs()

          :ok
        end
      end

  Write tests as normal and mock with custom expectations when needed:

      defmodule MyTest do
        use MyCase

        test "normal case" do
          assert :ok = impl(MyApp.First).some()
        end

        test "mocked case" do
          Mox.expect(impl(MyApp.Second), :other, fn -> :mocked end)

          assert :mocked = impl(MyApp.First).some()
        end
      end

  ## Hammox integration

  Next to normal stubs you can introduce stubs that upon each call,
  direct or not, will be checked against it's type specification.

      config :modular,
        area_mocking_enabled: true,
        areas: [
          MyApp.First
        ]
        typed_areas: [
          MyApp.Second
        ]

  And then extend you test setup with explicite stub instalation

        defmodule MyCase do
        use ExUnit.CaseTemplate

        using do
          quote do
            use Modular.AreaAccess, :all
          end
        end

        setup do
          Modular.AreaAccess.install_stubs()
          Modular.AreaAccess.install_typed_stubs()

          :ok
        end
      end

  With this as soon as any call (again, direct or not) to
  `impl(Module.Second).other()` will return anything not conforming to
  `c Module.Second.other/0` callback type specification your test will
  fail with `Hammox.TypeMatchError`.

  If you don't want to install your typed-stub globally simply use
  `Modular.AreaAcces.typed_stub/1` for stubbing , or
  `Modular.AreaAccess.typed_stub/3` to stub only one function.
  """

  defmacro __using__(:all) do
    quote do
      import Modular.AreaAccess, only: [impl: 1]
    end
  end

  defmacro __using__(mod_asts) when is_list(mod_asts) do
    mods = Enum.map(mod_asts, &Macro.expand(&1, __CALLER__))

    quote do
      import Modular.AreaAccess, only: [impl: 1]

      Module.put_attribute(__MODULE__, :area_impl_def, unquote(mods))
      Module.register_attribute(__MODULE__, :area_impl_call, accumulate: true)
      @before_compile Modular.AreaAccess
    end
  end

  defmacro __before_compile__(env) do
    defined = Module.delete_attribute(env.module, :area_impl_def)

    called =
      env.module
      |> Module.delete_attribute(:area_impl_call)
      |> Enum.uniq()

    undefined = Enum.map(called -- defined, &inspect/1)
    if Enum.any?(undefined), do: raise("calling unlisted area #{Enum.join(undefined, ", ")}")

    uncalled = Enum.map(defined -- called, &inspect/1)
    if Enum.any?(uncalled), do: raise("unused area #{Enum.join(uncalled, ", ")}")
  end

  defmacro impl(mod_ast) do
    mod = Macro.expand(mod_ast, __CALLER__)

    if Module.get_attribute(__CALLER__.module, :area_impl_def) do
      Module.put_attribute(__CALLER__.module, :area_impl_call, mod)
    end

    if mocking_enabled?() do
      mock_impl(mod)
    else
      real_impl(mod)
    end
  end

  defp mocking_enabled? do
    Application.get_env(:modular, :area_mocking_enabled, false)
  end

  defp mock_impl(mod) do
    Module.concat(mod, "Mock")
  end

  defp real_impl(mod) do
    Module.concat(mod, "Impl")
  end

  ## Mocking

  def define_mocks do
    for mod <- areas(),
        not Code.ensure_loaded?(mock_impl(mod)),
        do: mox(:defmock, [mock_impl(mod), [for: mod]])
  end

  def install_stubs do
    for mod <- areas(), do: mox(:stub_with, [mock_impl(mod), real_impl(mod)])
  end

  def install_typed_stubs do
    for mod <- type_checked_areas(), do: typed_stub(mod)
  end

  def typed_stub(module) do
    module.behaviour_info(:callbacks)
    |> Enum.each(fn {function_name, arity} ->
      typed_stub(module, function_name, arity)
    end)
  end

  def typed_stub(behaviour, callback_name, arity) do
    lambda = hammox(:protect, [{real_impl(behaviour), callback_name, arity}, behaviour])
    hammox(:stub, [mock_impl(behaviour), callback_name, lambda])
  end

  # We don't want Mox and Hammox to be a compile-time dependency for
  # this code because modular will be compiled and used in non-test
  # envs in which Mox is not present.

  defp hammox(function_name, args) do
    apply(Hammox, function_name, args)
  end

  defp mox(function_name, args) do
    apply(Mox, function_name, args)
  end

  defp areas do
    :modular
    |> Application.fetch_env!(:areas)
    |> Enum.filter(&ensure_compiled?/1)
  end

  defp type_checked_areas do
    :modular
    |> Application.fetch_env!(:typed_areas)
    |> Enum.filter(&ensure_compiled?/1)
  end

  defp ensure_compiled?(module) do
    case Code.ensure_compiled(module) do
      {:module, _compiled} -> true
      _ -> false
    end
  end
end
