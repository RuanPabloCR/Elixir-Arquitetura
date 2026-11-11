# Elixir — Sistema Resiliente de Processamento de Pedidos

> Projeto acadêmico desenvolvido para a disciplina de **Arquiteturas de Linguagens de Programação**, no CEFET/RJ.

## Sobre o projeto

Este projeto explora os principais recursos da linguagem **Elixir**, relacionando seus conceitos fundamentais às características que a tornam interessante para o desenvolvimento de sistemas concorrentes e resilientes.

A proposta é desenvolver um sistema de processamento de pedidos capaz de receber dados, validá-los, transformá-los e distribuí-los entre processos concorrentes.

Além de demonstrar o funcionamento da linguagem, o projeto busca evidenciar como Elixir e seu ecossistema, baseado na máquina virtual BEAM e no OTP, abordam problemas de concorrência, isolamento de falhas e recuperação de processos.

**Status:** Implementação iniciada. A etapa atual cobre apenas a **representação e a validação de pedidos** (veja [Escopo da etapa atual](#escopo-da-etapa-atual)). Concorrência, supervisão e interface visual ficam para as próximas etapas.

## Objetivos

- Explorar o paradigma funcional e a imutabilidade.
- Demonstrar pattern matching e composição de funções.
- Apresentar o sistema de tipos e o polimorfismo em Elixir.
- Compreender o modelo de processos da BEAM.
- Implementar processamento concorrente por troca de mensagens.
- Utilizar os recursos do OTP para supervisão e recuperação de falhas.
- Relacionar os recursos da linguagem aos conceitos estudados na disciplina.

## Escopo da etapa atual

Nesta etapa, o trabalho se limita a **implementar, representar e validar pedidos**. Nenhum processo, worker ou supervisor é criado ainda: tudo é feito com funções puras, o que permite testar a lógica isoladamente antes de distribuí-la.

### O que será entregue

1. **Representação:** uma `struct` para cada tipo de pedido, com `@type` associado.
2. **Polimorfismo:** um `Protocol` que calcula o total do pedido conforme o seu tipo.
3. **Validação:** funções que verificam um pedido e retornam `{:ok, pedido}` ou `{:error, motivo}`.
4. **Pipeline funcional:** recebe uma coleção de pedidos e a separa em válidos e inválidos.

### Fora do escopo desta etapa

- Testes automatizados: por se tratar de um projeto de apresentação, o escopo foi reduzido e a verificação é feita executando o programa de demonstração.
- Workers, Dispatcher, Supervisor e qualquer processamento concorrente.
- Reprocessamento, tentativas e métricas de execução.
- Interface visual.

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

O campo `falhas_simuladas` existe para as etapas futuras de demonstração e define em quantas tentativas o worker deve falhar. Nesta etapa ele só é **representado e validado**; não tem efeito sobre o processamento.

| Valor | Comportamento esperado (etapas futuras) |
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

A validação segue a convenção do Elixir para erros esperados: retorna `{:error, motivo}` e **não** lança exceção. Isso mantém a distinção entre pedido inválido (dado ruim, tratado no pipeline) e falha inesperada (crash, tratado pelo OTP nas etapas futuras).

### Conceitos explorados nesta etapa

- Structs e typespecs (`@type` e `@spec`).
- Pattern matching e guards.
- Polimorfismo com `Protocol`.
- Imutabilidade e composição de funções com o pipe operator (`|>`).
- Funções de ordem superior (`Enum.map`, `Enum.reduce`, `Enum.split_with`).
- Retorno `{:ok, _}` / `{:error, _}` com `with`.

## Funcionalidades planejadas

### 1. Processamento funcional de dados *(etapa atual)*

Recebimento de uma coleção de pedidos, seguida por etapas de validação, filtragem e transformação.

### 2. Tipos e polimorfismo *(etapa atual)*

Representação dos pedidos com structs e cálculo do total conforme o tipo, usando `Protocol`.

### 3. Processamento concorrente

Distribuição dos pedidos entre múltiplos workers, permitindo que diferentes tarefas sejam executadas simultaneamente.

Conceitos explorados: processos leves da BEAM, passagem de mensagens, concorrência e paralelismo, isolamento entre processos.

### 4. Supervisão e tolerância a falhas

Monitoramento dos workers, recuperação automática dos processos que falharem e reprocessamento dos pedidos interrompidos.

Conceitos explorados: OTP, `GenServer` e `Supervisor`, árvore de supervisão, estratégias de reinicialização, `Process.monitor`, filosofia *Let It Crash*.

### 5. Visualização da execução

Uma interface para acompanhar o sistema em funcionamento: workers ativos, pedidos em andamento, e controles para ajustar a quantidade de workers e simular falhas. Veja [Visualização](#visualização-decisão-em-aberto).

## Arquitetura proposta

A arquitetura é conceitual e poderá ser modificada durante a implementação. A etapa atual implementa apenas o bloco de validação e transformação.

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
└── Supervisor raiz (:rest_for_one)
    ├── Resultados
    ├── Dispatcher
    └── DynamicSupervisor dos workers (:one_for_one)
        ├── Worker 1
        ├── Worker 2
        ├── ...
        └── Worker N   (N configurável, de dezenas a 100 mil)
```

- Se um worker falhar, somente ele será reiniciado.
- Se o Dispatcher falhar, ele e os workers serão reiniciados, preservando os Resultados.
- Os processos mais simples e estáveis ficam no início da árvore.
- Os workers ficam sob um `DynamicSupervisor`, e não sob um `Supervisor` com filhos fixos: a quantidade `N` é definida em tempo de execução e pode ser alterada durante a demonstração.

### Escala dos workers

Três workers não diferenciam o Elixir de linguagens mainstream, que também lidam bem com 3 threads. O que o projeto quer mostrar é que, na BEAM, um worker é um **processo leve**, e por isso o sistema pode ter milhares deles.

Medição feita na máquina de desenvolvimento, com processos ociosos (Elixir 1.20 / OTP 29):

| Processos | Tempo para criar | Memória total |
|---|---|---|
| 10 mil | 31 ms | 26 MB |
| 100 mil | 545 ms | 262 MB |
| 1 milhão | 5,8 s | 2,6 GB |

Cada processo custa cerca de 2,7 KB. Uma thread do sistema operacional costuma reservar cerca de 1 MB de pilha, então 100 mil threads exigiriam algo na ordem de 100 GB só de pilha.

**Configurações previstas para a demonstração:**

| Modo | Workers | Objetivo |
|---|---|---|
| Padrão | 1.000 | Fluxo normal, fácil de acompanhar |
| Escala | 100.000 | Mostrar que a quantidade não é um problema |

Esses valores ainda serão ajustados na prática. O limite de 1 milhão de processos existe, mas custa 2,6 GB de memória e não acrescenta nada à demonstração.

**Pontos de atenção:**

- O Dispatcher atual escolhe o worker com `Enum.at(workers, i)`, que percorre a lista a cada pedido. Com muitos workers isso fica quadrático e precisa mudar (por exemplo, usar uma tupla ou escolher o próximo worker livre).
- O `DynamicSupervisor` aceita por padrão 3 reinícios em 5 segundos e depois cai. Derrubar vários workers em sequência na demonstração exige aumentar o `max_restarts`.
- O limite de processos da BEAM é configurável (`+P`) e hoje está em cerca de 1 milhão.
- Os `IO.puts` dos workers precisam ser substituídos por eventos ou contadores. Com 100 mil workers, imprimir cada um inviabiliza a demonstração e a visualização.

## Tratamento de erros

| Situação | Exemplo | Tratamento |
|---|---|---|
| Erro esperado | Valor negativo ou campo obrigatório ausente | Retorno `{:error, motivo}` no pipeline, sem crash |
| Falha inesperada | Exceção durante o processamento em um worker | Crash do worker e recuperação pelo OTP |

## Estratégia de recuperação

*Planejada para as etapas de concorrência e supervisão.*

1. O Dispatcher registra quais pedidos estão em andamento em cada worker.
2. Cada worker se registra ao iniciar, pois seu PID muda após um reinício.
3. O Dispatcher usa `Process.monitor` para detectar a queda de um worker.
4. O pedido interrompido volta para a fila, com o número de tentativas incrementado.
5. Ao atingir o limite de 3 tentativas, o pedido vai para a lista de falhas.

O limite de tentativas impede que um pedido problemático derrube repetidamente os workers. O `max_restarts` do supervisor será configurado de acordo com as falhas simuladas na demonstração.

### Limitações conhecidas

A fila e os resultados ficam em memória. A supervisão restaura o serviço, mas não preserva os dados de um processo que falhou. Portanto, se o Dispatcher cair, sua fila será perdida. Em um sistema real, esses dados precisariam de armazenamento persistente.

## Métricas

Planejadas para as etapas posteriores. Ao final da execução, o sistema deverá exibir:

- Pedidos processados.
- Pedidos inválidos.
- Pedidos reprocessados.
- Pedidos enviados à lista de falhas.
- Reinícios de workers.
- Tempo total de execução.

## Visualização (decisão em aberto)

Queremos um pequeno frontend para visualizar o programa em execução: a quantidade de workers, o estado de cada pedido e a simulação de falhas (por exemplo, um botão que derruba um worker). Ainda não decidimos se o projeto será **Elixir puro** ou se terá uma camada web. As opções consideradas:

| Opção | Linguagem | Prós | Contras |
|---|---|---|---|
| **Phoenix LiveView** | Elixir (sem JavaScript escrito por nós) | Continua 100% Elixir; os processos publicam eventos via `Phoenix.PubSub` e a tela atualiza em tempo real; botões chamam funções do sistema diretamente | Adiciona a dependência do Phoenix e mais conceitos para explicar |
| **Plug + Cowboy com SSE/WebSocket e página HTML estática** | Elixir + HTML/JS simples | Dependências mínimas; o servidor continua em Elixir | A página precisa de algum JavaScript; mais código manual |
| **Dashboard no terminal** (`IO.ANSI` ou biblioteca TUI) | Elixir puro | Sem dependências web | Menos atrativo para a apresentação |
| **`:observer.start()`** | Ferramenta da própria BEAM | Já mostra a árvore de supervisão e os PIDs, sem código | Não permite controlar a simulação |

**Inclinação atual:** manter o núcleo (pedidos, workers, supervisão) em Elixir puro e independente da interface, e adicionar o **Phoenix LiveView** depois como camada de visualização. Assim a lógica não depende do frontend, e o `:observer` serve de reserva para a demonstração.

Esta decisão **não bloqueia a etapa atual**, que não possui interface.

## Live Cases

**Live Case 01 — Transformação de dados**

Problema: como processar dados inconsistentes sem depender de alterações de estado?

Solução proposta: utilizar pattern matching, imutabilidade e composição de funções para construir um pipeline que separa pedidos válidos e inválidos.

**Live Case 02 — Sistema resiliente**

Problema: como manter o processamento funcionando, sem perder o pedido em andamento, quando um dos workers falha?

Solução proposta: utilizar processos isolados, supervisão do OTP e monitoramento pelo Dispatcher para recuperar o worker e reprocessar o pedido.

### Roteiro da demonstração

1. **Concorrência e escala:** executar o mesmo lote com 1 worker, depois com 1.000 e depois com 100.000, comparando os tempos e mostrando a memória usada e a quantidade de processos (`:erlang.system_info(:process_count)`).
2. **Isolamento:** encerrar um worker (ou vários, escolhidos aleatoriamente) com `Process.exit(pid, :kill)` enquanto os outros continuam processando.
3. **Recuperação:** mostrar o novo PID do worker e o reprocessamento do pedido interrompido.
4. **Limite de tentativas:** enviar um pedido que sempre falha e mostrar sua chegada à lista de falhas.
5. **Visualização:** exibir a árvore de supervisão e o estado dos workers (frontend ou `:observer.start()`).

## Tecnologias

- **Elixir** — linguagem principal.
- **BEAM** — máquina virtual de execução.
- **OTP** — abstrações para concorrência, supervisão e construção de sistemas tolerantes a falhas.
- **Phoenix LiveView** — visualização (a confirmar).

## Estrutura planejada

A estrutura abaixo é uma previsão inicial e será ajustada conforme a implementação evoluir. Os itens marcados com *(atual)* fazem parte da etapa em andamento.

```text
.
├── lib/
│   ├── orders/          # (atual) Structs, protocolo, validação e pipeline
│   ├── workers/         # Workers e seu supervisor
│   ├── dispatcher/      # Distribuição, monitoramento e reprocessamento
│   ├── results/         # Resultados e métricas
│   └── application.ex   # Inicialização da árvore de supervisão
├── mix.exs              # Configuração do projeto
└── README.md
```

> Para executar a demonstração da etapa atual: `mix run demo.exs`. O arquivo `src/main.ex` é um protótipo antigo (calculadora) sem relação com os pedidos.

## Roadmap

### Etapa atual — representação e validação de pedidos

- [x] Criar o projeto com `mix new` e migrar a estrutura inicial.
- [x] Definir as structs `PedidoFisico` e `PedidoDigital`, com `@type`.
- [x] Implementar o protocolo de cálculo do total.
- [x] Implementar a validação (`{:ok, pedido}` / `{:error, motivo}`).
- [x] Construir o pipeline que separa pedidos válidos e inválidos.
- [x] Criar um script de demonstração com pedidos válidos e inválidos.

### Próximas etapas

- [ ] Implementar os workers concorrentes.
- [ ] Implementar o processo de resultados e métricas.
- [ ] Integrar o Dispatcher.
- [ ] Implementar a árvore de supervisão com OTP.
- [ ] Implementar o monitoramento e o reprocessamento de pedidos.
- [ ] Simular falhas e validar a recuperação dos processos.
- [ ] Decidir e implementar a visualização (Elixir puro ou LiveView).
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
