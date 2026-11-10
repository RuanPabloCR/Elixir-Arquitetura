defmodule PedidoDigital do
  @moduledoc "Pedido de produto digital: nao tem frete."

  @enforce_keys [:id, :cliente, :itens]
  defstruct [:id, :cliente, :itens, falhas_simuladas: 0]

  @type t :: %__MODULE__{
          id: pos_integer(),
          cliente: String.t(),
          itens: [Pedido.item()],
          falhas_simuladas: non_neg_integer()
        }
end

defimpl Pedido.Total, for: PedidoDigital do
  def calcular(%PedidoDigital{itens: itens}), do: Pedido.subtotal(itens)
end
