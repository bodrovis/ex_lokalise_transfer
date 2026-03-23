defmodule ExLokaliseTransfer.Processes.BatchPoller do
  @moduledoc """
  Polls multiple Lokalise queued processes in parallel until each reaches
  a terminal status.
  """

  require Logger

  alias ElixirLokaliseApi.Model.QueuedProcess
  alias ExLokaliseTransfer.Helpers.Backoff
  alias ExLokaliseTransfer.Processes.Classifier
  alias ExLokaliseTransfer.Processes.Poller

  @max_concurrency 6

  @type queued_process :: Classifier.queued_process()
  @type check_result :: Classifier.check_result()
  @type poll_opts :: Poller.poll_opts()
  @type result :: Poller.result()

  @type many_check_result :: [{String.t(), check_result()}]
  @type many_result :: [{String.t(), result()}]

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
    |> Enum.map(fn {:ok, {process_id, result}} ->
      {process_id, result}
    end)
  end

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

  defp do_wait_many([], _project_id, _opts, _attempt_idx, _max_attempts, acc), do: acc

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
        {Map.put(done_map, process_id, to_terminal_result(result)), pending_ids}
    end)
    |> then(fn {done_map, pending_ids} ->
      {done_map, Enum.reverse(pending_ids)}
    end)
  end

  defp to_terminal_result({:ok, %QueuedProcess{} = process}), do: {:ok, process}

  defp to_terminal_result({:error, {:process_failed, %QueuedProcess{} = process}}),
    do: {:error, {:process_failed, process}}

  defp to_terminal_result({:error, {:process_cancelled, %QueuedProcess{} = process}}),
    do: {:error, {:process_cancelled, process}}

  defp to_terminal_result({:error, {:unexpected_process_status, status, process}}),
    do: {:error, {:unexpected_process_status, status, process}}

  defp to_terminal_result({:error, reason}), do: {:error, reason}

  defp safe_check(project_id, process_id) do
    try do
      Poller.check(project_id, process_id)
    rescue
      e ->
        {:error, {:exception, Exception.message(e)}}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end
end
