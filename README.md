# Cairn

[![CI](https://github.com/cristianodabc/cairn/actions/workflows/ci.yml/badge.svg)](https://github.com/cristianodabc/cairn/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/cairn.svg)](https://hex.pm/packages/cairn)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/cristianodabc/cairn/blob/main/LICENSE)

Small OTP helpers for message delivery and supervised task callbacks.

## Try it

```sh
cd cairn
iex -S mix
```

Paste this into IEx:

```elixir
defmodule Worker do
  use Cairn.Server

  def handle_msg(%Cairn.Message{ref: ref, payload: {:run, fun}}, state) do
    {:ok, _pid} = Cairn.Task.run(ref, fun)
    {:noreply, state}
  end

  def handle_task(ref, result, state) do
    Cairn.deliver(state.reply_to, Cairn.Message.new(self(), result, ref))
    {:noreply, state}
  end
end

{:ok, pid} = Worker.start_link(%{reply_to: self()})

msg = Cairn.Message.new(self(), {:run, fn -> 21 * 2 end})
Cairn.deliver(pid, msg)

{:ok, %Cairn.Message{payload: {:ok, 42}}} = Cairn.Await.message(msg.ref)
```

## API

- `Cairn.Message`
- `Cairn.deliver/2`
- `Cairn.Server`
- `Cairn.Function`
- `Cairn.Group`
- `Cairn.Task`
- `Cairn.Await`

## Groups

```elixir
{:ok, group} =
  1..1_000
  |> Enum.map(fn n -> fn input -> {n, input * n} end end)
  |> Cairn.Group.start_link()

{:ok, replies} = Cairn.Group.call(group, 21)
```

Use as many processes as your BEAM node can actually afford. Cairn does not add a pool or scheduler above OTP.
If your node can handle one million processes, the group can be one million processes.

## AI orchestration

```elixir
defmodule Triage do
  use Cairn.Server

  def handle_msg(%Cairn.Message{ref: ref, payload: {:ticket, text}}, state) do
    {:ok, _pid} = Cairn.Task.run(ref, fn -> MyApp.LLM.classify_ticket(text) end)
    {:noreply, state}
  end

  def handle_task(ref, {:ok, %{team: team, summary: summary}}, state) do
    Cairn.deliver(team, Cairn.Message.new(self(), {:ticket_summary, summary}, ref))
    {:noreply, state}
  end
end
```

```elixir
defmodule Researcher do
  use Cairn.Server

  def handle_msg(%Cairn.Message{ref: ref, payload: {:brief, topic}}, state) do
    {:ok, _pid} = Cairn.Task.run(ref, fn -> MyApp.Search.notes(topic) end)
    {:noreply, state}
  end

  def handle_task(ref, {:ok, notes}, state) do
    Cairn.deliver(:writer, Cairn.Message.new(self(), {:draft, notes}, ref))
    {:noreply, state}
  end
end

defmodule Writer do
  use Cairn.Server

  def handle_msg(%Cairn.Message{ref: ref, payload: {:draft, notes}}, state) do
    {:ok, _pid} = Cairn.Task.run(ref, fn -> MyApp.LLM.write_brief(notes) end)
    {:noreply, state}
  end
end
```

## Install

```elixir
def deps do
  [
    {:cairn, "~> 0.1.0"}
  ]
end
```
