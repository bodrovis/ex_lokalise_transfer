defmodule ExLokaliseTransfer.Downloader.AsyncTest do
  use ExLokaliseTransfer.Case, async: false

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader.Async
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.LokaliseFilesMock
  alias ExLokaliseTransfer.PollerMock
  alias ExLokaliseTransfer.RetryMock
  alias ExLokaliseTransfer.TempMock
  alias ExLokaliseTransfer.TransferMock

  setup {ExLokaliseTransfer.Case, :set_downloader_async_dependency_mocks}

  describe "run/1" do
    test "returns :ok when async process completes and bundle is downloaded and extracted" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, retry_opts ->
        assert retry_opts == retry_opts_fixture()
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", data ->
        assert is_map(data)
        assert data[:format] == "json"
        assert data[:original_filenames] == true
        {:ok, %{process_id: "proc-123"}}
      end)

      PollerMock
      |> expect(:wait, fn "project-123", "proc-123", poll_opts ->
        assert poll_opts == poll_opts_fixture()

        {:ok,
         %{
           process_id: "proc-123",
           details: %{"download_url" => "https://s3.example.com/bundle.zip"}
         }}
      end)

      TransferMock
      |> expect(:download_and_extract, fn "https://s3.example.com/bundle.zip",
                                          ^zip_path,
                                          target_dir,
                                          retry_opts ->
        assert target_dir == Path.expand("./priv/locales")
        assert retry_opts == retry_opts_fixture()
        :ok
      end)

      assert :ok =
               Async.run(valid_config())
    end

    test "returns unexpected_response when async request succeeds without valid process_id" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, retry_opts ->
        assert retry_opts == retry_opts_fixture()
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{foo: "bar"}}
      end)

      assert {:error, {:unexpected_response, %{foo: "bar"}}} =
               Async.run(valid_config())
    end

    test "returns unexpected_response when process_id is empty" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{process_id: ""}}
      end)

      assert {:error, {:unexpected_response, %{process_id: ""}}} =
               Async.run(valid_config())
    end

    test "returns retry error when async request fails" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

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

      assert {:error, ^err} = Async.run(valid_config())
    end

    test "returns poller error when queued process does not complete successfully" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{process_id: "proc-123"}}
      end)

      PollerMock
      |> expect(:wait, fn "project-123", "proc-123", poll_opts ->
        assert poll_opts == poll_opts_fixture()
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Async.run(valid_config())
    end

    test "returns missing_download_url when process details map has no download_url" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{process_id: "proc-123"}}
      end)

      PollerMock
      |> expect(:wait, fn "project-123", "proc-123", _poll_opts ->
        {:ok, %{process_id: "proc-123", details: %{}}}
      end)

      assert {:error, {:missing_download_url, "proc-123"}} =
               Async.run(valid_config())
    end

    test "returns missing_download_url when process details map contains blank string download_url" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{process_id: "proc-123"}}
      end)

      PollerMock
      |> expect(:wait, fn "project-123", "proc-123", _poll_opts ->
        {:ok,
         %{
           process_id: "proc-123",
           details: %{"download_url" => "   "}
         }}
      end)

      assert {:error, {:missing_download_url, "proc-123"}} =
               Async.run(valid_config())
    end

    test "accepts atom-keyed map details with download_url" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{process_id: "proc-123"}}
      end)

      PollerMock
      |> expect(:wait, fn "project-123", "proc-123", _poll_opts ->
        {:ok,
         %{
           process_id: "proc-123",
           details: %{download_url: "https://s3.example.com/bundle.zip"}
         }}
      end)

      TransferMock
      |> expect(:download_and_extract, fn "https://s3.example.com/bundle.zip",
                                          ^zip_path,
                                          _target_dir,
                                          _retry_opts ->
        :ok
      end)

      assert :ok = Async.run(valid_config())
    end

    test "accepts keyword-list details with download_url" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{process_id: "proc-123"}}
      end)

      PollerMock
      |> expect(:wait, fn "project-123", "proc-123", _poll_opts ->
        {:ok,
         %{
           process_id: "proc-123",
           details: [download_url: "https://s3.example.com/bundle.zip"]
         }}
      end)

      TransferMock
      |> expect(:download_and_extract, fn "https://s3.example.com/bundle.zip",
                                          ^zip_path,
                                          _target_dir,
                                          _retry_opts ->
        :ok
      end)

      assert :ok = Async.run(valid_config())
    end

    test "returns transfer error when bundle download and extraction fails" do
      zip_path = unique_tmp_zip_path()

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      RetryMock
      |> expect(:run, fn fun, :lokalise, _retry_opts ->
        fun.()
      end)

      LokaliseFilesMock
      |> expect(:download_async, fn "project-123", _data ->
        {:ok, %{process_id: "proc-123"}}
      end)

      PollerMock
      |> expect(:wait, fn "project-123", "proc-123", _poll_opts ->
        {:ok,
         %{
           process_id: "proc-123",
           details: %{"download_url" => "https://s3.example.com/bundle.zip"}
         }}
      end)

      TransferMock
      |> expect(:download_and_extract, fn "https://s3.example.com/bundle.zip",
                                          ^zip_path,
                                          _target_dir,
                                          _retry_opts ->
        {:error, {:http_error, 404, "not found"}}
      end)

      assert {:error, {:http_error, 404, "not found"}} =
               Async.run(valid_config())
    end

    test "removes temp zip path in after block" do
      zip_path = unique_tmp_zip_path()
      File.write!(zip_path, "stale zip")

      TempMock
      |> expect(:temp_zip_path, fn :async -> zip_path end)

      err = %Error{
        source: :lokalise,
        kind: :http,
        status: 500,
        code: nil,
        message: "boom"
      }

      RetryMock
      |> expect(:run, fn _fun, :lokalise, _retry_opts ->
        {:error, err}
      end)

      assert {:error, ^err} = Async.run(valid_config())

      refute File.exists?(zip_path)
    end
  end

  defp valid_config do
    %Config{
      project_id: "project-123",
      body: [
        format: "json",
        original_filenames: true
      ],
      retry: retry_opts_fixture(),
      poll: poll_opts_fixture(),
      extra: [extract_to: "./priv/locales"]
    }
  end

  defp retry_opts_fixture do
    [
      max_attempts: 3,
      min_sleep_ms: 1_000,
      max_sleep_ms: 60_000,
      jitter: :centered
    ]
  end

  defp poll_opts_fixture do
    [
      max_attempts: 5,
      min_sleep_ms: 1_000,
      max_sleep_ms: 5_000,
      jitter: :centered
    ]
  end

  defp unique_tmp_zip_path do
    Path.join(
      System.tmp_dir!(),
      "ex_lokalise_transfer_async_test_#{System.unique_integer([:positive, :monotonic])}.zip"
    )
  end
end
