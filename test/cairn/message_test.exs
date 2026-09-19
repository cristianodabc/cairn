defmodule Cairn.MessageTest do
  use ExUnit.Case, async: true

  alias Cairn.Message

  test "requires from and payload" do
    assert_raise ArgumentError, fn -> struct!(Message, payload: :hi) end
  end

  test "new/3 sets fields with ref defaulting to nil" do
    msg = Message.new(:someone, :hi)
    assert msg.from == :someone
    assert msg.payload == :hi
    assert msg.ref == nil
  end

  test "new/3 accepts a ref" do
    assert Message.new(:someone, :hi, :ref42).ref == :ref42
  end
end
