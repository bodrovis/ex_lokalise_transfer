defmodule ExLokaliseTransfer.Processes.BatchPollerTest do
  use ExLokaliseTransfer.Case, async: false

  setup {ExLokaliseTransfer.Case, :set_process_dependency_mocks}

  alias ElixirLokaliseApi.Model.QueuedProcess
  alias ExLokaliseTransfer.BackoffMock
  alias ExLokaliseTransfer.PollerMock
  alias ExLokaliseTransfer.Processes.BatchPoller
  alias ExLokaliseTransfer.SleepMock

  @project_id "proj_123"

  @poll_opts [
    max_attempts: 3,
    min_sleep_ms: 100,
    max_sleep_ms: 1_000,
    jitter: :centered
  ]

  describe "check_many/2" do
    test "returns results for multiple process ids in input order" do
      finished = queued_process("p1", "finished")
      pending = queued_process("p2", "in_progress")
      failed = queued_process("p3", "failed")

      responses = %{
        "p1" => {:ok, finished},
        "p2" => {:pending, pending},
        "p3" => {:error, {:process_failed, failed}}
      }

      expect(PollerMock, :check, 3, fn project_id, process_id ->
        assert project_id == @project_id
        Map.fetch!(responses, process_id)
      end)

      assert BatchPoller.check_many(@project_id, ["p1", "p2", "p3"]) == [
               {"p1", {:ok, finished}},
               {"p2", {:pending, pending}},
               {"p3", {:error, {:process_failed, failed}}}
             ]
    end

    test "isolates exceptions from one process and keeps others working" do
      finished = queued_process("p1", "finished")
      pending = queued_process("p3", "queued")

      expect(PollerMock, :check, 3, fn project_id, process_id ->
        assert project_id == @project_id

        case process_id do
          "p1" -> {:ok, finished}
          "p2" -> raise "boom"
          "p3" -> {:pending, pending}
        end
      end)

      assert BatchPoller.check_many(@project_id, ["p1", "p2", "p3"]) == [
               {"p1", {:ok, finished}},
               {"p2", {:error, {:exception, "boom"}}},
               {"p3", {:pending, pending}}
             ]
    end

    test "isolates thrown values from one process and keeps others working" do
      finished = queued_process("p1", "finished")

      expect(PollerMock, :check, 2, fn project_id, process_id ->
        assert project_id == @project_id

        case process_id do
          "p1" -> {:ok, finished}
          "p2" -> throw(:bad_thing)
        end
      end)

      assert BatchPoller.check_many(@project_id, ["p1", "p2"]) == [
               {"p1", {:ok, finished}},
               {"p2", {:error, {:throw, :bad_thing}}}
             ]
    end

    test "isolates exits from one process and keeps others working" do
      cancelled = queued_process("p2", "cancelled")

      expect(PollerMock, :check, 2, fn project_id, process_id ->
        assert project_id == @project_id

        case process_id do
          "p1" -> exit(:kaboom)
          "p2" -> {:error, {:process_cancelled, cancelled}}
        end
      end)

      assert BatchPoller.check_many(@project_id, ["p1", "p2"]) == [
               {"p1", {:error, {:exit, :kaboom}}},
               {"p2", {:error, {:process_cancelled, cancelled}}}
             ]
    end

    test "returns empty list for empty input" do
      assert BatchPoller.check_many(@project_id, []) == []
    end
  end

  describe "wait_many/3" do
    test "returns immediately when all processes are already finished" do
      p1 = queued_process("p1", "finished")
      p2 = queued_process("p2", "finished")

      responses = %{
        "p1" => {:ok, p1},
        "p2" => {:ok, p2}
      }

      expect(PollerMock, :check, 2, fn project_id, process_id ->
        assert project_id == @project_id
        Map.fetch!(responses, process_id)
      end)

      assert BatchPoller.wait_many(@project_id, ["p1", "p2"], @poll_opts) == [
               {"p1", {:ok, p1}},
               {"p2", {:ok, p2}}
             ]
    end

    test "keeps terminal results and continues polling only pending ones" do
      p1_finished = queued_process("p1", "finished")
      p2_pending = queued_process("p2", "queued")
      p2_finished = queued_process("p2", "finished")
      p3_failed = queued_process("p3", "failed")

      expect_check_sequence(@project_id, %{
        "p1" => [{:ok, p1_finished}],
        "p2" => [{:pending, p2_pending}, {:ok, p2_finished}],
        "p3" => [{:error, {:process_failed, p3_failed}}]
      })

      expect(BackoffMock, :backoff_ms, 1, fn 1, @poll_opts -> 111 end)
      expect(SleepMock, :sleep, 1, fn 111 -> :ok end)

      assert BatchPoller.wait_many(@project_id, ["p1", "p2", "p3"], @poll_opts) == [
               {"p1", {:ok, p1_finished}},
               {"p2", {:ok, p2_finished}},
               {"p3", {:error, {:process_failed, p3_failed}}}
             ]
    end

    test "returns timeout only for processes that remain pending at the limit" do
      p1_pending_1 = queued_process("p1", "queued")
      p1_pending_2 = queued_process("p1", "in_progress")
      p1_pending_3 = queued_process("p1", "running")
      p2_finished = queued_process("p2", "finished")

      opts = Keyword.put(@poll_opts, :max_attempts, 3)

      expect_check_sequence(@project_id, %{
        "p1" => [
          {:pending, p1_pending_1},
          {:pending, p1_pending_2},
          {:pending, p1_pending_3}
        ],
        "p2" => [
          {:ok, p2_finished}
        ]
      })

      expect(BackoffMock, :backoff_ms, 2, fn
        1, ^opts -> 111
        2, ^opts -> 222
      end)

      expect(SleepMock, :sleep, 2, fn
        111 -> :ok
        222 -> :ok
      end)

      assert BatchPoller.wait_many(@project_id, ["p1", "p2"], opts) == [
               {"p1", {:error, {:process_wait_timeout, "p1"}}},
               {"p2", {:ok, p2_finished}}
             ]
    end

    test "times out immediately on first pending round when max_attempts is 1" do
      pending = queued_process("p1", "queued")
      finished = queued_process("p2", "finished")
      opts = Keyword.put(@poll_opts, :max_attempts, 1)

      expect_check_sequence(@project_id, %{
        "p1" => [{:pending, pending}],
        "p2" => [{:ok, finished}]
      })

      assert BatchPoller.wait_many(@project_id, ["p1", "p2"], opts) == [
               {"p1", {:error, {:process_wait_timeout, "p1"}}},
               {"p2", {:ok, finished}}
             ]
    end

    test "deduplicates process ids and preserves first-seen order" do
      p1 = queued_process("p1", "finished")
      p2 = queued_process("p2", "finished")

      expect_check_sequence(@project_id, %{
        "p1" => [{:ok, p1}],
        "p2" => [{:ok, p2}]
      })

      assert BatchPoller.wait_many(@project_id, ["p1", "p2", "p1"], @poll_opts) == [
               {"p1", {:ok, p1}},
               {"p2", {:ok, p2}}
             ]
    end

    test "returns empty list for empty input" do
      assert BatchPoller.wait_many(@project_id, [], @poll_opts) == []
    end

    test "one crashing process does not break the batch" do
      p1 = queued_process("p1", "finished")
      p3 = queued_process("p3", "cancelled")

      expect(PollerMock, :check, 3, fn project_id, process_id ->
        assert project_id == @project_id

        case process_id do
          "p1" -> {:ok, p1}
          "p2" -> raise "bad process"
          "p3" -> {:error, {:process_cancelled, p3}}
        end
      end)

      assert BatchPoller.wait_many(@project_id, ["p1", "p2", "p3"], @poll_opts) == [
               {"p1", {:ok, p1}},
               {"p2", {:error, {:exception, "bad process"}}},
               {"p3", {:error, {:process_cancelled, p3}}}
             ]
    end

    test "keeps unexpected process status as terminal error result" do
      weird = queued_process("p1", "mystery_status")

      expect(PollerMock, :check, 1, fn project_id, process_id ->
        assert project_id == @project_id
        assert process_id == "p1"

        {:error, {:unexpected_process_status, "mystery_status", weird}}
      end)

      assert BatchPoller.wait_many(@project_id, ["p1"], @poll_opts) == [
               {"p1", {:error, {:unexpected_process_status, "mystery_status", weird}}}
             ]
    end
  end

  defp expect_check_sequence(project_id, scripted_results) do
    {:ok, agent} = Agent.start_link(fn -> scripted_results end)

    total_calls =
      scripted_results
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.sum()

    expect(PollerMock, :check, total_calls, fn actual_project_id, process_id ->
      assert actual_project_id == project_id

      Agent.get_and_update(agent, fn state ->
        case Map.fetch!(state, process_id) do
          [next | rest] ->
            {next, Map.put(state, process_id, rest)}

          [] ->
            raise "no scripted result left for process_id=#{inspect(process_id)}"
        end
      end)
    end)
  end

  defp queued_process(process_id, status) do
    struct!(
      QueuedProcess,
      process_id: process_id,
      type: "file-upload",
      status: status,
      message: nil,
      created_by: "user_123",
      created_by_email: "test@example.com",
      created_at: "2026-03-26 12:00:00 (Etc/UTC)",
      created_at_timestamp: "2026-03-26T12:00:00Z",
      details: %{}
    )
  end
end
