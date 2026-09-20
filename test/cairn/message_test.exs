defmodule Cairn.MessageTest do
  use ExUnit.Case, async: true

  alias Cairn.Message

  test "requires from and payload" do
    assert_raise ArgumentError, fn -> struct!(Message, payload: :hi) end
  end

  test "new/2 sets fields with a ref" do
    msg = Message.new(:someone, :hi)

    assert msg.from == :someone
    assert msg.payload == :hi
    assert is_reference(msg.ref)
  end

  test "new/3 accepts a ref" do
    assert Message.new(:someone, :hi, :ref42).ref == :ref42
  end

  test "reply/2 preserves the ref" do
    msg = Message.new(:someone, :hi, :ref42)

    assert Message.reply(msg, :ok) == Message.new(self(), :ok, :ref42)
  end
end
