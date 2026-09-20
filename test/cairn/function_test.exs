defmodule Cairn.FunctionTest do
  use ExUnit.Case, async: true

  test "starts a function-backed server" do
    {:ok, pid} = Cairn.Function.start_link(fn value -> value * 2 end)

    msg = Cairn.dispatch(pid, 21)

    assert {:ok, %Cairn.Message{payload: {:ok, 42}}} =
             Cairn.Await.message(msg.ref)
  end

  test "starts a named function-backed server" do
    start_supervised!({Registry, keys: :unique, name: __MODULE__.Reg})
    name = {:via, Registry, {__MODULE__.Reg, :double}}

    {:ok, _pid} = Cairn.Function.start_link(fn value -> value * 2 end, name: name)

    msg = Cairn.dispatch(name, 21)

    assert {:ok, %Cairn.Message{payload: {:ok, 42}}} =
             Cairn.Await.message(msg.ref)
  end

  test "starts function-backed servers under a supervisor" do
    children = [
      {Cairn.Function, {:double, fn value -> value * 2 end}},
      {Cairn.Function, {:plus_ten, fn value -> value + 10 end}}
    ]

    supervisor =
      start_supervised!(%{
        id: :function_supervisor,
        start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
      })

    pids =
      supervisor
      |> Supervisor.which_children()
      |> Enum.map(fn {_id, pid, :worker, [Cairn.Function]} -> pid end)

    refs =
      pids
      |> Cairn.dispatch(21)
      |> Enum.map(& &1.ref)

    assert {:ok, replies} = Cairn.Await.all(refs)
    assert Enum.sort(Enum.map(replies, & &1.payload)) == [{:ok, 31}, {:ok, 42}]
  end

  test "starts named function-backed server under a supervisor" do
    start_supervised!({Registry, keys: :unique, name: __MODULE__.NamedReg})
    name = {:via, Registry, {__MODULE__.NamedReg, :double}}

    child = {Cairn.Function, {:double, fn value -> value * 2 end, name: name}}

    start_supervised!(%{
      id: :named_function_supervisor,
      start: {Supervisor, :start_link, [[child], [strategy: :one_for_one]]}
    })

    msg = Cairn.dispatch(name, 21)

    assert {:ok, %Cairn.Message{payload: {:ok, 42}}} =
             Cairn.Await.message(msg.ref)
  end

  test "function-backed server does not start an extra task supervisor" do
    {:ok, pid} = Cairn.Function.start_link(fn value -> value * 2 end)

    msg = Cairn.dispatch(pid, 21)

    assert {:ok, %Cairn.Message{payload: {:ok, 42}}} =
             Cairn.Await.message(msg.ref)

    {:dictionary, dictionary} = Process.info(pid, :dictionary)

    refute Enum.any?(dictionary, fn {key, _value} ->
             key == {Cairn.Server, :task_supervisor}
           end)
  end

  test "function-backed server catches exits and throws" do
    {:ok, exit_pid} = Cairn.Function.start_link(fn _value -> exit(:boom) end)
    {:ok, throw_pid} = Cairn.Function.start_link(fn _value -> throw(:boom) end)

    exit_msg = Cairn.dispatch(exit_pid, :run)
    throw_msg = Cairn.dispatch(throw_pid, :run)

    assert {:ok, %Cairn.Message{payload: {:error, {:exit, :boom}}}} =
             Cairn.Await.message(exit_msg.ref)

    assert {:ok, %Cairn.Message{payload: {:error, {:throw, :boom}}}} =
             Cairn.Await.message(throw_msg.ref)
  end

  test "starts many function-backed servers" do
    {:ok, pids} =
      Cairn.Function.start_many([
        fn value -> value * 2 end,
        fn value -> value + 10 end,
        fn value -> value |> Integer.to_string() end
      ])

    refs =
      pids
      |> Cairn.dispatch(21)
      |> Enum.map(& &1.ref)

    assert {:ok, replies} = Cairn.Await.all(refs)

    assert Enum.map(replies, & &1.payload) == [
             {:ok, 42},
             {:ok, 31},
             {:ok, "21"}
           ]
  end
end
