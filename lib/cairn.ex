defmodule Cairn do
  @moduledoc """
  Message delivery helpers.
  """

  @type dest :: pid() | atom() | {:global, term()} | {:via, module(), term()}

  alias Cairn.Message

  @doc """
  Delivers a message to a process, local name, global name, or via tuple.
  """
  @spec deliver(dest(), Message.t()) :: :ok
  def deliver(dest, %Message{} = msg) do
    dest |> resolve() |> send(msg)
    :ok
  end

  @doc """
  Creates and delivers messages to one or more destinations.
  """
  @spec dispatch(dest() | [dest()], Message.payload()) :: Message.t() | [Message.t()]
  def dispatch(dest, payload) when not is_list(dest) do
    msg = Message.new(self(), payload)
    :ok = deliver(dest, msg)
    msg
  end

  def dispatch(dests, payload) do
    Enum.map(dests, fn dest ->
      dispatch(dest, payload)
    end)
  end

  defp resolve(:undefined), do: raise(ArgumentError, "unknown destination")
  defp resolve(pid) when is_pid(pid), do: pid
  defp resolve(name) when is_atom(name), do: name
  defp resolve({:global, name}), do: :global.whereis_name(name) |> resolve()
  defp resolve({:via, mod, name}), do: name |> mod.whereis_name() |> resolve()
end
