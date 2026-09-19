defmodule CairnTest do
  use ExUnit.Case
  doctest Cairn

  test "greets the world" do
    assert Cairn.hello() == :world
  end
end
