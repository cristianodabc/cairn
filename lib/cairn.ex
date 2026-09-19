defmodule Cairn do
  @moduledoc false

  @type dest :: pid() | atom() | {:global, term()} | {:via, module(), term()}

  alias Cairn.Message

  @doc false
  @spec deliver(dest(), Message.t()) :: :ok
  def deliver(dest, %Message{} = msg) do
    dest |> resolve() |> send(msg)
    :ok
  end

  defp resolve(:undefined), do: raise(ArgumentError, "unknown destination")
  defp resolve(pid) when is_pid(pid), do: pid
  defp resolve(name) when is_atom(name), do: name
  defp resolve({:global, name}), do: :global.whereis_name(name) |> resolve()
  defp resolve({:via, mod, name}), do: name |> mod.whereis_name() |> resolve()
end
