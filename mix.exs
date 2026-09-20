defmodule Cairn.MixProject do
  use Mix.Project

  def project do
    [
      app: :cairn,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/cristianodabc/cairn",
      homepage_url: "https://github.com/cristianodabc/cairn",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end

  defp description do
    "Small OTP helpers for message delivery and supervised task callbacks."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/cristianodabc/cairn"}
    ]
  end
end
