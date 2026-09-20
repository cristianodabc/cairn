defmodule Cairn.GroupTest do
  use ExUnit.Case, async: true

  test "runs many function servers in parallel" do
    {:ok, group} =
      Cairn.Group.start_link([
        fn value -> value * 2 end,
        fn value -> value + 10 end,
        fn value -> value |> Integer.to_string() end
      ])

    assert {:ok, replies} = Cairn.Group.call(group, 21)

    assert Enum.map(replies, & &1.payload) == [
             {:ok, 42},
             {:ok, 31},
             {:ok, "21"}
           ]
  end
end
