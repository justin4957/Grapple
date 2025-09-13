defmodule GrappleTest do
  use ExUnit.Case
  doctest Grapple

  test "greets the world" do
    assert Grapple.hello() == :world
  end
end
