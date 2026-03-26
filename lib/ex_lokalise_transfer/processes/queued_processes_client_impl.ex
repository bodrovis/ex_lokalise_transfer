defmodule ExLokaliseTransfer.Processes.QueuedProcessesClientImpl do
  @moduledoc false

  @behaviour ExLokaliseTransfer.Processes.QueuedProcessesClient

  alias ElixirLokaliseApi.QueuedProcesses

  @impl true
  def find(project_id, process_id) do
    QueuedProcesses.find(project_id, process_id)
  end
end
