defmodule ExLokaliseTransfer do
  @moduledoc """
  Public facade for Lokalise download/upload workflows.

  This module orchestrates config building, validation and delegates execution
  to specific runners.

  Flows:
    - upload (async, per-file processes with summary)
    - download_sync (blocking)
    - download_async (remote async process with polling, then download)

  Note:
    `download/1` is an alias for `download_sync/1`.
  """

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader
  alias ExLokaliseTransfer.Downloader.Sync
  alias ExLokaliseTransfer.Uploader
  alias ExLokaliseTransfer.Uploader.Async

  @type opts :: Keyword.t()

  @type download_result :: :ok | {:error, term()}

  @type upload_result ::
          {:ok, Uploader.Async.summary()}
          | {:error, Uploader.Async.summary()}
          | {:error, term()}

  @doc """
  Uploads local files to Lokalise.

  Each file is uploaded as a separate async process.

  Returns:
    - `{:ok, summary}` when all files succeeded
    - `{:error, summary}` when at least one file/process failed
    - `{:error, reason}` if the flow failed before execution
  """
  @spec upload(opts()) :: upload_result()
  def upload(opts \\ []) do
    config = Config.build(opts, Uploader.Common.default_opts())

    with :ok <- Uploader.Common.validate(config) do
      uploader_async_module().run(config)
    end
  end

  @doc """
  Runs sync download (default).

  Equivalent to `download_sync/1`.
  """
  @spec download() :: download_result()
  @spec download(opts()) :: download_result()
  def download(opts \\ []), do: download_sync(opts)

  @doc """
  Runs sync download.

  Blocks until the archive is downloaded and extracted.
  """
  @spec download_sync(opts()) :: download_result()
  def download_sync(opts \\ []) do
    do_download(downloader_sync_module(), opts)
  end

  @doc """
  Runs async download.

  Starts a remote Lokalise process, polls until completion,
  then downloads and extracts the archive.
  """
  @spec download_async(opts()) :: download_result()
  def download_async(opts \\ []) do
    do_download(downloader_async_module(), opts)
  end

  @spec do_download(module(), opts()) :: download_result()
  defp do_download(mod, opts) do
    config =
      opts
      |> Config.build(Downloader.Common.default_opts())

    with :ok <- Config.validate_common(config),
         :ok <- Downloader.Common.validate(config) do
      mod.run(config)
    end
  end

  defp uploader_async_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :uploader_async_module,
      Async
    )
  end

  defp downloader_sync_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :downloader_sync_module,
      Sync
    )
  end

  defp downloader_async_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :downloader_async_module,
      ExLokaliseTransfer.Downloader.Async
    )
  end
end
