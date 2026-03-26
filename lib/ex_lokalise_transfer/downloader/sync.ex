defmodule ExLokaliseTransfer.Downloader.Sync do
  @behaviour ExLokaliseTransfer.RunnerBehaviour

  require Logger

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Helpers.Normalization
  alias ExLokaliseTransfer.Downloader.Common
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Retry
  alias ExLokaliseTransfer.Downloader.Bundle.Temp
  alias ExLokaliseTransfer.Downloader.Bundle.Transfer

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
    target_dir = Common.resolve_extract_to(extra)

    Logger.debug("starting sync download",
      project_id: project_id,
      operation: :download_sync,
      extract_to: target_dir
    )

    zip_path = temp_module().temp_zip_path(:sync)
    data = Normalization.normalize_body(body)

    try do
      with {:ok, bundle_url} <- request_bundle_url(project_id, data, retry),
           :ok <- transfer_module().download_and_extract(bundle_url, zip_path, target_dir, retry) do
        :ok
      end
    after
      File.rm(zip_path)
    end
  end

  defp request_bundle_url(project_id, data, retry) do
    case retry_module().run(
           fn -> lokalise_files_module().download(project_id, data) end,
           :lokalise,
           retry
         ) do
      {:ok, %{bundle_url: url}} when is_binary(url) and url != "" ->
        {:ok, url}

      {:ok, resp} ->
        {:error, {:unexpected_response, resp}}

      {:error, %Error{} = err} ->
        {:error, err}
    end
  end

  defp retry_module,
    do: Application.get_env(:ex_lokalise_transfer, :retry_module, Retry)

  defp temp_module,
    do: Application.get_env(:ex_lokalise_transfer, :downloader_temp_module, Temp)

  defp transfer_module,
    do: Application.get_env(:ex_lokalise_transfer, :downloader_transfer_module, Transfer)

  defp lokalise_files_module,
    do:
      Application.get_env(
        :ex_lokalise_transfer,
        :lokalise_files_module,
        ExLokaliseTransfer.Sdk.LokaliseFilesImpl
      )
end
