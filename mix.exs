defmodule Pedidos.MixProject do
  use Mix.Project

  def project do
    [
      app: :pedidos,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Pedidos.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Somente para o painel web (lib/web). O nucleo nao depende delas.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.2"},
      {:phoenix_html, "~> 4.2"},
      {:bandit, "~> 1.14"},
      {:jason, "~> 1.4"}
    ]
  end
end
