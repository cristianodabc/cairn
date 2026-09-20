defmodule Cairn.Group do
  @moduledoc false

  @type fun :: Cairn.Function.fun()
  @type t :: [pid()]
  @type result :: {:ok, [Cairn.Message.t()]} | {:error, :timeout}

  @spec start_link([fun()]) :: {:ok, t()} | {:error, term()}
  def start_link(funs) do
    Cairn.Function.start_many(funs)
  end

  @spec dispatch(t(), Cairn.Message.payload()) :: [Cairn.Message.t()]
  def dispatch(pids, payload) do
    Cairn.dispatch(pids, payload)
  end

  @spec call(t(), Cairn.Message.payload(), Cairn.Await.wait()) :: result()
  def call(pids, payload, timeout \\ 5_000) do
    refs =
      pids
      |> dispatch(payload)
      |> Enum.map(& &1.ref)

    Cairn.Await.all(refs, timeout)
  end
end
