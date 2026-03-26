defmodule ExLokaliseTransfer.Processes.QueuedProcessesClient do
  @moduledoc false

  alias ExLokaliseTransfer.Processes.Classifier

  @type queued_process :: Classifier.queued_process()

  @callback find(String.t(), String.t()) ::
              {:ok, queued_process()} | {:error, term()}
end
