# Elixir — Sistema Resiliente de Processamento de Pedidos

> Projeto acadêmico desenvolvido para a disciplina de **Arquiteturas de Linguagens de Programação**, no CEFET/RJ.

## Sobre o projeto

Este projeto explora os principais recursos da linguagem **Elixir**, relacionando seus conceitos fundamentais às características que a tornam interessante para o desenvolvimento de sistemas concorrentes e resilientes.

A proposta é desenvolver um sistema de processamento de pedidos capaz de receber dados, validá-los, transformá-los e distribuí-los entre processos concorrentes.

Além de demonstrar o funcionamento da linguagem, o projeto busca evidenciar como Elixir e seu ecossistema, baseado na máquina virtual BEAM e no OTP, abordam problemas de concorrência, isolamento de falhas e recuperação de processos.

**Status:** O sistema cobre representação, validação, workers concorrentes, supervisão, reprocessamento, métricas e um painel web em Phoenix LiveView para a demonstração.

## Como executar

```bash
mix deps.get
mix phx.server        # painel em http://localhost:4000
mix run demo.exs      # fluxo completo no terminal
mix run escala.exs    # comparação de tempo com 1, 10 e 100 workers
```

## Objetivos

- Explorar o paradigma funcional e a imutabilidade.
- Demonstrar pattern matching e composição de funções.
- Apresentar o sistema de tipos e o polimorfismo em Elixir.
- Compreender o modelo de processos da BEAM.
- Implementar processamento concorrente por troca de mensagens.
- Utilizar os recursos do OTP para supervisão e recuperação de falhas.
- Relacionar os recursos da linguagem aos conceitos estudados na disciplina.

## Escopo da etapa atual

O sistema valida pedidos, distribui os válidos entre workers supervisionados e registra resultados e eventos. Um painel web consome esses eventos para mostrar a execução e permite controlar a demonstração.

### O que será entregue

1. **Representação:** uma `struct` para cada tipo de pedido, com `@type` associado.
2. **Polimorfismo:** um `Protocol` que calcula o total do pedido conforme o seu tipo.
3. **Validação:** funções que verificam um pedido e retornam `{:ok, pedido}` ou `{:error, motivo}`.
4. **Pipeline funcional:** recebe uma coleção de pedidos e a separa em válidos e inválidos.
5. **Concorrência e recuperação:** workers supervisionados processam os pedidos; falhas podem causar reprocessamento até o limite configurado.
6. **Resultados e eventos:** um processo mantém métricas, estado dos workers e eventos recentes, compartilhados com consumidores como o terminal e o painel web.
7. **Painel web:** Phoenix LiveView mostrando workers, métricas e eventos ao vivo, com controles para enviar pedidos, mudar a quantidade de workers e simular falhas.

### Fora do escopo

- Testes automatizados: por se tratar de um projeto de apresentação, o escopo foi reduzido e a verificação é feita executando o programa de demonstração.

### Representação dos pedidos

Cada tipo de pedido é uma `struct` com `@type` associado. Exemplo de pedido físico:

```elixir
%PedidoFisico{
  id: 1,
  cliente: "Ana",
  itens: [%{produto: "Teclado", quantidade: 1, preco: 150.0}],
  frete: 20.0,
  falhas_simuladas: 0
}
```

Os dois tipos previstos são `PedidoFisico` (com frete) e `PedidoDigital` (sem frete). O total de cada um é calculado pelo protocolo, e não por um `case` sobre o tipo:

```elixir
defprotocol Pedido.Total do
  @spec calcular(t()) :: float()
  def calcular(pedido)
end
```

O campo `falhas_simuladas` define quantas falhas o worker deve produzir antes de concluir o pedido. O limite de reprocessamentos é três; se o pedido continuar falhando, ele é registrado na lista de falhas.

| Valor | Comportamento |
|---|---|
| `0` | Pedido processado normalmente |
| `1` | Falha na primeira tentativa e é concluído ao ser reprocessado |
| Maior ou igual ao limite de tentativas | Pedido encaminhado à lista de falhas |

### Regras de validação

Um pedido é considerado inválido quando:

- `id` não é um inteiro positivo.
- `cliente` está ausente ou vazio.
- `itens` é uma lista vazia.
- algum item tem `quantidade` não positiva ou `preco` negativo.
- `frete` é negativo (pedido físico).
- `falhas_simuladas` não é um inteiro maior ou igual a zero.

A validação segue a convenção do Elixir para erros esperados: retorna `{:error, motivo}` e **não** lança exceção. Isso mantém a distinção entre pedido inválido (dado ruim, tratado no pipeline) e falha inesperada (crash, detectado pelo Dispatcher e recuperado pelo supervisor).

### Conceitos explorados nesta etapa

