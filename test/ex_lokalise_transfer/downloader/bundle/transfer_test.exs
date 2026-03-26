defmodule ExLokaliseTransfer.Downloader.Bundle.TransferTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Downloader.Bundle.Transfer
  alias ExLokaliseTransfer.RetryMock
  alias ExLokaliseTransfer.BundleFetcherMock
  alias ExLokaliseTransfer.BundleExtractorMock

  setup {ExLokaliseTransfer.Case, :set_downloader_transfer_dependency_mocks}

  describe "download_and_extract/4" do
    test "returns :ok when download and extraction succeed" do
      url = "https://example.com/bundle.zip"
      zip_path = "/tmp/bundle.zip"
      target_dir = "/tmp/out"
      retry_opts = [max_attempts: 3]

      RetryMock
      |> expect(:run, fn fun, :s3, ^retry_opts ->
        fun.()
      end)

      BundleFetcherMock
      |> expect(:download_zip_stream, fn finch, ^url, ^zip_path ->
        assert finch == ElixirLokaliseApi.Finch
        {:ok, :downloaded}
      end)

      BundleExtractorMock
      |> expect(:extract_zip, fn ^zip_path, ^target_dir ->
        :ok
      end)

      assert :ok = Transfer.download_and_extract(url, zip_path, target_dir, retry_opts)
    end

    test "returns retry error and does not call extractor when download fails" do
      url = "https://example.com/bundle.zip"
      zip_path = "/tmp/bundle.zip"
      target_dir = "/tmp/out"
      retry_opts = [max_attempts: 3]

      RetryMock
      |> expect(:run, fn fun, :s3, ^retry_opts ->
        fun.()
      end)

      BundleFetcherMock
      |> expect(:download_zip_stream, fn _finch, ^url, ^zip_path ->
        {:error, {:http_error, 404, "not found"}}
      end)

      assert {:error, {:http_error, 404, "not found"}} =
               Transfer.download_and_extract(url, zip_path, target_dir, retry_opts)
    end

    test "returns retry module error and does not call fetcher or extractor when retry fails before running callback" do
      url = "https://example.com/bundle.zip"
      zip_path = "/tmp/bundle.zip"
      target_dir = "/tmp/out"
      retry_opts = [max_attempts: 3]

      RetryMock
      |> expect(:run, fn _fun, :s3, ^retry_opts ->
        {:error, :retry_exhausted}
      end)

      assert {:error, :retry_exhausted} =
               Transfer.download_and_extract(url, zip_path, target_dir, retry_opts)
    end

    test "returns extractor error after successful download" do
      url = "https://example.com/bundle.zip"
      zip_path = "/tmp/bundle.zip"
      target_dir = "/tmp/out"
      retry_opts = [max_attempts: 3]

      RetryMock
      |> expect(:run, fn fun, :s3, ^retry_opts ->
        fun.()
      end)

      BundleFetcherMock
      |> expect(:download_zip_stream, fn _finch, ^url, ^zip_path ->
        {:ok, :downloaded}
      end)

      BundleExtractorMock
      |> expect(:extract_zip, fn ^zip_path, ^target_dir ->
        {:error, {:unsafe_zip_entry, "../evil.txt"}}
      end)

      assert {:error, {:unsafe_zip_entry, "../evil.txt"}} =
               Transfer.download_and_extract(url, zip_path, target_dir, retry_opts)
    end

    test "passes the configured finch module to fetcher" do
      original_finch = Application.get_env(:ex_lokalise_transfer, :finch_module)

      Application.put_env(:ex_lokalise_transfer, :finch_module, :custom_finch)

      on_exit(fn ->
        case original_finch do
          nil -> Application.delete_env(:ex_lokalise_transfer, :finch_module)
          value -> Application.put_env(:ex_lokalise_transfer, :finch_module, value)
        end
      end)

      url = "https://example.com/bundle.zip"
      zip_path = "/tmp/bundle.zip"
      target_dir = "/tmp/out"
      retry_opts = [max_attempts: 3]

      RetryMock
      |> expect(:run, fn fun, :s3, ^retry_opts ->
        fun.()
      end)

      BundleFetcherMock
      |> expect(:download_zip_stream, fn :custom_finch, ^url, ^zip_path ->
        {:ok, :downloaded}
      end)

      BundleExtractorMock
      |> expect(:extract_zip, fn ^zip_path, ^target_dir ->
        :ok
      end)

      assert :ok = Transfer.download_and_extract(url, zip_path, target_dir, retry_opts)
    end
  end
end
