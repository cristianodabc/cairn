defmodule CairnTest do
  use ExUnit.Case, async: true

  test "delivers a Message to a pid untouched" do
    msg = Cairn.Message.new(self(), :hello, :r1)
    :ok = Cairn.deliver(self(), msg)

    assert_receive ^msg
  end

  test "delivers to a registered name" do
    msg = Cairn.Message.new(self(), :hello)
    test_process = self()

    {:ok, _} =
      Task.start(fn ->
        Process.register(self(), :cairn_deliver_test_named)
        send(test_process, :ready)
        assert_receive ^msg
      end)

    assert_receive :ready
    :ok = Cairn.deliver(:cairn_deliver_test_named, msg)
  end

  test "delivers via a via-tuple registry entry" do
    start_supervised!({Registry, keys: :unique, name: __MODULE__.Reg})
    msg = Cairn.Message.new(self(), :hello)

    {:ok, _} = Registry.register(__MODULE__.Reg, :writer, self())
    :ok = Cairn.deliver({:via, Registry, {__MODULE__.Reg, :writer}}, msg)

    assert_receive ^msg
  end

  test "raises on an unregistered via-tuple destination" do
    start_supervised!({Registry, keys: :unique, name: __MODULE__.Reg})
    msg = Cairn.Message.new(self(), :hello)

    assert_raise ArgumentError, ~r/unknown destination/, fn ->
      Cairn.deliver({:via, Registry, {__MODULE__.Reg, :nobody}}, msg)
    end
  end

  test "raises on an unregistered global name" do
    msg = Cairn.Message.new(self(), :hello)

    assert_raise ArgumentError, ~r/unknown destination/, fn ->
      Cairn.deliver({:global, :cairn_no_such_global}, msg)
    end
  end
end
