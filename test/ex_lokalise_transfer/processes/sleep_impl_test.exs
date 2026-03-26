defmodule ExLokaliseTransfer.Processes.SleepImplTest do
  use ExUnit.Case, async: true

  alias ExLokaliseTransfer.Processes.SleepImpl

  test "sleep/1 does not crash" do
    assert SleepImpl.sleep(0) == :ok
  end
end
