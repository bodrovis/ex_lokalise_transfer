defmodule ExLokaliseTransfer.Downloader.Async do
  @moduledoc """
  Runs the async download flow for Lokalise translations.

  The module enqueues an async bundle build in Lokalise, waits for the queued
  process to finish, extracts the resulting `download_url`, then downloads and
  extracts the ZIP archive into `extra[:locales_path]`.
  """

  require Logger

  alias ElixirLokaliseApi.Files
  alias ExLokaliseTransfer.Helpers.Normalization
  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader.Bundle.Temp
  alias ExLokaliseTransfer.Downloader.Common
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Processes.Poller
  alias ExLokaliseTransfer.Retry

  @doc """
  Enqueues an async Lokalise bundle build, waits for completion, then downloads
  and extracts the archive into the configured locales path.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec run(Config.t()) :: :ok | {:error, term()}
  def run(%Config{
        project_id: project_id,
        body: body,
        retry: retry,
        poll: poll,
        extra: extra
      }) do
    target_dir = Common.resolve_extract_to(extra)

    Logger.debug("starting async download",
      project_id: project_id,
      operation: :download_async,
      extract_to: target_dir
    )

    zip_path = Temp.temp_zip_path(:async)
    data = Normalization.normalize_body(body)

    try do
      with {:ok, process_id} <- request_async_process(project_id, data, retry),
           {:ok, process} <- Poller.wait(project_id, process_id, poll || []),
           {:ok, bundle_url} <- extract_download_url(process),
           :ok <- Common.download_and_extract(bundle_url, zip_path, target_dir, retry) do
        :ok
      end
    after
      File.rm(zip_path)
    end
  end

  defp request_async_process(project_id, data, retry) do
    case Retry.run(fn -> Files.download_async(project_id, data) end, :lokalise, retry) do
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
    if String.trim(url) != "" do
      {:ok, url}
    else
      :error
    end
  end

  defp fetch_download_url(details) when is_map(details) do
    cond do
      is_binary(details[:download_url]) ->
        normalize_url(details[:download_url])

      is_binary(details["download_url"]) ->
        normalize_url(details["download_url"])

      true ->
        :error
    end
  end

  defp fetch_download_url(details) when is_list(details) do
    case Keyword.get(details, :download_url) do
      url when is_binary(url) ->
        if String.trim(url) != "" do
          {:ok, url}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp fetch_download_url(_), do: :error
end
