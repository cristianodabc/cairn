defmodule Cairn.Function do
  @moduledoc """
  Function-backed Cairn servers.
  """

  use Cairn.Server

  @type fun :: (Cairn.Message.payload() -> term())
  @type child_id :: term()
  @type child_arg :: fun() | {child_id(), fun()} | {child_id(), fun(), GenServer.options()}
  @type state :: %{fun: fun()}

  @spec child_spec(child_arg()) :: Supervisor.child_spec()
  def child_spec(fun) when is_function(fun, 1) do
    child_spec({{__MODULE__, fun}, fun, []})
  end

  def child_spec({id, fun}) when is_function(fun, 1) do
    child_spec({id, fun, []})
  end

  def child_spec({id, fun, opts}) when is_function(fun, 1) and is_list(opts) do
    %{
      id: id,
      start: {__MODULE__, :start_link, [fun, opts]},
      type: :worker
    }
  end

  @spec start_many([fun()]) :: {:ok, [pid()]} | {:error, term()}
  def start_many(funs) do
    funs
    |> Enum.reduce_while({:ok, []}, &start_one/2)
    |> normalize()
  end

  @impl GenServer
  def init(fun) when is_function(fun, 1) do
    {:ok, %{fun: fun}}
  end

  @impl Cairn.Server
  def handle_msg(%Cairn.Message{from: from, payload: payload, ref: ref}, state) do
    Cairn.deliver(from, Cairn.Message.new(self(), call(state.fun, payload), ref))
    {:noreply, state}
  end

  @impl Cairn.Server
  def handle_task(_ref, _result, state) do
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

  @spec call(fun(), Cairn.Message.payload()) :: Cairn.Task.result()
  defp call(fun, payload) do
    {:ok, fun.(payload)}
  rescue
    exception ->
      {:error, exception}
  catch
    kind, reason ->
      {:error, {kind, reason}}
  end
end
