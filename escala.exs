# Uso: mix run escala.exs [quantidades de workers]
# Exemplo: mix run escala.exs 1 10 100
#
# Processa o mesmo lote com quantidades diferentes de workers e compara o tempo,
# a quantidade de processos na BEAM e a memoria. Os eventos nao sao impressos.

quantidades =
  case System.argv() do
    [] -> [1, 10, 100]
    args -> Enum.map(args, &String.to_integer/1)
  end

total_pedidos = 100
tempo_por_pedido_ms = 50

Application.put_env(:pedidos, :tempo_processamento_ms, tempo_por_pedido_ms)

entradas =
  for id <- 1..total_pedidos do
    %{
      tipo: :digital,
      id: id,
      cliente: "Cliente #{id}",
      itens: [%{produto: "Licenca", quantidade: 1, preco: 10.0}]
    }
  end

%{validos: lote} = Pedido.Pipeline.processar(entradas)

IO.puts("""
== Escala: #{total_pedidos} pedidos, #{tempo_por_pedido_ms} ms cada ==
Tempo ideal com N workers: #{total_pedidos} * #{tempo_por_pedido_ms} ms / N
""")

IO.puts(
  String.pad_trailing("Workers", 10) <>
    String.pad_trailing("Tempo", 12) <>
    String.pad_trailing("Processos na BEAM", 20) <> "Memoria"
)

for quantidade <- quantidades do
  :ok = Pedido.WorkerSupervisor.definir_quantidade(quantidade)
  processos = :erlang.system_info(:process_count)
  memoria_mb = Float.round(:erlang.memory(:total) / 1_048_576, 1)

  Pedido.Dispatcher.submeter(lote)
  {:ok, resumo} = Pedido.Dispatcher.aguardar(:infinity)

  IO.puts(
    String.pad_trailing("#{quantidade}", 10) <>
      String.pad_trailing("#{resumo.metricas.tempo_execucao_ms} ms", 12) <>
      String.pad_trailing("#{processos}", 20) <> "#{memoria_mb} MB"
  )
end
