defmodule ExLokaliseTransfer.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/bodrovis/ex_lokalise_transfer"
  @description "Wrapper around Lokalise API download and upload endpoints for Elixir projects."

  def project do
    [
      app: :ex_lokalise_transfer,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @description,
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],

      # Dialyxir
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:mint]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_lokalise_api, "~> 4.1.1"},
      {:finch, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.1", only: :test},
      {:ex_doc, "~> 0.37", only: :dev},
      {:mox, "~> 1.2", only: :test},
      {:quokka, "~> 2.12", only: [:dev, :test], runtime: false}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def docs do
    [
      extras: [
        "README.md": [title: "Readme"],
        "CHANGELOG.md": [title: "Changelog"],
        "LICENSE.md": [title: "License"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      homepage_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp package do
    [
      description: @description,
      maintainers: ["Elijah S. Krukowski"],
      licenses: ["BSD-3-Clause"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end
end
