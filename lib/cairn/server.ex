defmodule Cairn.Server do
  @moduledoc false

  @task_supervisor_key {__MODULE__, :task_supervisor}
  @callback_key {__MODULE__, :callback}

  @type state :: term()
  @type reason :: term()
  @type callback_result :: {:noreply, state()} | {:stop, reason(), state()}

  @callback handle_msg(Cairn.Message.t(), state()) :: callback_result()
  @callback handle_task(Cairn.Message.ref(), Cairn.Task.result(), state()) :: callback_result()

  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer
      @behaviour Cairn.Server

      @before_compile Cairn.Server

      @impl GenServer
      def init(arg) do
        {:ok, arg}
      end

      @impl Cairn.Server
      def handle_msg(_msg, state) do
        {:noreply, state}
      end

      @impl Cairn.Server
      def handle_task(_ref, _result, state) do
        {:noreply, state}
      end

      @spec start_link(term()) :: GenServer.on_start()
      def start_link(arg) do
        GenServer.start_link(__MODULE__, arg)
      end

      @spec child_spec(term()) :: Supervisor.child_spec()
      def child_spec(arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [arg]},
          type: :worker
        }
      end

      @impl GenServer
      def handle_info(%Cairn.Message{} = msg, state) do
        Cairn.Server.__callback__(fn ->
          handle_msg(msg, state)
        end)
      end

      def handle_info({Cairn.Task, ref, result}, state) do
        Cairn.Server.__callback__(fn ->
          handle_task(ref, result, state)
        end)
      end

      @impl GenServer
      def terminate(_reason, _state) do
        Cairn.Server.__stop_task_supervisor__()
      end

      defoverridable init: 1,
                     handle_msg: 2,
                     handle_task: 3,
                     terminate: 2,
                     start_link: 1,
                     child_spec: 1
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @impl GenServer
      def handle_info(_msg, state) do
        {:noreply, state}
      end
    end
  end

  @spec __callback__((-> callback_result())) :: callback_result()
  def __callback__(fun) when is_function(fun, 0) do
    previous = Process.get(@callback_key)
    Process.put(@callback_key, true)

    try do
      fun.()
    after
      restore(@callback_key, previous)
    end
  end

  @spec __callback__?() :: boolean()
  def __callback__? do
    Process.get(@callback_key) == true
  end

  @spec __task_supervisor__() :: {:ok, pid()}
  def __task_supervisor__ do
    case Process.get(@task_supervisor_key) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          start_task_supervisor()
        end

      _ ->
        start_task_supervisor()
    end
  end

  @spec __stop_task_supervisor__() :: :ok
  def __stop_task_supervisor__ do
    case Process.get(@task_supervisor_key) do
      pid when is_pid(pid) ->
        Supervisor.stop(pid)
        Process.delete(@task_supervisor_key)
        :ok

      _ ->
        :ok
    end
  end

  @spec restore(term(), term()) :: term()
  defp restore(key, nil) do
    Process.delete(key)
  end

  defp restore(key, value) do
    Process.put(key, value)
  end

  @spec start_task_supervisor() :: {:ok, pid()}
  defp start_task_supervisor do
    case Task.Supervisor.start_link() do
      {:ok, pid} ->
        Process.put(@task_supervisor_key, pid)
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Process.put(@task_supervisor_key, pid)
        {:ok, pid}
    end
  end
end
