defmodule Cairn.Await do
  @moduledoc """
  Mailbox helpers for awaiting Cairn messages by ref.
  """

  alias Cairn.Message

  @type ref :: Message.ref()
  @type refs :: [ref()]
  @type wait :: non_neg_integer() | :infinity
  @type result :: {:ok, Message.t()} | {:error, :timeout}
  @type all_result :: {:ok, [Message.t()]} | {:error, :timeout}
  @type collect_result :: {:ok, [Message.t()]} | {:partial, [Message.t()], refs()}
  @type ref_set :: MapSet.t(ref())
  @type message_stream :: Enumerable.t()

  @doc """
  Waits for one message matching a ref.
  """
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

  @doc """
  Waits for the first message matching any of the refs.
  """
  @spec any(refs(), wait()) :: result()
  def any(refs, timeout \\ 5_000)

  def any([], _timeout) do
    {:error, :timeout}
  end

  def any(refs, timeout) do
    case take(MapSet.new(refs), deadline(timeout), []) do
      {:ok, msg, stashed} ->
        restore(stashed)
        {:ok, msg}

      {:error, :timeout, stashed} ->
        restore(stashed)
        {:error, :timeout}
    end
  end

  @doc """
  Waits for all refs and returns messages in ref order.
  """
  @spec all(refs(), wait()) :: all_result()
  def all(refs, timeout \\ 5_000) do
    all(refs, MapSet.new(refs), %{}, deadline(timeout), [])
  end

  @doc """
  Waits for refs and returns partial results on timeout.
  """
  @spec collect(refs(), wait()) :: collect_result()
  def collect(refs, timeout \\ 5_000) do
    collect(refs, MapSet.new(refs), %{}, deadline(timeout), [])
  end

  @doc """
  Streams messages as matching refs arrive.
  """
  @spec stream(refs(), wait()) :: message_stream()
  def stream(refs, timeout \\ 5_000) do
    Stream.resource(
      fn -> {MapSet.new(refs), deadline(timeout), []} end,
      &next/1,
      fn {_refs, _deadline, stashed} -> restore(stashed) end
    )
  end

  @spec next({ref_set(), integer() | :infinity, [term()]}) ::
          {[Message.t()], {ref_set(), integer() | :infinity, [term()]}} | {:halt, term()}
  defp next({refs, deadline, stashed}) do
    if MapSet.size(refs) == 0 do
      {:halt, {refs, deadline, stashed}}
    else
      case take(refs, deadline, stashed) do
        {:ok, %Message{ref: ref} = msg, stashed} ->
          {[msg], {MapSet.delete(refs, ref), deadline, stashed}}

        {:error, :timeout, stashed} ->
          {:halt, {refs, deadline, stashed}}
      end
    end
  end

  @spec collect(refs(), ref_set(), %{ref() => Message.t()}, integer() | :infinity, [term()]) ::
          collect_result()
  defp collect(refs, remaining, messages, deadline, stashed) do
    if MapSet.size(remaining) == 0 do
      restore(stashed)
      {:ok, ordered(refs, messages)}
    else
      case take(remaining, deadline, stashed) do
        {:ok, %Message{ref: ref} = msg, stashed} ->
          collect(
            refs,
            MapSet.delete(remaining, ref),
            Map.put(messages, ref, msg),
            deadline,
            stashed
          )

        {:error, :timeout, stashed} ->
          restore(stashed)
          {:partial, ordered_present(refs, messages), missing(refs, messages)}
      end
    end
  end

  @spec all(refs(), ref_set(), %{ref() => Message.t()}, integer() | :infinity, [term()]) ::
          all_result()
  defp all(refs, remaining, messages, deadline, stashed) do
    if MapSet.size(remaining) == 0 do
      restore(stashed)
      {:ok, ordered(refs, messages)}
    else
      case take(remaining, deadline, stashed) do
        {:ok, %Message{ref: ref} = msg, stashed} ->
          all(refs, MapSet.delete(remaining, ref), Map.put(messages, ref, msg), deadline, stashed)

        {:error, :timeout, stashed} ->
          restore(Map.values(messages) ++ stashed)
          {:error, :timeout}
      end
    end
  end

  @spec take(ref_set(), integer() | :infinity, [term()]) ::
          {:ok, Message.t(), [term()]} | {:error, :timeout, [term()]}
  defp take(refs, deadline, stashed) do
    receive do
      %Message{ref: ref} = msg ->
        if MapSet.member?(refs, ref) do
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

  @spec ordered(refs(), %{ref() => Message.t()}) :: [Message.t()]
  defp ordered(refs, messages) do
    Enum.map(refs, &Map.fetch!(messages, &1))
  end

  @spec ordered_present(refs(), %{ref() => Message.t()}) :: [Message.t()]
  defp ordered_present(refs, messages) do
    refs
    |> Enum.filter(&Map.has_key?(messages, &1))
    |> Enum.map(&Map.fetch!(messages, &1))
  end

  @spec missing(refs(), %{ref() => Message.t()}) :: refs()
  defp missing(refs, messages) do
    Enum.reject(refs, &Map.has_key?(messages, &1))
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
