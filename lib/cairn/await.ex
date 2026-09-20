defmodule Cairn.Await do
  @moduledoc false

  alias Cairn.Message

  @type ref :: Message.ref()
  @type refs :: [ref()]
  @type wait :: non_neg_integer() | :infinity
  @type result :: {:ok, Message.t()} | {:error, :timeout}
  @type all_result :: {:ok, [Message.t()]} | {:error, :timeout}

  @spec message(ref(), wait()) :: result()
  def message(ref, timeout \\ 5_000) do
    receive do
      %Message{ref: ^ref} = msg ->
        {:ok, msg}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  @spec any(refs(), wait()) :: result()
  def any(refs, timeout \\ 5_000) do
    case take(refs, deadline(timeout), []) do
      {:ok, msg, stashed} ->
        restore(stashed)
        {:ok, msg}

      {:error, :timeout, stashed} ->
        restore(stashed)
        {:error, :timeout}
    end
  end

  @spec all(refs(), wait()) :: all_result()
  def all(refs, timeout \\ 5_000) do
    deadline = deadline(timeout)
    await_all(refs, %{}, deadline)
  end

  @spec await_all(refs(), %{ref() => Message.t()}, integer() | :infinity) :: all_result()
  defp await_all(refs, messages, deadline, stashed \\ []) do
    missing = Enum.reject(refs, &Map.has_key?(messages, &1))

    if missing == [] do
      restore(stashed)
      {:ok, Enum.map(refs, &Map.fetch!(messages, &1))}
    else
      case take(missing, deadline, stashed) do
        {:ok, %Message{ref: ref} = msg, stashed} ->
          await_all(refs, Map.put(messages, ref, msg), deadline, stashed)

        {:error, :timeout, stashed} ->
          restore(Map.values(messages) ++ stashed)
          {:error, :timeout}
      end
    end
  end

  @spec take(refs(), integer() | :infinity, [term()]) ::
          {:ok, Message.t(), [term()]} | {:error, :timeout, [term()]}
  defp take(refs, deadline, stashed) do
    receive do
      %Message{ref: ref} = msg ->
        if Enum.member?(refs, ref) do
          {:ok, msg, stashed}
        else
          take(refs, deadline, [msg | stashed])
        end

      msg ->
        take(refs, deadline, [msg | stashed])
    after
      remaining(deadline) ->
        {:error, :timeout, stashed}
    end
  end

  @spec restore([term()]) :: :ok
  defp restore(messages) do
    messages
    |> Enum.reverse()
    |> Enum.each(&send(self(), &1))
  end

  @spec deadline(wait()) :: integer() | :infinity
  defp deadline(:infinity) do
    :infinity
  end

  defp deadline(timeout) do
    System.monotonic_time(:millisecond) + timeout
  end

  @spec remaining(integer() | :infinity) :: non_neg_integer() | :infinity
  defp remaining(:infinity) do
    :infinity
  end

  defp remaining(deadline) do
    max(deadline - System.monotonic_time(:millisecond), 0)
  end
end
