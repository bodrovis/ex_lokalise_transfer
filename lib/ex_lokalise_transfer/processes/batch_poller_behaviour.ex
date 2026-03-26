defmodule ExLokaliseTransfer.Processes.BatchPollerBehaviour do
  @moduledoc false

  alias ExLokaliseTransfer.Processes.Poller

  @type poll_opts :: Poller.poll_opts()
  @type result :: Poller.result()

  @callback wait_many(String.t(), [String.t()], poll_opts()) ::
              [{String.t(), result()}]
end
