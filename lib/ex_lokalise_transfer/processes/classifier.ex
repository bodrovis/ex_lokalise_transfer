defmodule ExLokaliseTransfer.Processes.Classifier do
  @moduledoc false

  alias ElixirLokaliseApi.Model.QueuedProcess

  @type queued_process :: %QueuedProcess{
          process_id: term(),
          type: term(),
          status: term(),
          message: term(),
          created_by: term(),
          created_by_email: term(),
          created_at: term(),
          created_at_timestamp: term(),
          details: term()
        }

  @type check_result ::
          {:ok, queued_process()}
          | {:pending, queued_process()}
          | {:error, {:process_failed, queued_process()}}
          | {:error, {:process_cancelled, queued_process()}}
          | {:error, {:unexpected_process_status, term(), term()}}

  @spec classify(queued_process()) :: check_result()
  def classify(%QueuedProcess{status: "finished"} = process) do
    {:ok, process}
  end

  def classify(%QueuedProcess{status: "failed"} = process) do
    {:error, {:process_failed, process}}
  end

  def classify(%QueuedProcess{status: "cancelled"} = process) do
    {:error, {:process_cancelled, process}}
  end

  def classify(%QueuedProcess{status: status} = process) when is_binary(status) and status != "" do
    {:pending, process}
  end

  def classify(%QueuedProcess{status: status} = process) do
    {:error, {:unexpected_process_status, status, process}}
  end
end
