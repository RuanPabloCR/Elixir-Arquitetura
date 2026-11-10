defmodule PedidoFisico do
  @moduledoc "Pedido de produto fisico: o total inclui o frete."

  @enforce_keys [:id, :cliente, :itens]
  defstruct [:id, :cliente, :itens, frete: 0.0, falhas_simuladas: 0]

  @type t :: %__MODULE__{
          id: pos_integer(),
          cliente: String.t(),
          itens: [Pedido.item()],
          frete: number(),
          falhas_simuladas: non_neg_integer()
        }
end

defimpl Pedido.Total, for: PedidoFisico do
  def calcular(%PedidoFisico{itens: itens, frete: frete}), do: Pedido.subtotal(itens) + frete
end
