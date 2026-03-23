defmodule ExLokaliseTransfer.Uploader.Async do
  @moduledoc """
  Runs the async upload flow for Lokalise translation files.

  Flow:
    1. Discover local files under `extra[:locales_path]`
    2. Read and encode each file as base64
    3. Enqueue upload requests in parallel (max 6 at a time)
    4. Wait for all queued Lokalise processes to finish
    5. Return a summary with per-file/process results

  Returns:
    - `{:ok, summary}` when all files were uploaded successfully
    - `{:error, summary}` when at least one enqueue or process failed
  """

  require Logger

  alias ExLokaliseTransfer.Helpers.Normalization
  alias ElixirLokaliseApi.Files
  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Processes.BatchPoller
  alias ExLokaliseTransfer.Retry
  alias ExLokaliseTransfer.Uploader.Files, as: UploadFiles
  alias ExLokaliseTransfer.Uploader.Files.Entry

  @max_concurrency 6

  @type enqueue_success :: %{
          entry: Entry.t(),
          process_id: String.t()
        }

  @type enqueue_error :: %{
          entry: Entry.t(),
          error: term()
        }

  @type process_result :: %{
          entry: Entry.t(),
          process_id: String.t(),
          result: BatchPoller.result()
        }

  @type summary :: %{
          discovered_entries: [Entry.t()],
          enqueue_successes: [enqueue_success()],
          enqueue_errors: [enqueue_error()],
          process_results: [process_result()],
          errors: [term()]
        }

  @type result :: {:ok, summary()} | {:error, summary()}

  @doc """
  Runs the async uploader.
  """
  @spec run(Config.t()) :: result()
  def run(%Config{
        project_id: project_id,
        body: body,
        retry: retry,
        poll: poll,
        extra: extra
      }) do
    Logger.debug("starting async upload",
      project_id: project_id,
      operation: :upload_async
    )

    with {:ok, entries} <- UploadFiles.discover(extra) do
      body_map = Normalization.normalize_body(body)

      {enqueue_successes, enqueue_errors} =
        enqueue_many(project_id, entries, body_map, retry)

      process_results =
        wait_for_enqueued_processes(project_id, enqueue_successes, poll || [])

      summary = %{
        discovered_entries: entries,
        enqueue_successes: enqueue_successes,
        enqueue_errors: enqueue_errors,
        process_results: process_results,
        errors: collect_errors(enqueue_errors, process_results)
      }

      if summary.errors == [] do
        {:ok, summary}
      else
        {:error, summary}
      end
    end
  end

  defp enqueue_many(project_id, entries, body_map, retry) do
    entries
    |> Task.async_stream(
      fn %Entry{} = entry ->
        enqueue_one(project_id, entry, body_map, retry)
      end,
      max_concurrency: @max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {:ok, success}}, {successes, errors} ->
        {[success | successes], errors}

      {:ok, {:error, error}}, {successes, errors} ->
        {successes, [error | errors]}
    end)
    |> then(fn {successes, errors} ->
      {Enum.reverse(successes), Enum.reverse(errors)}
    end)
  end

  defp enqueue_one(project_id, %Entry{} = entry, body_map, retry) do
    with {:ok, encoded_data} <- read_and_encode_file(entry.abs_path),
         payload <- build_upload_payload(entry, encoded_data, body_map),
         {:ok, process_id} <- request_upload(project_id, payload, retry) do
      {:ok, %{entry: entry, process_id: process_id}}
    else
      {:error, reason} ->
        {:error, %{entry: entry, error: reason}}
    end
  end

  defp read_and_encode_file(abs_path) when is_binary(abs_path) do
    case File.read(abs_path) do
      {:ok, contents} ->
        {:ok, Base.encode64(contents)}

      {:error, reason} ->
        {:error, {:file_read_failed, abs_path, reason}}
    end
  end

  defp build_upload_payload(%Entry{} = entry, encoded_data, body_map) do
    Map.merge(body_map, %{
      data: encoded_data,
      filename: entry.rel_path,
      lang_iso: entry.lang_iso
    })
  end

  defp request_upload(project_id, payload, retry) do
    case Retry.run(fn -> Files.upload(project_id, payload) end, :lokalise, retry) do
      {:ok, %{process_id: process_id}} when is_binary(process_id) and process_id != "" ->
        {:ok, process_id}

      {:ok, resp} ->
        {:error, {:unexpected_response, resp}}

      {:error, %Error{} = err} ->
        {:error, err}
    end
  end

  defp wait_for_enqueued_processes(_project_id, [], _poll_opts), do: []

  defp wait_for_enqueued_processes(project_id, enqueue_successes, poll_opts) do
    process_ids = Enum.map(enqueue_successes, & &1.process_id)

    entry_by_process_id =
      Map.new(enqueue_successes, fn %{entry: entry, process_id: process_id} ->
        {process_id, entry}
      end)

    project_id
    |> BatchPoller.wait_many(process_ids, poll_opts)
    |> Enum.map(fn {process_id, result} ->
      %{
        entry: Map.fetch!(entry_by_process_id, process_id),
        process_id: process_id,
        result: result
      }
    end)
  end

  defp collect_errors(enqueue_errors, process_results) do
    enqueue_reasons =
      Enum.map(enqueue_errors, fn %{entry: entry, error: error} ->
        {:enqueue_error, entry.rel_path, error}
      end)

    process_reasons =
      Enum.flat_map(process_results, fn %{entry: entry, process_id: process_id, result: result} ->
        case result do
          {:ok, _process} ->
            []

          {:error, reason} ->
            [{:process_error, entry.rel_path, process_id, reason}]
        end
      end)

    enqueue_reasons ++ process_reasons
  end
end
