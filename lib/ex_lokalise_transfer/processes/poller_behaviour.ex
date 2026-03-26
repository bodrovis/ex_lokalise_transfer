defmodule ExLokaliseTransfer.Processes.PollerBehaviour do
  @moduledoc false

  alias ExLokaliseTransfer.Processes.Classifier
  alias ExLokaliseTransfer.Processes.Poller

  @type check_result :: Classifier.check_result()
  @type poll_opts :: Poller.poll_opts()
  @type result :: Poller.result()

  @callback check(String.t(), String.t()) :: check_result()
  @callback wait(String.t(), String.t(), poll_opts()) :: result()
end
