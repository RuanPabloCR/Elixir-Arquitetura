defmodule Pedidos.MixProject do
  use Mix.Project

  def project do
    [
      app: :pedidos,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: []
    ]
  end

  def application do
    [
      mod: {Pedidos.Application, []},
      extra_applications: [:logger]
    ]
  end
end
