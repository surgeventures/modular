defmodule Modular.MixProject do
  use Mix.Project

  @version "0.3.1"
  @desc "Apply modular programming principles and patterns to build better Elixir apps"

  def project do
    [
      app: :modular,
      version: @version,
      elixir: "~> 1.7",
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      description: @desc,
      package: package(),

      # Docs
      name: "Modular",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_check, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.20", only: :dev},
      {:mox, ">= 0.0.0", optional: true}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/surgeventures/modular",
        "Fresha" => "https://www.fresha.com"
      },
      files: ~w(.formatter.exs mix.exs LICENSE.md README.md CHANGELOG.md lib)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/modular",
      source_url: "https://github.com/surgeventures/modular",
      extras: extras()
    ]
  end

  defp extras do
    [
      "README.md",
      "CHANGELOG.md"
    ]
  end
end
