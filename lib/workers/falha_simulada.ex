defmodule Pedido.FalhaSimulada do
  @moduledoc "Excecao lancada pelo worker para simular uma falha inesperada (`falhas_simuladas`)."

  defexception [:pedido_id, :tentativa, :falhas_simuladas]

  @impl true
  def message(%{pedido_id: id, tentativa: tentativa, falhas_simuladas: total}) do
    "falha simulada no pedido ##{id} (falha #{tentativa + 1} de #{total} previstas)"
  end
end