- Structs e typespecs (`@type` e `@spec`).
- Pattern matching e guards.
- Polimorfismo com `Protocol`.
- Imutabilidade e composição de funções com o pipe operator (`|>`).
- Funções de ordem superior (`Enum.map`, `Enum.reduce`, `Enum.split_with`).
- Retorno `{:ok, _}` / `{:error, _}` com `with`.
- Processos OTP com `GenServer`, `DynamicSupervisor` e `Registry`.
- Eventos assíncronos e métricas mantidas por um processo dedicado.

## Funcionalidades planejadas

### 1. Processamento funcional de dados *(etapa atual)*

Recebimento de uma coleção de pedidos, seguida por etapas de validação, filtragem e transformação.

### 2. Tipos e polimorfismo *(etapa atual)*

Representação dos pedidos com structs e cálculo do total conforme o tipo, usando `Protocol`.

### 3. Processamento concorrente *(etapa atual)*

Distribuição dos pedidos entre múltiplos workers, permitindo que diferentes tarefas sejam executadas simultaneamente.

Conceitos explorados: processos leves da BEAM, passagem de mensagens, concorrência e paralelismo, isolamento entre processos.

### 4. Supervisão e tolerância a falhas *(etapa atual)*

Monitoramento dos workers, recuperação automática dos processos que falharem e reprocessamento dos pedidos interrompidos.

Conceitos explorados: OTP, `GenServer` e `Supervisor`, árvore de supervisão, estratégias de reinicialização, `Process.monitor`, filosofia *Let It Crash*.

### 5. Resultados, métricas e eventos *(etapa atual)*

`Pedido.Resultados` mantém contadores, estado dos workers e os 2.000 eventos mais recentes. Consumidores assinam eventos ou consultam um snapshot; o terminal já apresenta os mesmos eventos que poderão alimentar a interface.

### 6. Visualização da execução *(etapa atual)*

