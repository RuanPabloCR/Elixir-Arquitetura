# Elixir — Sistema Resiliente de Processamento de Pedidos

> Projeto acadêmico desenvolvido para a disciplina de **Arquiteturas de Linguagens de Programação**, no CEFET/RJ.

## Sobre o projeto

Este projeto tem como objetivo explorar os principais recursos da linguagem **Elixir**, relacionando seus conceitos fundamentais às características que a tornam interessante para o desenvolvimento de sistemas concorrentes e resilientes.

A proposta é desenvolver um sistema de processamento de pedidos capaz de receber dados, validá-los, transformá-los e distribuí-los entre processos concorrentes.

Além de demonstrar o funcionamento da linguagem, o projeto busca evidenciar como Elixir e seu ecossistema, baseado na máquina virtual BEAM e no OTP, abordam problemas de concorrência, isolamento de falhas e recuperação de processos.

**Status:** Planejamento inicial — implementação ainda não iniciada.

## Objetivos

- Explorar o paradigma funcional e a imutabilidade.
- Demonstrar pattern matching e composição de funções.
- Compreender o modelo de processos da BEAM.
- Implementar processamento concorrente por troca de mensagens.
- Utilizar os recursos do OTP para supervisão e recuperação de falhas.
- Relacionar os recursos da linguagem aos conceitos estudados na disciplina.

## Funcionalidades planejadas

### 1. Processamento funcional de dados

Recebimento de uma coleção de pedidos, seguida por etapas de validação, filtragem e transformação.

Conceitos explorados:
- Pattern matching.
- Guards.
- Imutabilidade.
- Funções de ordem superior.
- Pipe operator (`|>`).

### 2. Processamento concorrente

Distribuição dos pedidos entre múltiplos workers, permitindo que diferentes tarefas sejam executadas simultaneamente.

Conceitos explorados:
- Processos leves da BEAM.
- Passagem de mensagens.
- Concorrência e paralelismo.
- Isolamento entre processos.

### 3. Supervisão e tolerância a falhas

Monitoramento dos workers e recuperação automática de processos que falharem durante a execução.

Conceitos explorados:
- OTP.
- Supervisors.
- Estratégias de reinicialização.
- Filosofia *Let It Crash*.

## Arquitetura proposta

```text
             Entrada de pedidos
                     |
                     v
          Pipeline de processamento
          (validação e transformação)
                     |
                     v
                 Dispatcher
                     |
          +----------+----------+
          |          |          |
          v          v          v
       Worker 1   Worker 2   Worker 3
          |          |          |
          +----------+----------+
                     |
                     v
              Supervisor OTP
                     |
                     v
           Resultados e métricas
```

A arquitetura é conceitual e poderá ser modificada durante a implementação.

## Live Cases

O desenvolvimento também será orientado por dois cenários demonstrativos:

**Live Case 01 — Transformação de dados**

Problema: como processar dados inconsistentes sem depender de alterações de estado?

Solução proposta: utilizar pattern matching, imutabilidade e composição de funções para construir um pipeline de transformação.

**Live Case 02 — Sistema resiliente**

Problema: como manter o processamento funcionando quando um dos workers falha?

Solução proposta: utilizar processos isolados e supervisão do OTP para recuperar workers sem interromper todo o sistema.

## Tecnologias

- **Elixir** — linguagem principal.
- **BEAM** — máquina virtual de execução.
- **OTP** — abstrações para concorrência, supervisão e construção de sistemas tolerantes a falhas.

## Estrutura planejada

```text
.
├── lib/
│   ├── orders/          # Representação e processamento de pedidos
│   ├── workers/         # Processos responsáveis pelas tarefas
│   ├── dispatcher/      # Distribuição de pedidos
│   └── application.ex   # Inicialização e supervisão OTP
├── test/                # Testes automatizados
├── mix.exs              # Configuração do projeto
└── README.md
```

A estrutura acima é uma previsão inicial e será ajustada conforme a implementação evoluir.

## Roadmap

- [ ] Definir a estrutura inicial do projeto.
- [ ] Implementar representação e validação de pedidos.
- [ ] Construir o pipeline funcional de processamento.
- [ ] Implementar workers concorrentes.
- [ ] Integrar o dispatcher.
- [ ] Implementar supervisão com OTP.
- [ ] Simular falhas e validar a recuperação dos processos.
- [ ] Desenvolver testes automatizados.
- [ ] Preparar demonstração prática.

## Contexto acadêmico

O projeto acompanha uma apresentação sobre Elixir, abordando sua arquitetura, paradigma, sistema de tipos, expressões, polimorfismo, concorrência e tolerância a falhas.

A implementação prática busca conectar os conceitos teóricos ao funcionamento de um sistema real.

---

**Disciplina:** Arquiteturas de Linguagens de Programação  
**Instituição:** CEFET/RJ  
**Linguagem:** Elixir

**Integrantes:** A definir.