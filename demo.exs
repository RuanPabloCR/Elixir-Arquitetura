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

# Lote maior para os workers terem o que fazer: repete os validos com ids novos.
lote =
  for rodada <- 0..4, item <- validos do
    %{item | pedido: %{item.pedido | id: item.pedido.id + rodada * 100}}
  end

IO.puts("\n== Despachando #{length(lote)} pedidos (workers: #{inspect(Pedido.WorkerSupervisor.ids())}) ==")
Pedido.Dispatcher.submeter(lote)

# Simula uma falha: derruba o worker 1 enquanto ele processa um pedido.
Process.sleep(300)
IO.puts("\n>>> Derrubando o worker 1 com Process.exit(pid, :kill)\n")
Pedido.Worker.derrubar(1)

{:ok, resumo} = Pedido.Dispatcher.aguardar()
IO.puts("\n== Resumo ==\n#{inspect(resumo)}")
