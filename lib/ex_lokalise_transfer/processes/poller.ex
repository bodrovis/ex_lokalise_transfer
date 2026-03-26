defmodule ExLokaliseTransfer.Processes.Poller do
  @moduledoc """
  Polls a single Lokalise queued process until it reaches a terminal status.
  """

  @behaviour ExLokaliseTransfer.Processes.PollerBehaviour

  require Logger

  alias ElixirLokaliseApi.Model.QueuedProcess
  alias ExLokaliseTransfer.Processes.Classifier

  @type queued_process :: Classifier.queued_process()
  @type check_result :: Classifier.check_result()

  @type jitter_mode :: :full | :centered

  @type poll_opts :: [
          max_attempts: pos_integer(),
          min_sleep_ms: non_neg_integer(),
          max_sleep_ms: non_neg_integer(),
          jitter: jitter_mode()
        ]

  @type result ::
          {:ok, queued_process()}
          | {:error, {:process_failed, queued_process()}}
          | {:error, {:process_cancelled, queued_process()}}
          | {:error, {:process_wait_timeout, String.t()}}
          | {:error, {:unexpected_process_status, term(), term()}}
          | {:error, term()}

  @spec find(String.t(), String.t()) :: {:ok, queued_process()} | {:error, term()}
  def find(project_id, process_id)
      when is_binary(project_id) and is_binary(process_id) do
    queued_processes_client().find(project_id, process_id)
  end

  @spec check(String.t(), String.t()) :: check_result()
  def check(project_id, process_id)
      when is_binary(project_id) and is_binary(process_id) do
    case find(project_id, process_id) do
      {:ok, %QueuedProcess{} = process} ->
        Classifier.classify(process)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec wait(String.t(), String.t(), poll_opts()) :: result()
  def wait(project_id, process_id, opts)
      when is_binary(project_id) and is_binary(process_id) and is_list(opts) do
    max_attempts = Keyword.fetch!(opts, :max_attempts)
    do_wait(project_id, process_id, opts, 1, max_attempts)
  end

  defp do_wait(project_id, process_id, opts, attempt_idx, max_attempts) do
    case check(project_id, process_id) do
      {:ok, %QueuedProcess{} = process} ->
        {:ok, process}

      {:pending, _process} when attempt_idx >= max_attempts ->
        {:error, {:process_wait_timeout, process_id}}

      {:pending, process} ->
        sleep_ms = backoff_module().backoff_ms(attempt_idx, opts)

        Logger.debug("polling queued process",
          process_id: process_id,
          status: process.status,
          attempt: attempt_idx,
          max_attempts: max_attempts,
          next_check_in_ms: sleep_ms
        )

        sleep_module().sleep(sleep_ms)

        do_wait(project_id, process_id, opts, attempt_idx + 1, max_attempts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp queued_processes_client do
    Application.get_env(
      :ex_lokalise_transfer,
      :queued_processes_client,
      ExLokaliseTransfer.Processes.QueuedProcessesClientImpl
    )
  end

  defp backoff_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :backoff_module,
      ExLokaliseTransfer.Helpers.Backoff
    )
  end

  defp sleep_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :sleep_module,
      ExLokaliseTransfer.Processes.SleepImpl
    )
  end
end
