defmodule ExLokaliseTransfer.Processes.ClassifierTest do
  use ExLokaliseTransfer.Case, async: true

  alias ElixirLokaliseApi.Model.QueuedProcess
  alias ExLokaliseTransfer.Processes.Classifier

  describe "classify/1 – finished process" do
    test "returns {:ok, process} for finished status" do
      process = queued_process(status: "finished")

      assert {:ok, ^process} = Classifier.classify(process)
    end
  end

  describe "classify/1 – failed process" do
    test "returns process_failed error for failed status" do
      process = queued_process(status: "failed")

      assert {:error, {:process_failed, ^process}} = Classifier.classify(process)
    end
  end

  describe "classify/1 – cancelled process" do
    test "returns process_cancelled error for cancelled status" do
      process = queued_process(status: "cancelled")

      assert {:error, {:process_cancelled, ^process}} = Classifier.classify(process)
    end
  end

  describe "classify/1 – pending statuses" do
    test "returns {:pending, process} for in_progress status" do
      process = queued_process(status: "in_progress")

      assert {:pending, ^process} = Classifier.classify(process)
    end

    test "returns {:pending, process} for queued status" do
      process = queued_process(status: "queued")

      assert {:pending, ^process} = Classifier.classify(process)
    end

    test "returns {:pending, process} for any non-empty binary status other than terminal ones" do
      process = queued_process(status: "whatever_lokalise_returns")

      assert {:pending, ^process} = Classifier.classify(process)
    end
  end

  describe "classify/1 – unexpected statuses" do
    test "returns unexpected_process_status for nil status" do
      process = queued_process(status: nil)

      assert {:error, {:unexpected_process_status, nil, ^process}} =
               Classifier.classify(process)
    end

    test "returns unexpected_process_status for empty string status" do
      process = queued_process(status: "")

      assert {:error, {:unexpected_process_status, "", ^process}} =
               Classifier.classify(process)
    end

    test "returns unexpected_process_status for non-binary status" do
      process = queued_process(status: :queued)

      assert {:error, {:unexpected_process_status, :queued, ^process}} =
               Classifier.classify(process)
    end
  end

  defp queued_process(overrides) do
    struct!(
      QueuedProcess,
      Keyword.merge(
        [
          process_id: "proc_123",
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
