defmodule ExLokaliseTransfer.Processes.QueuedProcessesClientImpl do
  @moduledoc false

  @behaviour ExLokaliseTransfer.Processes.QueuedProcessesClient

  @impl true
  def find(project_id, process_id) do
    queued_processes_module().find(project_id, process_id)
  end

  defp queued_processes_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :queued_processes_sdk_module,
      ElixirLokaliseApi.QueuedProcesses
    )
  end
end
