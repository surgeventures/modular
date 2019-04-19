defmodule Modular.MixProject do
  use Mix.Project

  @version "0.1.0"
  @desc "Apply modular programming principles and patterns to build better Elixir apps"

  def project do
    [
      app: :modular,
      version: @version,
      elixir: "~> 1.7",
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: preferred_cli_env(),

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
      {:credo, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.20", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:junit_formatter, "~> 3.0", only: :test}
    ]
  end

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  end

  defp package do
    [
      maintainers: ["Karol Słuszniak"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/surgeventures/modular",
        "Shedul" => "https://www.shedul.com"
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
