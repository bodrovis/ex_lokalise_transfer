defmodule ExLokaliseTransfer.Processes.SleepBehaviour do
  @moduledoc false

  @callback sleep(non_neg_integer()) :: term()
end
