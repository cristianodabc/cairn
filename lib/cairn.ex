defmodule Cairn do
  @moduledoc """
  A simple message delivery system for Elixir processes.
  """

  @type dest :: pid() | atom() | {:global, term()} | {:via, module(), term()}

  alias Cairn.Message

  @doc """
  Delivers `msg` to `dest`. Fire and forget, at-most-once in-flight,
  no delivery guarantee beyond what `Kernel.send/2` provides.
  """
  @spec deliver(dest(), Message.t()) :: :ok
  def deliver(dest, %Message{} = msg) do
    dest |> resolve() |> send(msg)
    :ok
  end

  defp resolve(pid) when is_pid(pid), do: pid
  defp resolve(name) when is_atom(name), do: name
  defp resolve({:global, name}), do: :global.whereis_name(name)

  defp resolve({:via, mod, name}) do
    case mod.whereis_name(name) do
      :undefined ->
        raise ArgumentError,
              "unknown destination: #{inspect({:via, mod, name})}"

      pid ->
        pid
    end
  end
end
