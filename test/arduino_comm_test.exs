defmodule ArduinoCommTest do
  use ExUnit.Case
  doctest ArduinoComm

  test "greets the world" do
    assert ArduinoComm.hello() == :world
  end
end
