defmodule Cairn.AgentTest do
  use ExUnit.Case, async: true

  defmodule PingAgent do
    use Cairn.Agent

    @impl GenServer
    def init(_), do: {:ok, %{count: 0}}

    @impl Cairn.Agent
    def handle_message(%Cairn.Message{payload: :ping, from: from}, state) do
      send(from, {:pong, self()})
      {:noreply, state}
    end

    def handle_message(%Cairn.Message{payload: :increment}, state) do
      {:noreply, %{state | count: state.count + 1}}
    end
  end

  defmodule TokenAgent do
    use Cairn.Agent

    @impl GenServer
    def handle_info({:token, chunk}, test_pid) do
      send(test_pid, {:received, chunk})
      {:noreply, test_pid}
    end
  end

  test "routes Cairn messages to handle_message/2" do
    {:ok, pid} = PingAgent.start_link([])

    Cairn.deliver(pid, Cairn.Message.new(self(), :ping))

    assert_receive {:pong, ^pid}
  end

  test "allows custom handle_info/2 clauses" do
    {:ok, pid} = TokenAgent.start_link(self())

    send(pid, {:token, "chunk"})

    assert_receive {:received, "chunk"}
  end

  test "handle_message/2 can be tested without a process" do
    state = %{count: 0}
    msg = Cairn.Message.new(self(), :increment)

    assert {:noreply, %{count: 1}} =
             PingAgent.handle_message(msg, state)
  end

  test "agent state is ordinary GenServer state" do
    {:ok, pid} = PingAgent.start_link([])

    assert :sys.get_state(pid) == %{count: 0}

    Cairn.deliver(pid, Cairn.Message.new(self(), :increment))

    assert :sys.get_state(pid) == %{count: 1}
  end
end
