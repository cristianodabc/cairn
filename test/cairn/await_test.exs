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
end
