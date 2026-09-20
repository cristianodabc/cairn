defmodule Cairn.ServerTest do
  use ExUnit.Case, async: true

  defmodule PingServer do
    use Cairn.Server

    @impl GenServer
    def init(_arg) do
      {:ok, %{count: 0}}
    end

    @impl Cairn.Server
    def handle_msg(%Cairn.Message{payload: :ping, from: from}, state) do
      send(from, {:pong, self()})
      {:noreply, state}
    end

    def handle_msg(%Cairn.Message{payload: :increment}, state) do
      {:noreply, %{state | count: state.count + 1}}
    end
  end

  defmodule TokenServer do
    use Cairn.Server

    @impl GenServer
    def handle_info({:token, chunk}, test_pid) do
      send(test_pid, {:received, chunk})
      {:noreply, test_pid}
    end
  end

  defmodule TaskServer do
    use Cairn.Server

    @impl Cairn.Server
    def handle_msg(%Cairn.Message{payload: {:run, fun}, ref: ref}, test_pid) do
      {:ok, pid} = Cairn.Task.run(ref, fun)
      send(test_pid, {:task_started, ref, pid})
      {:noreply, test_pid}
    end

    @impl Cairn.Server
    def handle_task(ref, result, test_pid) do
      send(test_pid, {:task_result, ref, result})
      {:noreply, test_pid}
    end
  end

  test "routes Cairn messages to handle_msg/2" do
    {:ok, pid} = PingServer.start_link([])

    Cairn.deliver(pid, Cairn.Message.new(self(), :ping))

    assert_receive {:pong, ^pid}
  end

  test "allows custom handle_info/2 clauses" do
    {:ok, pid} = TokenServer.start_link(self())

    send(pid, {:token, "chunk"})

    assert_receive {:received, "chunk"}
  end

  test "handle_msg/2 can be tested without a process" do
    state = %{count: 0}
    msg = Cairn.Message.new(self(), :increment)

    assert {:noreply, %{count: 1}} =
             PingServer.handle_msg(msg, state)
  end

  test "server state is ordinary GenServer state" do
    {:ok, pid} = PingServer.start_link([])

    assert :sys.get_state(pid) == %{count: 0}

    Cairn.deliver(pid, Cairn.Message.new(self(), :increment))

    assert :sys.get_state(pid) == %{count: 1}
  end

  test "routes task success to handle_task/3" do
    {:ok, pid} = TaskServer.start_link(self())
    msg = Cairn.Message.new(self(), {:run, fn -> :done end}, :ok_ref)

    Cairn.deliver(pid, msg)

    assert_receive {:task_started, :ok_ref, task_pid}
    assert is_pid(task_pid)
    assert_receive {:task_result, :ok_ref, {:ok, :done}}
  end

  test "routes raised task exceptions to handle_task/3" do
    {:ok, pid} = TaskServer.start_link(self())
    msg = Cairn.Message.new(self(), {:run, fn -> raise "boom" end}, :error_ref)

    Cairn.deliver(pid, msg)

    assert_receive {:task_started, :error_ref, task_pid}
    assert is_pid(task_pid)
    assert_receive {:task_result, :error_ref, {:error, %RuntimeError{message: "boom"}}}
  end

  test "hard-killed tasks do not call handle_task/3" do
    {:ok, pid} = TaskServer.start_link(self())

    msg =
      Cairn.Message.new(
        self(),
        {:run,
         fn ->
           receive do
             :continue -> :done
           end
         end},
        :kill_ref
      )

    Cairn.deliver(pid, msg)

    assert_receive {:task_started, :kill_ref, task_pid}
    Process.exit(task_pid, :kill)

    refute_receive {:task_result, :kill_ref, _}, 100
  end

  test "stopping a server stops in-flight tasks" do
    {:ok, pid} = TaskServer.start_link(self())

    msg =
      Cairn.Message.new(
        self(),
        {:run,
         fn ->
           receive do
             :continue -> :done
           end
         end},
        :stop_ref
      )

    Cairn.deliver(pid, msg)

    assert_receive {:task_started, :stop_ref, task_pid}
    task_monitor = Process.monitor(task_pid)

    GenServer.stop(pid)

    assert_receive {:DOWN, ^task_monitor, :process, ^task_pid, _reason}
    refute_receive {:task_result, :stop_ref, _}, 100
  end

  test "Cairn.Task.run/2 raises outside a server callback" do
    assert_raise ArgumentError, ~r/Cairn.Server callback/, fn ->
      Cairn.Task.run(:ref, fn -> :done end)
    end
  end
end
