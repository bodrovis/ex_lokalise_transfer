defmodule ExLokaliseTransfer.Downloader.Bundle.Transfer do
  @moduledoc """
  Coordinates bundle download and extraction.

  The bundle is downloaded with retries and extracted only after a successful
  download.
  """

  @behaviour ExLokaliseTransfer.Downloader.Bundle.TransferBehaviour

  alias ExLokaliseTransfer.Retry
  alias ExLokaliseTransfer.Downloader.Bundle.Fetcher
  alias ExLokaliseTransfer.Downloader.Bundle.Extractor

  @finch ElixirLokaliseApi.Finch

  @spec download_and_extract(String.t(), String.t(), String.t(), Keyword.t()) ::
          :ok | {:error, term()}
  def download_and_extract(url, zip_path, target_dir, retry_opts)
      when is_binary(url) and is_binary(zip_path) and is_binary(target_dir) and
             is_list(retry_opts) do
    with {:ok, :downloaded} <-
           retry_module().run(
             fn -> fetcher_module().download_zip_stream(finch_name(), url, zip_path) end,
             :s3,
             retry_opts
           ),
         :ok <- extractor_module().extract_zip(zip_path, target_dir) do
      :ok
    end
  end

  defp retry_module do
    Application.get_env(:ex_lokalise_transfer, :retry_module, Retry)
  end

  defp fetcher_module do
    Application.get_env(:ex_lokalise_transfer, :bundle_fetcher_module, Fetcher)
  end

  defp extractor_module do
    Application.get_env(:ex_lokalise_transfer, :bundle_extractor_module, Extractor)
  end

  defp finch_name do
    Application.get_env(:ex_lokalise_transfer, :finch_module, @finch)
  end
end
