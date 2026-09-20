defmodule Cairn.Await do
  @moduledoc false

  alias Cairn.Message

  @type ref :: Message.ref()
  @type wait :: non_neg_integer() | :infinity
  @type result :: {:ok, Message.t()} | {:error, :timeout}

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
end
