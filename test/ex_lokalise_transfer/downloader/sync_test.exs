defmodule ExLokaliseTransfer.Downloader.SyncTest do
  use ExLokaliseTransfer.Case, async: false

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader.Sync
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.RetryMock
  alias ExLokaliseTransfer.TempMock
  alias ExLokaliseTransfer.TransferMock
  alias ExLokaliseTransfer.LokaliseFilesMock

  setup {ExLokaliseTransfer.Case, :set_downloader_sync_dependency_mocks}

  describe "run/1" do
    test "returns :ok when bundle url is requested and bundle is downloaded and extracted" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :sync -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, [max_attempts: 3] = retry_opts ->
        assert retry_opts == [max_attempts: 3]
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download, fn "project-123", data ->
        assert data == %{
                 format: "json",
                 original_filenames: true
               }

        {:ok, %{bundle_url: "https://s3.example.com/bundle.zip"}}
      end)

      TransferMock
      |> expect(:download_and_extract, fn "https://s3.example.com/bundle.zip",
                                          ^zip_path,
                                          target_dir,
                                          [max_attempts: 3] ->
        assert target_dir == Path.expand("./priv/locales")
        :ok
      end)

      assert :ok =
               Sync.run(%Config{
                 project_id: "project-123",
                 body: [format: "json", original_filenames: true],
                 retry: [max_attempts: 3],
                 extra: [extract_to: "./priv/locales"]
               })
    end

    test "returns unexpected_response when download request succeeds without valid bundle_url" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :sync -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, retry_opts ->
        assert retry_opts == [max_attempts: 3]
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download, fn "project-123", _data ->
        {:ok, %{foo: "bar"}}
      end)

      assert {:error, {:unexpected_response, %{foo: "bar"}}} =
               Sync.run(%Config{
                 project_id: "project-123",
                 body: [format: "json"],
                 retry: [max_attempts: 3],
                 extra: [extract_to: "./priv/locales"]
               })
    end

    test "returns unexpected_response when bundle_url is empty" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :sync -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download, fn "project-123", _data ->
        {:ok, %{bundle_url: ""}}
      end)

      assert {:error, {:unexpected_response, %{bundle_url: ""}}} =
               Sync.run(%Config{
                 project_id: "project-123",
                 body: [format: "json"],
                 retry: [max_attempts: 3],
                 extra: [extract_to: "./priv/locales"]
               })
    end

    test "returns retry error when bundle url request fails" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :sync -> zip_path end)

      err = %Error{
        source: :lokalise,
        kind: :http,
        status: 429,
        code: nil,
        message: "rate limited"
      }

      RetryMock
      |> expect(:run, fn _fun, :lokalise, _retry_opts ->
        {:error, err}
      end)

      assert {:error, ^err} =
               Sync.run(%Config{
                 project_id: "project-123",
                 body: [format: "json"],
                 retry: [max_attempts: 3],
                 extra: [extract_to: "./priv/locales"]
               })
    end

    test "returns transfer error when bundle download/extract fails" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :sync -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download, fn "project-123", _data ->
        {:ok, %{bundle_url: "https://s3.example.com/bundle.zip"}}
      end)

      TransferMock
      |> expect(:download_and_extract, fn "https://s3.example.com/bundle.zip",
                                          ^zip_path,
                                          _target_dir,
                                          _retry ->
        {:error, {:http_error, 404, "not found"}}
      end)

      assert {:error, {:http_error, 404, "not found"}} =
               Sync.run(%Config{
                 project_id: "project-123",
                 body: [format: "json"],
                 retry: [max_attempts: 3],
                 extra: [extract_to: "./priv/locales"]
               })
    end

    test "removes temp zip path in after block" do
      zip_path = unique_tmp_zip_path()
      File.write!(zip_path, "stale zip")

      TempMock
      |> expect(:temp_zip_path, fn :sync -> zip_path end)

      RetryMock
      |> expect(:run, fn _fun, :lokalise, _retry_opts ->
        {:error, %Error{source: :lokalise, kind: :http, status: 500, code: nil, message: "boom"}}
      end)

      assert {:error, %Error{}} =
               Sync.run(%Config{
                 project_id: "project-123",
                 body: [format: "json"],
                 retry: [max_attempts: 3],
                 extra: [extract_to: "./priv/locales"]
               })

      refute File.exists?(zip_path)
    end
  end

  defp unique_tmp_zip_path do
    Path.join(
      System.tmp_dir!(),
      "ex_lokalise_transfer_sync_test_#{System.unique_integer([:positive, :monotonic])}.zip"
    )
  end
end
