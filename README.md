# Cairn

[![CI](https://github.com/cristianodabc/cairn/actions/workflows/ci.yml/badge.svg)](https://github.com/cristianodabc/cairn/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/cairn.svg)](https://hex.pm/packages/cairn)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/cristianodabc/cairn/blob/main/LICENSE)

Cairn is a small OTP library for correlated messaging, lightweight function
processes, supervised work, and waiting on results.

It stays close to OTP: processes are GenServers, messages use ordinary BEAM
mailboxes, and supervision uses standard OTP supervisors. Cairn adds a few
conventions around those primitives rather than introducing a new runtime,
workflow model, or agent framework.

## Motivation

OTP already gives Elixir the hard parts: processes, mailboxes, supervisors,
tasks, registries, and failure isolation.

Cairn exists for the small pattern that keeps reappearing in orchestration code:

- wrap work in a message with `from`, `payload`, and `ref`
- send it to one process or many processes
- reply with the same ref
- wait for one, many, partial, or streamed replies
- run task work from a server callback and receive the result in the same server

That is useful for fan-out/fan-in, background work, service coordination,
pipelines, human approval, and AI orchestration.

## Blunt Q/A

**Why not just use OTP?**

You should. Cairn does not replace OTP. It standardizes a small recurring
pattern: correlated messages, function-backed processes, waiting on multiple
replies, and supervised callbacks.

**Is this worth a dependency for 20 lines of code?**

Maybe not for one call site. It starts to pay off when the same message/ref
pattern appears across workers, LiveViews, task callbacks, and fan-out code.

**Is this an agent framework?**

No. Cairn has no agents, tools, memory, chains, graphs, plugins, or workflow
DSL. AI is only one possible use case.

**Does it hide processes?**

No. A `Cairn.Server` is a GenServer. `Cairn.Function` is a GenServer that calls
a function. Messages still go through process mailboxes.

**Does it add a pool or scheduler?**

No. If you start 1,000 processes, they are 1,000 BEAM processes. If your node
can afford more, Cairn does not add a separate limiter.

**What about "let it crash"?**

`Cairn.Function` treats function invocation failures as reply values. That is
intentional for request/reply work where the caller expects a result. Use a
custom `Cairn.Server` when you want different crash semantics.

**What is the main tradeoff?**

`Cairn.Await` receives messages from the caller mailbox while looking for refs
and restores unrelated messages afterward. That keeps the API small, but it also
means the caller should treat `Await` as mailbox coordination code, not magic.

## Try it

```sh
cd cairn
mix deps.get
iex -S mix
```

Paste this into IEx:

```elixir
{:ok, worker} = Cairn.Function.start_link(fn value -> value * 2 end)

msg = Cairn.dispatch(worker, 21)

{:ok, %Cairn.Message{payload: {:ok, 42}}} =
  Cairn.Await.message(msg.ref)
```

Function workers treat invocation failures as values:

```elixir
{:ok, worker} = Cairn.Function.start_link(fn _input -> raise "failed" end)

msg = Cairn.dispatch(worker, :run)

{:ok, %Cairn.Message{payload: {:error, %RuntimeError{message: "failed"}}}} =
  Cairn.Await.message(msg.ref)
```

## Livebook

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fcristianodabc%2Fcairn%2Fblob%2Fmain%2Fnotebooks%2Fcairn_features.livemd)

Feature tour covering function workers, fan-out/fan-in, streaming,
supervision, server callbacks, task callbacks, and human review.

## API

- `Cairn.Message.new/3` and `Cairn.Message.reply/2`
- `Cairn.deliver/2` and `Cairn.dispatch/2`
- `Cairn.Server` with `handle_msg/2` and `handle_task/3`
- `Cairn.Function.start_link/2`, `Cairn.Function.start_many/1`, and supervised child specs
- `Cairn.Task.run/2`
- `Cairn.Await.message/2`, `any/2`, `all/2`, `collect/2`, and `stream/2`

## Architecture

```text
Cairn.dispatch/2 --> Cairn.Message --> process mailbox
Cairn.deliver/2  --> Cairn.Message --> process mailbox

Cairn.Function   --> Cairn.Server --> GenServer
Cairn.Task.run/2 --> Task.Supervisor --> Cairn.Server.handle_task/3

caller mailbox --> Cairn.Await --> replies matched by ref
```

## Fan-out/Fan-in

```elixir
{:ok, workers} =
  Cairn.Function.start_many([
    fn input -> {:double, input * 2} end,
    fn input -> {:square, input * input} end,
    fn input -> {:string, Integer.to_string(input)} end
  ])

refs =
  workers
  |> Cairn.dispatch(21)
  |> Enum.map(& &1.ref)

{:ok, replies} = Cairn.Await.all(refs)

Enum.map(replies, & &1.payload)
```

## First Reply

```elixir
{:ok, workers} =
  Cairn.Function.start_many([
    fn query ->
      Process.sleep(120)
      {:slow, query}
    end,
    fn query ->
      Process.sleep(20)
      {:fast, query}
    end
  ])

refs =
  workers
  |> Cairn.dispatch("lookup")
  |> Enum.map(& &1.ref)

{:ok, first} = Cairn.Await.any(refs)

first.payload
```

## Partial and Streamed Replies

```elixir
case Cairn.Await.collect(refs, 2_000) do
  {:ok, replies} ->
    replies

  {:partial, replies, missing} ->
    {replies, missing}
end
```

```elixir
refs
|> Cairn.Await.stream()
|> Enum.each(fn msg ->
  IO.inspect(msg.payload)
end)
```

## Supervision

Function workers are ordinary supervisor children:

```elixir
children = [
  {Cairn.Function, {:classify, &MyApp.Classifier.run/1}},
  {Cairn.Function, {:retrieve, &MyApp.Search.run/1}}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Named workers are ordinary OTP names:

```elixir
name = {:via, Registry, {MyApp.Registry, :classify}}

children = [
  {Registry, keys: :unique, name: MyApp.Registry},
  {Cairn.Function, {:classify, &MyApp.Classifier.run/1, name: name}}
]

Supervisor.start_link(children, strategy: :one_for_one)

msg = Cairn.dispatch(name, "refund request")

Cairn.Await.message(msg.ref)
```

## Server Callbacks

Use `Cairn.Server` when a process needs state and async work:

```elixir
defmodule MyApp.Worker do
  use Cairn.Server

  @impl GenServer
  def init(_arg) do
    {:ok, %{pending: %{}}}
  end

  @impl Cairn.Server
  def handle_msg(%Cairn.Message{from: caller, ref: ref, payload: input}, state) do
    {:ok, _pid} =
      Cairn.Task.run(ref, fn ->
        MyApp.Expensive.run(input)
      end)

    {:noreply, put_in(state.pending[ref], caller)}
  end

  @impl Cairn.Server
  def handle_task(ref, result, state) do
    {caller, state} = pop_in(state.pending[ref])

    if caller do
      Cairn.deliver(caller, Cairn.Message.new(self(), result, ref))
    end

    {:noreply, state}
  end
end
```

## Human Review

Human approval can be represented as another message exchange:

```elixir
def handle_msg(%Cairn.Message{from: caller, ref: ref, payload: {:draft, prompt}}, state) do
  {:ok, _pid} =
    Cairn.Task.run(ref, fn ->
      MyApp.LLM.draft(prompt)
    end)

  {:noreply, put_in(state.pending[ref], caller)}
end

def handle_task(ref, {:ok, draft}, state) do
  send(state.ui, {:review, self(), ref, draft})
  {:noreply, state}
end

def handle_msg(%Cairn.Message{payload: {:approved, ref, text}}, state) do
  {caller, state} = pop_in(state.pending[ref])

  if caller do
    Cairn.deliver(caller, Cairn.Message.new(self(), {:ok, text}, ref))
  end

  {:noreply, state}
end
```

The review UI can be a Phoenix LiveView, channel, controller, or another OTP
process.

## AI Orchestration

AI work is just one use case for the same primitives:

```text
caller --dispatch(prompt)--> search
       --dispatch(prompt)--> outline
       --dispatch(prompt)--> risks

search  --reply(ref)--> caller
outline --reply(ref)--> caller
risks   --reply(ref)--> caller

caller --Await.all(refs)--> results
```

```elixir
{:ok, workers} =
  Cairn.Function.start_many([
    &MyApp.Search.notes/1,
    &MyApp.LLM.outline/1,
    &MyApp.LLM.risks/1
  ])

refs =
  workers
  |> Cairn.dispatch("elixir lightweight processes")
  |> Enum.map(& &1.ref)

{:ok, replies} = Cairn.Await.all(refs)

Enum.map(replies, & &1.payload)
```

## Install

```elixir
def deps do
  [
    {:cairn, "~> 0.1.6"}
  ]
end
```

## Release

Set `HEX_API_KEY` in GitHub repository secrets. Run the Release workflow with
the next unreleased version, without the `v` prefix.

The workflow updates `mix.exs`, README, and `CHANGELOG.md`; runs quality checks;
publishes Hex; tags the commit; and creates the GitHub release.

If the tag already exists but Hex does not have that version, the workflow
publishes the existing tag instead of rebuilding from `main`.
