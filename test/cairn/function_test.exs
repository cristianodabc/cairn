defmodule Cairn.FunctionTest do
  use ExUnit.Case, async: true

  test "starts a function-backed server" do
    {:ok, pid} = Cairn.Function.start_link(fn value -> value * 2 end)

    msg = Cairn.dispatch(pid, 21)

    assert {:ok, %Cairn.Message{payload: {:ok, 42}}} =
             Cairn.Await.message(msg.ref)
  end
end
