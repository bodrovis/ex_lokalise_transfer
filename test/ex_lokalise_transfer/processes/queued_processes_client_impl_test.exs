defmodule ExLokaliseTransfer.Processes.QueuedProcessesClientImplTest do
  use ExLokaliseTransfer.Case, async: true

  setup {ExLokaliseTransfer.Case, :set_queued_processes_impl_mocks}

  alias ExLokaliseTransfer.Processes.QueuedProcessesClientImpl
  alias ExLokaliseTransfer.QueuedProcessesSdkMock

  import Mox

  test "find delegates to sdk" do
    expect(QueuedProcessesSdkMock, :find, fn "proj", "proc" ->
      {:ok, %{id: "proc"}}
    end)

    assert {:ok, %{id: "proc"}} =
             QueuedProcessesClientImpl.find("proj", "proc")
  end
end
