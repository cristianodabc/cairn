# Cairn

[![CI](https://github.com/cristianodabc/cairn/actions/workflows/ci.yml/badge.svg)](https://github.com/cristianodabc/cairn/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/cairn.svg)](https://hex.pm/packages/cairn)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/cristianodabc/cairn/blob/main/LICENSE)

Small OTP helpers for message delivery and supervised task callbacks.

Cairn tries not to become a framework for OTP. It is a thin layer for starting
lightweight processes, passing messages, running supervised work, and waiting
on refs.

## Try it

```sh
cd cairn
mix deps.get
iex -S mix
```

Paste this into IEx:

```elixir
{:ok, pid} = Cairn.Function.start_link(fn value -> value * 2 end)

msg = Cairn.dispatch(pid, 21)

{:ok, %Cairn.Message{payload: {:ok, 42}}} =
  Cairn.Await.message(msg.ref)
```

## API

- `Cairn.Message`
- `Cairn.deliver/2`
- `Cairn.Server`
- `Cairn.Function`
- `Cairn.Task`
- `Cairn.Await`

## Many Processes

```elixir
{:ok, pids} =
  1..1_000
  |> Enum.map(fn n -> fn input -> {n, input * n} end end)
  |> Cairn.Function.start_many()

msgs = Cairn.dispatch(pids, 21)
refs = Enum.map(msgs, & &1.ref)

{:ok, replies} = Cairn.Await.all(refs)
```

Use as many processes as your BEAM node can actually afford. Cairn does not add a pool or scheduler above OTP.
If your node can handle one million processes, `pids` can be one million processes.

## AI orchestration

```elixir
{:ok, classifier} =
  Cairn.Function.start_link(fn text ->
    MyApp.LLM.classify_ticket(text)
  end)

msg = Cairn.dispatch(classifier, "payment failed after upgrade")

{:ok, %Cairn.Message{payload: {:ok, %{team: team, summary: summary}}}} =
  Cairn.Await.message(msg.ref)
```

```elixir
{:ok, pids} =
  Cairn.Function.start_many([
    fn topic -> MyApp.Search.notes(topic) end,
    fn topic -> MyApp.LLM.outline(topic) end,
    fn topic -> MyApp.LLM.risks(topic) end
  ])

refs =
  pids
  |> Cairn.dispatch("elixir lightweight processes")
  |> Enum.map(& &1.ref)

{:ok, replies} = Cairn.Await.all(refs)
```

```elixir
pids
|> Cairn.dispatch("index my release notes")
|> Enum.map(& &1.ref)
|> Cairn.Await.stream()
|> Enum.each(fn msg -> IO.inspect(msg.payload) end)
```

```elixir
case Cairn.Await.collect(refs, 2_000) do
  {:ok, replies} -> replies
  {:partial, replies, missing} -> {replies, missing}
end
```

### Human in the loop

Human decisions are just messages too:

```elixir
def handle_msg(%Cairn.Message{from: from, ref: ref, payload: {:draft, text}}, state) do
  send(state.ui, {:review, self(), ref, text})
  {:noreply, put_in(state.pending[ref], from)}
end

def handle_msg(%Cairn.Message{payload: {:approved, ref, edits}}, state) do
  case pop_in(state.pending[ref]) do
    {nil, state} ->
      {:noreply, state}

    {from, state} ->
      Cairn.deliver(from, Cairn.Message.new(self(), {:ok, edits}, ref))
      {:noreply, state}
  end
end
```

## Install

```elixir
def deps do
  [
    {:cairn, "~> 0.1.3"}
  ]
end
```

## Release

Set `HEX_API_KEY` in GitHub repository secrets. Run the Release workflow with
the next version, without the `v` prefix.

The workflow updates `mix.exs`, README, and `CHANGELOG.md`; runs quality checks;
publishes Hex; tags the commit; and creates the GitHub release.
