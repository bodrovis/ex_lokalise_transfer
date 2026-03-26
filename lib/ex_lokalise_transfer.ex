defmodule ExLokaliseTransfer do
  @moduledoc """
  High-level entry points for ExLokaliseTransfer.

  Provides:
    - `upload/1`   (upload local files to Lokalise)
    - `download/1` (download files from Lokalise)

  Both accept optional overrides via opts.
  """

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader
  alias ExLokaliseTransfer.Uploader

  @type download_result :: :ok | {:error, term()}

  @type upload_result ::
          {:ok, ExLokaliseTransfer.Uploader.Async.summary()}
          | {:error, ExLokaliseTransfer.Uploader.Async.summary()}
          | {:error, term()}

  @spec upload(Keyword.t()) :: upload_result()
  def upload(opts \\ []) do
    config = Config.build(opts, Uploader.Common.default_opts())

    with :ok <- Uploader.Common.validate(config) do
      uploader_async_module().run(config)
    end
  end

  @doc """
  Runs the default download flow.
  """
  @spec download(Keyword.t()) :: download_result()
  @spec download() :: download_result()
  def download(opts \\ []), do: download_sync(opts)

  @doc """
  Runs the sync downloader.
  """
  @spec download_sync(Keyword.t()) :: download_result()
  def download_sync(opts \\ []) do
    do_download(downloader_sync_module(), opts)
  end

  @spec download_async(Keyword.t()) :: download_result()
  def download_async(opts \\ []) do
    do_download(downloader_async_module(), opts)
  end

  @spec do_download(module(), Keyword.t()) :: download_result()
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
      ExLokaliseTransfer.Uploader.Async
    )
  end

  defp downloader_sync_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :downloader_sync_module,
      ExLokaliseTransfer.Downloader.Sync
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
