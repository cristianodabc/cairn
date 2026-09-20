defmodule Cairn.Function do
  @moduledoc false

  use Cairn.Server

  @type fun :: (Cairn.Message.payload() -> term())
  @type waiting :: %{Cairn.Message.ref() => Cairn.Message.from()}
  @type state :: %{fun: fun(), waiting: waiting()}

  @spec start_link(fun()) :: GenServer.on_start()
  def start_link(fun) when is_function(fun, 1) do
    GenServer.start_link(__MODULE__, fun)
  end

  @spec start_many([fun()]) :: {:ok, [pid()]} | {:error, term()}
  def start_many(funs) do
    funs
    |> Enum.reduce_while({:ok, []}, &start_one/2)
    |> normalize()
  end

  @impl GenServer
  def init(fun) do
    {:ok, %{fun: fun, waiting: %{}}}
  end

  @impl Cairn.Server
  def handle_msg(%Cairn.Message{from: from, payload: payload, ref: ref}, state) do
    {:ok, _pid} = Cairn.Task.run(ref, fn -> state.fun.(payload) end)
    {:noreply, put_in(state.waiting[ref], from)}
  end

  @impl Cairn.Server
  def handle_task(ref, result, state) do
    {from, state} = pop_in(state.waiting[ref])
    Cairn.deliver(from, Cairn.Message.new(self(), result, ref))
    {:noreply, state}
  end

  @spec start_one(fun(), {:ok, [pid()]}) ::
          {:cont, {:ok, [pid()]}} | {:halt, {:error, term()}}
  defp start_one(fun, {:ok, pids}) do
    case start_link(fun) do
      {:ok, pid} ->
        {:cont, {:ok, [pid | pids]}}

      error ->
        Enum.each(pids, &GenServer.stop/1)
        {:halt, error}
    end
  end

  @spec normalize({:ok, [pid()]} | {:error, term()}) :: {:ok, [pid()]} | {:error, term()}
  defp normalize({:ok, pids}) do
    {:ok, Enum.reverse(pids)}
  end

  defp normalize(error) do
    error
  end
end
