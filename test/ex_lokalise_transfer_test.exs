defmodule ExLokaliseTransferTest do
  use ExLokaliseTransfer.Case, async: false

  setup {ExLokaliseTransfer.Case, :set_top_level_runner_mocks}

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.RunnerMock

  test "download_async/1 builds config and delegates to async downloader" do
    expect(RunnerMock, :run, 1, fn %Config{} = config ->
      assert config.project_id == "proj_123"
      assert is_list(config.body)

      assert Keyword.get(config.retry, :max_attempts) == 3
      assert Keyword.get(config.retry, :min_sleep_ms) == 1_000
      assert Keyword.get(config.retry, :max_sleep_ms) == 60_000
      assert Keyword.get(config.retry, :jitter) == :centered

      assert is_list(config.extra)

      {:ok, %{from: :async_downloader}}
    end)

    assert {:ok, %{from: :async_downloader}} =
             ExLokaliseTransfer.download_async(
               project_id: "proj_123",
               extra: [locales_path: "./priv/locales"]
             )
  end

  test "download/1 delegates to sync downloader by default" do
    expect(RunnerMock, :run, 1, fn %Config{} = config ->
      assert config.project_id == "proj_123"
      :ok
    end)

    assert :ok =
             ExLokaliseTransfer.download(
               project_id: "proj_123",
               extra: [locales_path: "./priv/locales"]
             )
  end

  test "download_async/1 returns validation error and does not call runner" do
    assert {:error, {:invalid, :project_id, :empty_or_whitespace}} =
             ExLokaliseTransfer.download_async(
               project_id: "   ",
               extra: [locales_path: "./priv/locales"]
             )
  end

  test "upload/1 builds config and delegates to async uploader" do
    expect(RunnerMock, :run, 1, fn %Config{} = config ->
      assert config.project_id == "proj_123"
      assert config.body == [format: "json"]

      assert Keyword.get(config.retry, :max_attempts) == 3
      assert Keyword.get(config.retry, :min_sleep_ms) == 1_000
      assert Keyword.get(config.retry, :max_sleep_ms) == 60_000
      assert Keyword.get(config.retry, :jitter) == :centered

      assert Keyword.get(config.poll, :max_attempts) == 3
      assert Keyword.get(config.poll, :min_sleep_ms) == 1_000
      assert Keyword.get(config.poll, :max_sleep_ms) == 60_000
      assert Keyword.get(config.poll, :jitter) == :centered

      assert Keyword.get(config.extra, :locales_path) == "./priv/locales"
      assert Keyword.get(config.extra, :include_patterns) == ["**/*"]
      assert Keyword.get(config.extra, :exclude_patterns) == []
      assert Keyword.get(config.extra, :lang_resolver) == :basename

      {:ok, %{from: :async_uploader}}
    end)

    assert {:ok, %{from: :async_uploader}} =
             ExLokaliseTransfer.upload(
               project_id: "proj_123",
               body: [format: "json"],
               extra: [locales_path: "./priv/locales"]
             )
  end

  test "upload/1 returns validation error and does not call runner" do
    assert {:error, {:invalid, :locales_path, :empty_or_whitespace}} =
             ExLokaliseTransfer.upload(
               project_id: "proj_123",
               extra: [locales_path: "   "]
             )
  end
end
