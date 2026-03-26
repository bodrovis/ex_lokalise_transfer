defmodule ExLokaliseTransfer.Processes.SleepImpl do
  @moduledoc false

  @behaviour ExLokaliseTransfer.Processes.SleepBehaviour

  @impl true
  def sleep(ms), do: Process.sleep(ms)
end
