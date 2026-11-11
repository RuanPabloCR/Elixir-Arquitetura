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
  # Falha na 1a tentativa e conclui ao ser reprocessado.
  %{
    tipo: :digital,
    id: 8,
    cliente: "Fabio",
    itens: [%{produto: "Plugin", quantidade: 1, preco: 49.9}],
    falhas_simuladas: 1
  },
  # Sempre falha: esgota as 3 tentativas e vai para a lista de falhas.
  %{
    tipo: :fisico,
    id: 9,
    cliente: "Gabi",
    itens: [%{produto: "Monitor", quantidade: 1, preco: 900.0}],
    frete: 30.0,
    falhas_simuladas: 3
  },
  %{tipo: :misterioso, id: 7},
  "isto nao e um pedido"
]

%{validos: validos, invalidos: invalidos} = Pedido.Pipeline.processar(entradas)

rodadas = 3

IO.puts("""
== Fluxo da demonstracao ==
Somente os #{length(validos)} pedidos validos entram no despacho.
Como sao feitas #{rodadas} rodadas, o lote tera #{length(validos) * rodadas} pedidos.
Os #{length(invalidos)} pedidos invalidos sao contabilizados, mas nao sao enviados aos workers.
""")
:ok = Pedido.Terminal.habilitar_saida()

IO.puts("== Validos (#{length(validos)}) ==")

for %{pedido: pedido, total: total} <- validos do
  IO.puts("  ##{pedido.id} #{inspect(pedido.__struct__)} - #{pedido.cliente}: R$ #{total}")
end

:ok = Pedido.Resultados.registrar_invalidos(invalidos)
IO.puts("\n== Invalidos (#{length(invalidos)}) ==")

# Lote maior para os workers terem o que fazer: a 1a rodada mantem as falhas
# simuladas; as copias seguintes (ids novos) nao falham.
lote =
  for rodada <- 0..(rodadas - 1), item <- validos do
    pedido =
      if rodada == 0,
        do: item.pedido,
        else: %{item.pedido | id: item.pedido.id + rodada * 100, falhas_simuladas: 0}

    %{item | pedido: pedido}
  end

IO.puts("\n== Despachando #{length(lote)} pedidos (workers: #{inspect(Pedido.WorkerSupervisor.ids())}) ==")
Pedido.Dispatcher.submeter(lote)

# Simula uma falha: derruba o worker 1 enquanto ele processa um pedido.
Process.sleep(300)
IO.puts("\n>>> Derrubando o worker 1 com Process.exit(pid, :kill)\n")
Pedido.Worker.derrubar(1)

{:ok, resumo} = Pedido.Dispatcher.aguardar()
IO.puts("\n== Resumo ==\n#{inspect(resumo)}")
