defmodule ExLokaliseTransfer.Downloader.Bundle.FetcherTest do
  use ExLokaliseTransfer.Case, async: true

  setup {ExLokaliseTransfer.Case, :set_downloader_bundle_dependency_mocks}

  alias ExLokaliseTransfer.Downloader.Bundle.Fetcher
  alias ExLokaliseTransfer.HTTPStreamClientMock

  describe "download_zip_stream/3" do
    test "downloads response body into final file on HTTP 200" do
      tmp_dir = unique_tmp_dir()
      path = Path.join(tmp_dir, "bundle.zip")

      HTTPStreamClientMock
      |> expect(:stream, fn :test_finch, :get, "https://example.com/bundle.zip", acc, fun ->
        acc =
          acc
          |> then(&fun.({:status, 200}, &1))
          |> then(&fun.({:headers, [{"content-type", "application/zip"}]}, &1))
          |> then(&fun.({:data, "abc"}, &1))
          |> then(&fun.({:data, "def"}, &1))
          |> then(&fun.({:done}, &1))

        {:ok, acc}
      end)

      assert {:ok, :downloaded} =
               Fetcher.download_zip_stream(:test_finch, "https://example.com/bundle.zip", path)

      assert File.read!(path) == "abcdef"
      refute File.exists?(path <> ".part")
    end

    test "returns http_error for non-200 response and removes temp file" do
      tmp_dir = unique_tmp_dir()
      path = Path.join(tmp_dir, "bundle.zip")

      HTTPStreamClientMock
      |> expect(:stream, fn :test_finch, :get, "https://example.com/missing.zip", acc, fun ->
        acc =
          acc
          |> then(&fun.({:status, 404}, &1))
          |> then(&fun.({:headers, []}, &1))
          |> then(&fun.({:data, " not found \n"}, &1))
          |> then(&fun.({:done}, &1))

        {:ok, acc}
      end)

      assert {:error, {:http_error, 404, "not found"}} =
               Fetcher.download_zip_stream(:test_finch, "https://example.com/missing.zip", path)

      refute File.exists?(path)
      refute File.exists?(path <> ".part")
    end

    test "returns no_status when stream completes without status" do
      tmp_dir = unique_tmp_dir()
      path = Path.join(tmp_dir, "bundle.zip")

      HTTPStreamClientMock
      |> expect(:stream, fn :test_finch, :get, "https://example.com/weird.zip", acc, fun ->
        acc =
          acc
          |> then(&fun.({:headers, []}, &1))
          |> then(&fun.({:done}, &1))

        {:ok, acc}
      end)

      assert {:error, :no_status} =
               Fetcher.download_zip_stream(:test_finch, "https://example.com/weird.zip", path)

      refute File.exists?(path)
      refute File.exists?(path <> ".part")
    end

    test "returns stream_failed when stream client returns error tuple" do
      tmp_dir = unique_tmp_dir()
      path = Path.join(tmp_dir, "bundle.zip")

      HTTPStreamClientMock
      |> expect(:stream, fn :test_finch, :get, "https://example.com/fail.zip", _acc, _fun ->
        {:error, %{reason: :timeout}, []}
      end)

      assert {:error, {:stream_failed, :timeout}} =
               Fetcher.download_zip_stream(:test_finch, "https://example.com/fail.zip", path)

      refute File.exists?(path)
      refute File.exists?(path <> ".part")
    end

    test "limits collected error body size" do
      tmp_dir = unique_tmp_dir()
      path = Path.join(tmp_dir, "bundle.zip")
      big = String.duplicate("a", 10_000)

      HTTPStreamClientMock
      |> expect(:stream, fn :test_finch, :get, "https://example.com/huge_error.zip", acc, fun ->
        acc =
          acc
          |> then(&fun.({:status, 500}, &1))
          |> then(&fun.({:data, big}, &1))
          |> then(&fun.({:done}, &1))

        {:ok, acc}
      end)

      assert {:error, {:http_error, 500, body}} =
               Fetcher.download_zip_stream(
                 :test_finch,
                 "https://example.com/huge_error.zip",
                 path
               )

      assert byte_size(body) == 8_192
    end

    test "creates parent directory when needed" do
      tmp_dir = unique_tmp_dir()
      path = Path.join([tmp_dir, "nested", "deeper", "bundle.zip"])

      HTTPStreamClientMock
      |> expect(:stream, fn :test_finch, :get, "https://example.com/bundle.zip", acc, fun ->
        acc =
          acc
          |> then(&fun.({:status, 200}, &1))
          |> then(&fun.({:data, "zipdata"}, &1))
          |> then(&fun.({:done}, &1))

        {:ok, acc}
      end)

      assert {:ok, :downloaded} =
               Fetcher.download_zip_stream(:test_finch, "https://example.com/bundle.zip", path)

      assert File.read!(path) == "zipdata"
    end

    test "cleans up stale temp file before downloading" do
      tmp_dir = unique_tmp_dir()
      path = Path.join(tmp_dir, "bundle.zip")
      tmp_path = path <> ".part"

      File.write!(tmp_path, "stale temp data")

      HTTPStreamClientMock
      |> expect(:stream, fn :test_finch, :get, "https://example.com/bundle.zip", acc, fun ->
        acc =
          acc
          |> then(&fun.({:status, 200}, &1))
          |> then(&fun.({:data, "fresh"}, &1))
          |> then(&fun.({:done}, &1))

        {:ok, acc}
      end)

      assert {:ok, :downloaded} =
               Fetcher.download_zip_stream(:test_finch, "https://example.com/bundle.zip", path)

      assert File.read!(path) == "fresh"
      refute File.exists?(tmp_path)
    end
  end

  defp unique_tmp_dir do
    path =
      Path.join(
        System.tmp_dir!(),
        "ex_lokalise_transfer_fetcher_test_#{System.unique_integer([:positive, :monotonic])}"
      )

    File.rm_rf!(path)
    File.mkdir_p!(path)
    path
  end
end
