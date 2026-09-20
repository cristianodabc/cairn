defmodule Cairn.FunctionTest do
  use ExUnit.Case, async: true

  test "starts a function-backed server" do
    {:ok, pid} = Cairn.Function.start_link(fn value -> value * 2 end)

    msg = Cairn.dispatch(pid, 21)

    assert {:ok, %Cairn.Message{payload: {:ok, 42}}} =
             Cairn.Await.message(msg.ref)
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