Painel em Phoenix LiveView para acompanhar o sistema em funcionamento: workers ativos, pedidos em andamento, e controles para ajustar a quantidade de workers e simular falhas. Veja [Painel web](#painel-web-phoenix-liveview).

## Arquitetura proposta

A arquitetura é conceitual e poderá ser modificada durante a implementação. A implementação atual inclui validação, despacho, supervisão, recuperação e resultados.

### Fluxo dos pedidos

```text
Entrada de pedidos
        |
        v
Pipeline de validação e transformação   <-- etapa atual
        |                    |
     válidos             inválidos
        |                    |
        v                    v
    Dispatcher           Resultados
        |
   +----+----+
   |    |    |
   v    v    v
  W1   W2  ...  WN
   |    |    |
   +----+----+
        |
        v
    Resultados
```

### Árvore de supervisão

O Supervisor não participa do fluxo de dados: ele inicia, observa e reinicia processos.

```text
Application
└── Supervisor raiz (:one_for_one)
    ├── Pedidos.Nucleo (:rest_for_one)
    │   ├── Registry            (nome -> PID atual de cada worker)
    │   ├── Resultados          (métricas e eventos)
    │   ├── Dispatcher
    │   ├── DynamicSupervisor dos workers (:one_for_one)
    │   │   ├── Worker 1
    │   │   ├── ...
    │   │   └── Worker N        (5 por padrão; ajustável em tempo de execução)
    │   ├── Terminal            (imprime os eventos)
    │   └── workers_iniciais    (inicia os N workers na subida e não fica vivo)
    ├── PubSub                  (Phoenix)
    └── Endpoint                (painel web)
```

- Se um worker falhar, somente ele será reiniciado.
- Se o Dispatcher falhar, ele, os workers e o Terminal serão reiniciados, preservando os Resultados. Os workers iniciais são recriados e se anunciam ao novo Dispatcher; workers adicionados depois não voltam.
- O painel web fica em um ramo separado do núcleo: derrubar o Dispatcher na demonstração não desconecta o painel.
- Os processos mais simples e estáveis ficam no início da árvore.
- Os workers ficam sob um `DynamicSupervisor`, e não sob um `Supervisor` com filhos fixos: a quantidade `N` é definida em tempo de execução (`Pedido.WorkerSupervisor.definir_quantidade/1`) e pode ser alterada durante a demonstração.

### Escala dos workers

Na BEAM, um worker é um **processo leve**, e não uma thread do sistema operacional. A demonstração usa uma **escala moderada**, para que a interface continue legível: 5 workers no fluxo normal e até cerca de 100 no script de escala. Os números abaixo servem de argumento de que a quantidade poderia ser muito maior.

Medição de referência feita na máquina de desenvolvimento, com processos ociosos (Elixir 1.20 / OTP 29):

| Processos | Tempo para criar | Memória total |
|---|---|---|
| 10 mil | 31 ms | 26 MB |
| 100 mil | 545 ms | 262 MB |
| 1 milhão | 5,8 s | 2,6 GB |

Cada processo custa cerca de 2,7 KB. Uma thread do sistema operacional costuma reservar cerca de 1 MB de pilha, então 100 mil threads exigiriam algo na ordem de 100 GB só de pilha.

**Script de escala (`mix run escala.exs`):** processa o mesmo lote de 100 pedidos, com 50 ms cada, usando 1, 10 e 100 workers. As quantidades podem ser passadas como argumento (`mix run escala.exs 1 10 50`). Resultado na máquina de desenvolvimento:

| Workers | Tempo | Processos na BEAM | Memória |
|---|---|---|---|
| 1 | 6.199 ms | 182 | 51,7 MB |
| 10 | 616 ms | 191 | 51,6 MB |
| 100 | 59 ms | 281 | 52,4 MB |

Os cerca de 180 processos da primeira linha já existem antes dos workers: são da própria BEAM, do Phoenix e do núcleo.

O tempo cai na proporção do número de workers, enquanto a memória quase não muda. Com 1 worker, o tempo fica acima dos 5.000 ms ideais porque, no Windows, o `Process.sleep` tem granularidade de cerca de 15 ms. O trabalho simulado é uma espera (`Process.sleep`), então o script demonstra concorrência, e não paralelismo de CPU.

**Pontos de atenção:**

- O Dispatcher entrega pedidos aos workers ociosos por uma fila; assim, não percorre a lista de workers a cada pedido.
- O `DynamicSupervisor` está configurado com até 100 reinícios em 5 segundos para permitir a demonstração de falhas em sequência.
- O limite de processos da BEAM é configurável (`+P`) e hoje está em cerca de 1 milhão.
- O Terminal só imprime eventos depois de `Pedido.Terminal.habilitar_saida/0`; até lá guarda no máximo 500. O script de escala não habilita a saída, para não imprimir cada evento.
- `Pedido.Resultados.publicar/2` é assíncrona, para não bloquear o Dispatcher a cada evento.
- `Pedido.Resultados` monitora os workers por conta própria: se o Dispatcher estiver fora do ar quando um worker sair, o estado mostrado no painel continua correto.

## Tratamento de erros

| Situação | Exemplo | Tratamento |
|---|---|---|
| Erro esperado | Valor negativo ou campo obrigatório ausente | Retorno `{:error, motivo}` no pipeline, sem crash |
| Falha inesperada | Exceção durante o processamento em um worker | Crash do worker e recuperação pelo OTP |

## Estratégia de recuperação

1. O Dispatcher registra quais pedidos estão em andamento em cada worker.
2. Cada worker se registra ao iniciar, pois seu PID muda após um reinício.
3. O Dispatcher usa `Process.monitor` para detectar a queda de um worker.
4. O pedido interrompido volta para a fila, com o número de tentativas incrementado.
5. Ao atingir o limite de 3 tentativas, o pedido vai para a lista de falhas.

O limite de tentativas impede que um pedido problemático derrube repetidamente os workers. O `max_restarts` do supervisor será configurado de acordo com as falhas simuladas na demonstração.

### Limitações conhecidas

A fila e os resultados ficam em memória. A supervisão restaura o serviço, mas não preserva os dados de um processo que falhou. Portanto, se o Dispatcher cair, sua fila será perdida. Em um sistema real, esses dados precisariam de armazenamento persistente.

## Métricas

As métricas são mantidas por `Pedido.Resultados` e incluídas no resumo ao final da execução. `processados` conta conclusões bem-sucedidas; `falhas` conta pedidos que esgotaram as tentativas:

- Pedidos processados.
- Pedidos inválidos.
- Pedidos reprocessados.
- Pedidos enviados à lista de falhas.
- Reinícios de workers (workers removidos de propósito não contam).
- Tempo de execução do último lote (`tempo_execucao_ms`), do primeiro pedido submetido até a fila esvaziar.

## Painel web (Phoenix LiveView)

`mix phx.server` sobe o painel em http://localhost:4000. Ele é somente uma camada de visualização: não tem regra de negócio, assina os eventos de `Pedido.Resultados` e chama as mesmas funções que se usaria no `iex`.

**O que mostra:** as métricas (processados, inválidos, reprocessados, falhas, reinícios, fila e tempo do último lote), um cartão por worker com seu estado, pedido atual, PID e quantidade de reinícios, a lista de falhas e os eventos recentes. Um worker que cai fica destacado em vermelho por 2 segundos, já com o novo PID.

**Controles:** enviar um lote de pedidos, um pedido que falha uma vez, um que sempre falha e pedidos inválidos; adicionar, remover ou definir a quantidade de workers (até 200); mudar o tempo de processamento por pedido; derrubar um worker específico ou o Dispatcher.

**Por que LiveView:** o painel continua 100% Elixir. O estado é mantido no servidor, e o navegador recebe só as diferenças pelo WebSocket. Não há Node nem esbuild: o JavaScript do Phoenix e do LiveView é servido direto dos pacotes, e o CSS e o JS do painel ficam em `priv/static`.

**Atualização:** a cada rajada de eventos, o painel relê o estado no máximo a cada 100 ms, para não redesenhar a tela a cada evento quando há muitos workers.

O `:observer.start()` continua disponível como reserva para mostrar a árvore de supervisão.

## Live Cases

**Live Case 01 — Transformação de dados**

Problema: como processar dados inconsistentes sem depender de alterações de estado?

Solução proposta: utilizar pattern matching, imutabilidade e composição de funções para construir um pipeline que separa pedidos válidos e inválidos.

**Live Case 02 — Sistema resiliente**

Problema: como manter o processamento funcionando, sem perder o pedido em andamento, quando um dos workers falha?

Solução proposta: utilizar processos isolados, supervisão do OTP e monitoramento pelo Dispatcher para recuperar o worker e reprocessar o pedido.

### Roteiro da demonstração

1. **Concorrência e escala:** rodar `mix run escala.exs`, que executa o mesmo lote com 1, 10 e 100 workers e mostra o tempo, a memória usada e a quantidade de processos (`:erlang.system_info(:process_count)`).
2. **Isolamento:** encerrar um worker (ou vários, escolhidos aleatoriamente) com `Process.exit(pid, :kill)` enquanto os outros continuam processando.
3. **Recuperação:** mostrar o novo PID do worker e o reprocessamento do pedido interrompido.
4. **Limite de tentativas:** enviar um pedido que sempre falha e mostrar sua chegada à lista de falhas.
5. **Visualização:** conduzir os passos 2 a 4 pelo painel (`mix phx.server`); o `:observer.start()` mostra a árvore de supervisão.

## Tecnologias

- **Elixir** — linguagem principal.
- **BEAM** — máquina virtual de execução.
- **OTP** — abstrações para concorrência, supervisão e construção de sistemas tolerantes a falhas.
- **Phoenix LiveView** e **Bandit** — painel web da demonstração.

## Estrutura planejada

A estrutura abaixo é uma previsão inicial e será ajustada conforme a implementação evoluir. Os itens marcados com *(atual)* fazem parte da etapa em andamento.

```text
.
├── lib/
│   ├── orders/          # Structs, protocolo, validação e pipeline
│   ├── workers/         # Workers, falhas simuladas e DynamicSupervisor
│   ├── dispatcher/      # Distribuição, monitoramento e reprocessamento
│   ├── results/         # Métricas, estado e eventos compartilhados
│   ├── web/             # Painel: Endpoint, Router, layout e LiveView
│   └── application.ex   # Inicialização da árvore de supervisão
├── priv/static/         # CSS e JS do painel
├── config/config.exs    # Configuração do Endpoint
├── demo.exs             # Fluxo completo: validação, falhas e recuperação
├── escala.exs           # Comparação de tempo com 1, 10 e 100 workers
├── mix.exs              # Configuração do projeto
└── README.md
```

> Para executar, veja [Como executar](#como-executar).

## Roadmap

### Etapa atual — processamento concorrente e resultados

- [x] Criar o projeto com `mix new` e migrar a estrutura inicial.
- [x] Definir as structs `PedidoFisico` e `PedidoDigital`, com `@type`.
- [x] Implementar o protocolo de cálculo do total.
- [x] Implementar a validação (`{:ok, pedido}` / `{:error, motivo}`).
- [x] Construir o pipeline que separa pedidos válidos e inválidos.
- [x] Criar um script de demonstração com pedidos válidos e inválidos.
- [x] Implementar workers concorrentes e supervisão dinâmica.
- [x] Integrar o Dispatcher, monitoramento e reprocessamento.
- [x] Manter métricas e eventos no processo de resultados.
- [x] Usar os eventos compartilhados como saída do terminal.
- [x] Manter a saída do terminal após reinícios da árvore.
- [x] Medir o tempo de execução de cada lote.
- [x] Criar o script de escala (1 contra N workers).
- [x] Implementar o painel web com Phoenix LiveView.

### Próximas etapas

- [ ] Preparar e ensaiar a demonstração prática.

## Contexto acadêmico

O projeto acompanha uma apresentação sobre Elixir, abordando sua arquitetura, paradigma, sistema de tipos, expressões, polimorfismo, concorrência e tolerância a falhas.

A implementação prática busca conectar os conceitos teóricos ao funcionamento de um sistema real.

---

**Disciplina:** Arquiteturas de Linguagens de Programação  
**Instituição:** CEFET/RJ  
**Linguagem:** Elixir

**Integrantes:**

- Ruan Pablo
- Tony Terra
- Maycom Estevão
- Rodrigo Lopes
