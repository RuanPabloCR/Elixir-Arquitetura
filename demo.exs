# Uso: mix run demo.exs
entradas = [
  %{
    tipo: :fisico,
    id: 1,
    cliente: "Ana",
    itens: [%{produto: "Teclado", quantidade: 1, preco: 150.0}],
    frete: 20.0
  },
  %{
    tipo: :digital,
    id: 2,
    cliente: "Bruno",
    itens: [%{produto: "E-book", quantidade: 2, preco: 39.9}]
  },
  %{tipo: :fisico, id: 3, cliente: "Carla", itens: [], frete: 10.0},
  %{tipo: :digital, id: -4, cliente: "Davi", itens: [%{produto: "Curso", quantidade: 1, preco: 99}]},
  %{
    tipo: :fisico,
    id: 5,
    cliente: "Eva",
    itens: [%{produto: "Mouse", quantidade: 0, preco: 80.0}],
    frete: 15.0
  },
  %{tipo: :fisico, id: 6, cliente: "", itens: [%{produto: "Cabo", quantidade: 1, preco: 10}], frete: 5},
  %{tipo: :misterioso, id: 7},
  "isto nao e um pedido"
]

%{validos: validos, invalidos: invalidos} = Pedido.Pipeline.processar(entradas)

IO.puts("== Validos (#{length(validos)}) ==")

for %{pedido: pedido, total: total} <- validos do
  IO.puts("  ##{pedido.id} #{inspect(pedido.__struct__)} - #{pedido.cliente}: R$ #{total}")
end

IO.puts("\n== Invalidos (#{length(invalidos)}) ==")

for %{entrada: entrada, motivo: motivo} <- invalidos do
  id = if is_map(entrada), do: Map.get(entrada, :id, "?"), else: "?"
  IO.puts("  ##{id}: #{motivo}")
end

:ok = Pedido.Dispatcher.processar(validos, 2)
