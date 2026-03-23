defmodule ExLokaliseTransfer.Processes.Poller do
  @moduledoc """
  Polls Lokalise queued processes until they reach a terminal status.

  This module is generic and does not interpret process-specific details.
  It simply waits until the queued process is finished, failed, or cancelled.

  Success:
    - `"finished"`  -> returns the full `%QueuedProcess{}`

  Failure:
    - `"failed"`    -> returns `{:error, {:process_failed, process}}`
    - `"cancelled"` -> returns `{:error, {:process_cancelled, process}}`

  Any other non-empty binary status is treated as pending.
  """

  require Logger

  alias ElixirLokaliseApi.Model.QueuedProcess
  alias ElixirLokaliseApi.QueuedProcesses
  alias ExLokaliseTransfer.Backoff

  @max_concurrency 6

  @type jitter_mode :: :full | :centered

  @type poll_opts :: [
          max_attempts: pos_integer(),
          min_sleep_ms: non_neg_integer(),
          max_sleep_ms: non_neg_integer(),
          jitter: jitter_mode()
        ]

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
          | {:error, term()}

  @type result ::
          {:ok, queued_process()}
          | {:error, {:process_failed, queued_process()}}
          | {:error, {:process_cancelled, queued_process()}}
          | {:error, {:process_wait_timeout, String.t()}}
          | {:error, {:unexpected_process_status, term(), term()}}
          | {:error, term()}

  @type many_check_result :: [{String.t(), check_result()}]
  @type many_result :: [{String.t(), result()}]

  @doc """
  Fetches a single queued process from Lokalise.
  """
  @spec find(String.t(), String.t()) :: {:ok, queued_process()} | {:error, term()}
  def find(project_id, process_id)
      when is_binary(project_id) and is_binary(process_id) do
    QueuedProcesses.find(project_id, process_id)
  end

  @doc """
  Checks a single queued process once.

  Returns:
    - `{:ok, process}` when finished
    - `{:pending, process}` when still running/queued/etc.
    - `{:error, reason}` for terminal failure or invalid response
  """
  @spec check(String.t(), String.t()) :: check_result()
  def check(project_id, process_id)
      when is_binary(project_id) and is_binary(process_id) do
    case find(project_id, process_id) do
      {:ok, %QueuedProcess{} = process} ->
        classify_process(process)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks multiple queued processes in parallel.

  The requests are executed with a maximum concurrency of #{@max_concurrency}.

  A failure for one process does not stop checks for the others.
  """
  @spec check_many(String.t(), [String.t()]) :: many_check_result()
  def check_many(project_id, process_ids)
      when is_binary(project_id) and is_list(process_ids) do
    process_ids
    |> Task.async_stream(
      fn process_id ->
        {process_id, safe_check(project_id, process_id)}
      end,
      max_concurrency: @max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, {process_id, result}} ->
        {process_id, result}
    end)
  end

  @doc """
  Waits until the queued process reaches a terminal status.

  Returns the full `%QueuedProcess{}` on success.
  """
  @spec wait(String.t(), String.t(), poll_opts()) :: result()
  def wait(project_id, process_id, opts)
      when is_binary(project_id) and is_binary(process_id) and is_list(opts) do
    max_attempts = Keyword.fetch!(opts, :max_attempts)
    do_wait(project_id, process_id, opts, 1, max_attempts)
  end

  @doc """
  Waits for multiple queued processes until each reaches a terminal status.

  Processes are checked in parallel on each polling round. Finished and failed
  processes are removed from subsequent rounds; only still-pending process IDs
  are checked again.

  A failure for one process does not stop waiting for the others.
  """
  @spec wait_many(String.t(), [String.t()], poll_opts()) :: many_result()
  def wait_many(project_id, process_ids, opts)
      when is_binary(project_id) and is_list(process_ids) and is_list(opts) do
    max_attempts = Keyword.fetch!(opts, :max_attempts)
    uniq_ids = Enum.uniq(process_ids)

    results_map =
      do_wait_many(uniq_ids, project_id, opts, 1, max_attempts, %{})

    Enum.map(uniq_ids, fn process_id ->
      {process_id, Map.fetch!(results_map, process_id)}
    end)
  end

  defp do_wait(project_id, process_id, opts, attempt_idx, max_attempts) do
    case check(project_id, process_id) do
      {:ok, %QueuedProcess{} = process} ->
        {:ok, process}

      {:pending, _process} when attempt_idx >= max_attempts ->
        {:error, {:process_wait_timeout, process_id}}

      {:pending, process} ->
        sleep_ms = Backoff.backoff_ms(attempt_idx, opts)

        Logger.debug("polling queued process",
          process_id: process_id,
          status: process.status,
          attempt: attempt_idx,
          max_attempts: max_attempts,
          next_check_in_ms: sleep_ms
        )

        Process.sleep(sleep_ms)

        do_wait(project_id, process_id, opts, attempt_idx + 1, max_attempts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_wait_many([], _project_id, _opts, _attempt_idx, _max_attempts, acc) do
    acc
  end

  defp do_wait_many(process_ids, project_id, _opts, attempt_idx, max_attempts, acc)
       when attempt_idx >= max_attempts do
    round_results = check_many(project_id, process_ids)
    {done_map, pending_ids} = partition_many_results(round_results)

    timeout_map =
      Map.new(pending_ids, fn process_id ->
        {process_id, {:error, {:process_wait_timeout, process_id}}}
      end)

    acc
    |> Map.merge(done_map)
    |> Map.merge(timeout_map)
  end

  defp do_wait_many(process_ids, project_id, opts, attempt_idx, max_attempts, acc) do
    round_results = check_many(project_id, process_ids)
    {done_map, pending_ids} = partition_many_results(round_results)

    acc = Map.merge(acc, done_map)

    if pending_ids == [] do
      acc
    else
      sleep_ms = Backoff.backoff_ms(attempt_idx, opts)

      Logger.debug("polling queued processes batch",
        pending_count: length(pending_ids),
        attempt: attempt_idx,
        max_attempts: max_attempts,
        next_check_in_ms: sleep_ms
      )

      Process.sleep(sleep_ms)

      do_wait_many(
        pending_ids,
        project_id,
        opts,
        attempt_idx + 1,
        max_attempts,
        acc
      )
    end
  end

  defp partition_many_results(results) do
    Enum.reduce(results, {%{}, []}, fn
      {process_id, {:pending, %QueuedProcess{} = process}}, {done_map, pending_ids} ->
        Logger.debug("queued process still pending",
          process_id: process_id,
          status: process.status
        )

        {done_map, [process_id | pending_ids]}

      {process_id, result}, {done_map, pending_ids} ->
        {Map.put(done_map, process_id, normalize_many_result(process_id, result)), pending_ids}
    end)
    |> then(fn {done_map, pending_ids} ->
      {done_map, Enum.reverse(pending_ids)}
    end)
  end

  defp normalize_many_result(_process_id, {:ok, %QueuedProcess{} = process}) do
    {:ok, process}
  end

  defp normalize_many_result(_process_id, {:error, {:process_failed, %QueuedProcess{} = process}}) do
    {:error, {:process_failed, process}}
  end

  defp normalize_many_result(
         _process_id,
         {:error, {:process_cancelled, %QueuedProcess{} = process}}
       ) do
    {:error, {:process_cancelled, process}}
  end

  defp normalize_many_result(
         _process_id,
         {:error, {:unexpected_process_status, status, process}}
       ) do
    {:error, {:unexpected_process_status, status, process}}
  end

  defp normalize_many_result(_process_id, {:error, reason}) do
    {:error, reason}
  end

  defp classify_process(%QueuedProcess{status: "finished"} = process) do
    {:ok, process}
  end

  defp classify_process(%QueuedProcess{status: "failed"} = process) do
    {:error, {:process_failed, process}}
  end

  defp classify_process(%QueuedProcess{status: "cancelled"} = process) do
    {:error, {:process_cancelled, process}}
  end

  defp classify_process(%QueuedProcess{status: status} = process)
       when is_binary(status) and status != "" do
    {:pending, process}
  end

  defp classify_process(%QueuedProcess{status: status} = process) do
    {:error, {:unexpected_process_status, status, process}}
  end

  defp safe_check(project_id, process_id) do
    try do
      check(project_id, process_id)
    rescue
      e ->
        {:error, {:exception, Exception.message(e)}}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end
end
