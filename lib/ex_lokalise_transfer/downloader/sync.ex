defmodule ExLokaliseTransfer.Downloader.Sync do
  @moduledoc """
  Runs the sync download flow for Lokalise translations.

  The module requests a bundle URL from Lokalise, downloads the ZIP archive with retries,
  and extracts it into `extra[:extract_to]`.

  The target path is expanded to an absolute path. Existing files in the target directory
  are not removed before extraction.
  """

  require Logger

  alias ElixirLokaliseApi.Files
  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Helpers
  alias ExLokaliseTransfer.Downloader.Bundle
  alias ExLokaliseTransfer.Downloader.Common
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Retry

  @doc """
  Downloads and extracts the Lokalise bundle into the configured locales path.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec run(Config.t()) :: :ok | {:error, term()}
  def run(%Config{
        project_id: project_id,
        body: body,
        retry: retry,
        extra: extra
      }) do
    target_dir = Helpers.resolve_extract_to(extra)

    Logger.debug("starting sync download",
      project_id: project_id,
      operation: :download_sync,
      extract_to: target_dir
    )

    zip_path = Bundle.temp_zip_path(:sync)
    data = Helpers.normalize_body(body)

    try do
      with {:ok, bundle_url} <- request_bundle_url(project_id, data, retry),
           :ok <- Common.download_and_extract(bundle_url, zip_path, target_dir, retry) do
        :ok
      end
    after
      File.rm(zip_path)
    end
  end

  defp request_bundle_url(project_id, data, retry) do
    case Retry.run(fn -> Files.download(project_id, data) end, :lokalise, retry) do
      {:ok, %{bundle_url: url}} when is_binary(url) and url != "" ->
        {:ok, url}

      {:ok, resp} ->
        {:error, {:unexpected_response, resp}}

      {:error, %Error{} = err} ->
        {:error, err}
    end
  end
end
