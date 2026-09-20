defmodule Cairn.AwaitTest do
  use ExUnit.Case, async: true

  test "returns a message matching the ref" do
    msg = Cairn.Message.new(self(), :done, :r1)
    send(self(), msg)

    assert Cairn.Await.message(:r1) == {:ok, msg}
  end

  test "ignores messages with another ref" do
    send(self(), Cairn.Message.new(self(), :other, :r1))

    assert Cairn.Await.message(:r2, 0) == {:error, :timeout}
  end

  test "returns timeout" do
    assert Cairn.Await.message(:missing, 0) == {:error, :timeout}
  end

  test "any returns the first matching message" do
    other = Cairn.Message.new(self(), :other, :other)
    msg = Cairn.Message.new(self(), :done, :r2)

    send(self(), other)
    send(self(), msg)

    assert Cairn.Await.any([:r1, :r2]) == {:ok, msg}
    assert_receive ^other
  end

  test "any returns timeout" do
    assert Cairn.Await.any([:missing], 0) == {:error, :timeout}
  end

  test "any returns timeout for no refs" do
    assert Cairn.Await.any([]) == {:error, :timeout}
  end

  test "all returns messages in ref order" do
    first = Cairn.Message.new(self(), :first, :r1)
    second = Cairn.Message.new(self(), :second, :r2)

    send(self(), second)
    send(self(), first)

    assert Cairn.Await.all([:r1, :r2]) == {:ok, [first, second]}
  end

  test "all handles a larger ref set" do
    refs = Enum.to_list(1..1_000)

    refs
    |> Enum.reverse()
    |> Enum.each(fn ref ->
      send(self(), Cairn.Message.new(self(), ref, ref))
    end)

    assert {:ok, replies} = Cairn.Await.all(refs)
    assert Enum.map(replies, & &1.payload) == refs
  end

  test "all returns timeout when one message is missing" do
    send(self(), Cairn.Message.new(self(), :done, :r1))

    assert Cairn.Await.all([:r1, :missing], 0) == {:error, :timeout}
  end

  test "all returns empty list for no refs" do
    assert Cairn.Await.all([]) == {:ok, []}
  end
end
