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

  @type result :: :ok | {:error, term()}

  @spec upload(Keyword.t()) :: result()
  def upload(opts \\ []) do
    config = Config.build(opts, Uploader.Common.default_opts())

    with :ok <- Uploader.Common.validate(config) do
      Uploader.Async.run(config)
    end
  end

  @doc """
  Runs the default download flow.
  """
  @spec download(Keyword.t()) :: result()
  @spec download() :: result()
  def download(opts \\ []), do: download_sync(opts)

  @doc """
  Runs the sync downloader.
  """
  @spec download_sync(Keyword.t()) :: result()
  def download_sync(opts \\ []) do
    do_download(Downloader.Sync, opts)
  end

  @spec download_async(Keyword.t()) :: result()
  def download_async(opts \\ []) do
    do_download(Downloader.Async, opts)
  end

  @spec do_download(module(), Keyword.t()) :: result()
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
