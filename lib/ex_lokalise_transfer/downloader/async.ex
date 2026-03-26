defmodule ExLokaliseTransfer.Downloader.Async do
  @moduledoc """
  Runs the async download flow for Lokalise translations.

  The module enqueues an async bundle build in Lokalise, waits for the queued
  process to finish, extracts the resulting `download_url`, then downloads and
  extracts the ZIP archive into `extra[:extract_to]`.
  """

  @behaviour ExLokaliseTransfer.RunnerBehaviour

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader.Bundle.Temp
  alias ExLokaliseTransfer.Downloader.Bundle.Transfer
  alias ExLokaliseTransfer.Downloader.Common
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Helpers.Normalization
  alias ExLokaliseTransfer.Processes.Poller
  alias ExLokaliseTransfer.Retry
  alias ExLokaliseTransfer.Sdk.LokaliseFilesImpl

  require Logger

  @doc """
  Enqueues an async Lokalise bundle build, waits for completion, then downloads
  and extracts the archive into the configured locales path.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec run(Config.t()) :: :ok | {:error, term()}
  def run(%Config{project_id: project_id, body: body, retry: retry, poll: poll, extra: extra}) do
    target_dir = Common.resolve_extract_to(extra)

    Logger.debug("starting async download",
      project_id: project_id,
      operation: :download_async,
      extract_to: target_dir
    )

    zip_path = temp_module().temp_zip_path(:async)
    data = Normalization.normalize_body(body)

    try do
      with {:ok, process_id} <- request_async_process(project_id, data, retry),
           {:ok, process} <- poller_module().wait(project_id, process_id, poll || []),
           {:ok, bundle_url} <- extract_download_url(process) do
        transfer_module().download_and_extract(bundle_url, zip_path, target_dir, retry)
      end
    after
      File.rm(zip_path)
    end
  end

  defp request_async_process(project_id, data, retry) do
    case retry_module().run(
           fn -> lokalise_files_module().download_async(project_id, data) end,
           :lokalise,
           retry
         ) do
      {:ok, %{process_id: process_id}} when is_binary(process_id) and process_id != "" ->
        {:ok, process_id}

      {:ok, resp} ->
        {:error, {:unexpected_response, resp}}

      {:error, %Error{} = err} ->
        {:error, err}
    end
  end

  defp extract_download_url(%{process_id: process_id, details: details}) do
    case fetch_download_url(details) do
      {:ok, url} ->
        {:ok, url}

      :error ->
        {:error, {:missing_download_url, process_id}}
    end
  end

  defp normalize_url(url) when is_binary(url) do
    if String.trim(url) == "" do
      :error
    else
      {:ok, url}
    end
  end

  defp fetch_download_url(details) when is_map(details) do
    atom_url = details[:download_url]
    string_url = details["download_url"]

    case {atom_url, string_url} do
      {url, _} when is_binary(url) ->
        normalize_url(url)

      {_, url} when is_binary(url) ->
        normalize_url(url)

      _ ->
        :error
    end
  end

  defp fetch_download_url(details) when is_list(details) do
    case Keyword.get(details, :download_url) do
      url when is_binary(url) ->
        normalize_url(url)

      _ ->
        :error
    end
  end

  defp fetch_download_url(_), do: :error

  defp retry_module do
    Application.get_env(:ex_lokalise_transfer, :retry_module, Retry)
  end

  defp poller_module do
    Application.get_env(:ex_lokalise_transfer, :poller_module, Poller)
  end

  defp temp_module do
    Application.get_env(:ex_lokalise_transfer, :downloader_temp_module, Temp)
  end

  defp transfer_module do
    Application.get_env(:ex_lokalise_transfer, :downloader_transfer_module, Transfer)
  end

  defp lokalise_files_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :lokalise_files_module,
      LokaliseFilesImpl
    )
  end
end
