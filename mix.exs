defmodule Cairn.MixProject do
  use Mix.Project

  def project do
    [
      app: :cairn,
      version: "0.1.6",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/cristianodabc/cairn",
      homepage_url: "https://github.com/cristianodabc/cairn",
      docs: docs(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Small OTP helpers for message delivery and supervised task callbacks."
  end

  defp package do
    [
      files: ~w(lib notebooks .formatter.exs mix.exs README.md CHANGELOG.md LICENSE),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/cristianodabc/cairn"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "notebooks/cairn_features.livemd"]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp aliases do
    [
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "xref graph --format cycles --label compile-connected --fail-above 0",
        "deps.unlock --check-unused",
        "credo --strict",
        "deps.audit",
        "dialyzer",
        "cmd env MIX_ENV=test mix test",
        "docs"
      ],
      precommit: ["quality"]
    ]
  end
end
