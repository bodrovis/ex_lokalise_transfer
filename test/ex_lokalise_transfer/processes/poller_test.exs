defmodule ExLokaliseTransfer.Processes.PollerTest do
  use ExLokaliseTransfer.Case, async: false

  alias ElixirLokaliseApi.Model.QueuedProcess
  alias ExLokaliseTransfer.BackoffMock
  alias ExLokaliseTransfer.Processes.Poller
  alias ExLokaliseTransfer.QueuedProcessesClientMock
  alias ExLokaliseTransfer.SleepMock

  setup {ExLokaliseTransfer.Case, :set_process_dependency_mocks}

  @project_id "proj_123"
  @process_id "proc_123"

  @poll_opts [
    max_attempts: 3,
    min_sleep_ms: 100,
    max_sleep_ms: 1_000,
    jitter: :centered
  ]

  describe "find/2" do
    test "delegates to queued processes client" do
      process = queued_process(status: "finished")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, process}
      end)

      assert {:ok, ^process} = Poller.find(@project_id, @process_id)
    end

    test "returns client error as-is" do
      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Poller.find(@project_id, @process_id)
    end
  end

  describe "check/2" do
    test "returns {:ok, process} when process is finished" do
      process = queued_process(status: "finished")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, process}
      end)

      assert {:ok, ^process} = Poller.check(@project_id, @process_id)
    end

    test "returns {:pending, process} when process is still running" do
      process = queued_process(status: "in_progress")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, process}
      end)

      assert {:pending, ^process} = Poller.check(@project_id, @process_id)
    end

    test "returns process_failed error when process failed" do
      process = queued_process(status: "failed")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, process}
      end)

      assert {:error, {:process_failed, ^process}} =
               Poller.check(@project_id, @process_id)
    end

    test "returns process_cancelled error when process was cancelled" do
      process = queued_process(status: "cancelled")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, process}
      end)

      assert {:error, {:process_cancelled, ^process}} =
               Poller.check(@project_id, @process_id)
    end

    test "returns unexpected_process_status for invalid status" do
      process = queued_process(status: nil)

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, process}
      end)

      assert {:error, {:unexpected_process_status, nil, ^process}} =
               Poller.check(@project_id, @process_id)
    end

    test "returns client error as-is" do
      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:error, :upstream_error}
      end)

      assert {:error, :upstream_error} = Poller.check(@project_id, @process_id)
    end
  end

  describe "wait/3" do
    test "returns immediately when process is already finished" do
      process = queued_process(status: "finished")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, process}
      end)

      assert {:ok, ^process} = Poller.wait(@project_id, @process_id, @poll_opts)
    end

    test "polls until process finishes" do
      pending_1 = queued_process(status: "queued")
      pending_2 = queued_process(status: "in_progress")
      finished = queued_process(status: "finished")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, pending_1}
      end)

      expect(BackoffMock, :backoff_ms, fn 1, @poll_opts ->
        111
      end)

      expect(SleepMock, :sleep, fn 111 ->
        :ok
      end)

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, pending_2}
      end)

      expect(BackoffMock, :backoff_ms, fn 2, @poll_opts ->
        222
      end)

      expect(SleepMock, :sleep, fn 222 ->
        :ok
      end)

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, finished}
      end)

      assert {:ok, ^finished} = Poller.wait(@project_id, @process_id, @poll_opts)
    end

    test "returns timeout when process stays pending until max_attempts" do
      pending_1 = queued_process(status: "queued")
      pending_2 = queued_process(status: "in_progress")
      pending_3 = queued_process(status: "running")

      opts = Keyword.put(@poll_opts, :max_attempts, 3)

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, pending_1}
      end)

      expect(BackoffMock, :backoff_ms, fn 1, ^opts ->
        111
      end)

      expect(SleepMock, :sleep, fn 111 ->
        :ok
      end)

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, pending_2}
      end)

      expect(BackoffMock, :backoff_ms, fn 2, ^opts ->
        222
      end)

      expect(SleepMock, :sleep, fn 222 ->
        :ok
      end)

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, pending_3}
      end)

      assert {:error, {:process_wait_timeout, @process_id}} =
               Poller.wait(@project_id, @process_id, opts)
    end

    test "times out immediately on first pending result when max_attempts is 1" do
      pending = queued_process(status: "queued")
      opts = Keyword.put(@poll_opts, :max_attempts, 1)

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, pending}
      end)

      assert {:error, {:process_wait_timeout, @process_id}} =
               Poller.wait(@project_id, @process_id, opts)
    end

    test "returns process_failed error without sleeping" do
      failed = queued_process(status: "failed")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, failed}
      end)

      assert {:error, {:process_failed, ^failed}} =
               Poller.wait(@project_id, @process_id, @poll_opts)
    end

    test "returns process_cancelled error without sleeping" do
      cancelled = queued_process(status: "cancelled")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, cancelled}
      end)

      assert {:error, {:process_cancelled, ^cancelled}} =
               Poller.wait(@project_id, @process_id, @poll_opts)
    end

    test "returns unexpected_process_status without sleeping" do
      invalid = queued_process(status: "")

      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:ok, invalid}
      end)

      assert {:error, {:unexpected_process_status, "", ^invalid}} =
               Poller.wait(@project_id, @process_id, @poll_opts)
    end

    test "returns client error without retrying" do
      expect(QueuedProcessesClientMock, :find, fn @project_id, @process_id ->
        {:error, :api_down}
      end)

      assert {:error, :api_down} = Poller.wait(@project_id, @process_id, @poll_opts)
    end
  end

  defp queued_process(overrides) do
    struct!(
      QueuedProcess,
      Keyword.merge(
        [
          process_id: @process_id,
          type: "file-upload",
          status: "queued",
          message: nil,
          created_by: "user_123",
          created_by_email: "test@example.com",
          created_at: "2026-03-26 12:00:00 (Etc/UTC)",
          created_at_timestamp: "2026-03-26T12:00:00Z",
          details: %{}
        ],
        overrides
      )
    )
  end
end
