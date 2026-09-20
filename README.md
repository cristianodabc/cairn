# Cairn

Small OTP helpers for message delivery and supervised task callbacks.

## API

- `Cairn.Message`
- `Cairn.deliver/2`
- `Cairn.Server`
- `Cairn.Task`
- `Cairn.Await`

## Example

```elixir
defmodule Worker do
  use Cairn.Server

  def handle_msg(%Cairn.Message{ref: ref, payload: {:run, fun}}, state) do
    {:ok, _pid} = Cairn.Task.run(ref, fun)
    {:noreply, state}
  end

  def handle_task(ref, result, state) do
    send(state.test_pid, {:done, ref, result})
    {:noreply, state}
  end
end

ref = make_ref()
Cairn.deliver(pid, Cairn.Message.new(self(), {:run, fun}, ref))
{:ok, msg} = Cairn.Await.message(ref)
```

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

Not published yet.
