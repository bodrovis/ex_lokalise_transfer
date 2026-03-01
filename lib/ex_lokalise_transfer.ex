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

  @spec upload(Keyword.t()) :: any()
  def upload(opts \\ []) do
    config = Config.build(opts, Uploader.Common.default_opts())

    with :ok <- Uploader.Common.validate(config) do
      Uploader.Async.run(config)
    end
  end

  @spec download(Keyword.t()) :: any()
  def download(opts \\ []), do: download_sync(opts)

  @spec download_sync(Keyword.t()) :: any()
  def download_sync(opts \\ []) do
    do_download(Downloader.Sync, opts)
  end

  @spec download_async(Keyword.t()) :: any()
  def download_async(opts \\ []) do
    do_download(Downloader.Async, opts)
  end

  defp do_download(mod, opts) do
    config =
      opts
      |> Config.build(Downloader.Common.default_opts())

    with :ok <- Config.validate_common(config),
         :ok <- Downloader.Common.validate(config) do
      mod.run(config)
    end
  end
end
