defmodule ExLokaliseSync do
  @moduledoc """
  High-level entry points for ExLokaliseSync.

  Provides:
    - `upload/1`   (upload local files to Lokalise)
    - `download/1` (download files from Lokalise)

  Both accept optional overrides via opts.
  """

  alias ExLokaliseSync.Config
  alias ExLokaliseSync.Downloader
  alias ExLokaliseSync.Uploader

  @spec upload(Keyword.t()) :: any()
  def upload(opts \\ []) do
    config = Config.build(opts, Uploader.default_opts())
    Uploader.run(config)
  end

  @spec download(Keyword.t()) :: any()
  def download(opts \\ []) do
    config = Config.build(opts, Downloader.default_opts())
    Downloader.run(config)
  end
end
