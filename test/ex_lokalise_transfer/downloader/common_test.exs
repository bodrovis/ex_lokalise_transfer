defmodule ExLokaliseTransfer.Downloader.CommonTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader.Common

  describe "default_opts/0" do
    test "returns expected downloader defaults" do
      opts = Common.default_opts()

      assert Keyword.get(opts, :body) == [
               format: "json",
               original_filenames: true,
               directory_prefix: "",
               indentation: "2sp"
             ]

      assert Keyword.get(opts, :retry) == [
               max_attempts: 3,
               min_sleep_ms: 1_000,
               max_sleep_ms: 60_000,
               jitter: :centered
             ]

      assert Keyword.get(opts, :poll) == [
               max_attempts: 3,
               min_sleep_ms: 1_000,
               max_sleep_ms: 60_000,
               jitter: :centered
             ]

      assert Keyword.get(opts, :extra) == [
               extract_to: "./"
             ]
    end
  end

  describe "validate/1" do
    test "returns :ok for valid downloader config" do
      assert :ok =
               valid_config()
               |> Common.validate()
    end

    test "returns error when project_id is empty" do
      config = valid_config(project_id: "   ")

      assert {:error, {:invalid, :project_id, :empty_or_whitespace}} =
               Common.validate(config)
    end

    test "returns error when body is not a keyword list" do
      config = valid_config(body: "nope")

      assert {:error, {:invalid, :body, :not_keyword}} =
               Common.validate(config)
    end

    test "returns error when retry opts are invalid" do
      config =
        valid_config(
          retry: [max_attempts: 0, min_sleep_ms: 1_000, max_sleep_ms: 2_000, jitter: :centered]
        )

      assert {:error, {:invalid, :max_attempts, {:lt, 1}}} =
               Common.validate(config)
    end

    test "returns error when poll opts are invalid" do
      config =
        valid_config(
          poll: [max_attempts: 3, min_sleep_ms: 5_000, max_sleep_ms: 1_000, jitter: :centered]
        )

      assert {:error, {:invalid, :poll, :min_sleep_gt_max_sleep}} =
               Common.validate(config)
    end

    test "returns error when extra is not a keyword list" do
      config = valid_config(extra: "nope")

      assert {:error, {:invalid, :extra, :not_keyword}} =
               Common.validate(config)
    end

    test "returns error when body format is missing" do
      config = valid_config(body: [original_filenames: true])

      assert {:error, {:missing, :format}} =
               Common.validate(config)
    end

    test "returns error when body format is empty" do
      config = valid_config(body: [format: "   "])

      assert {:error, {:invalid, :format, :empty_or_whitespace}} =
               Common.validate(config)
    end

    test "returns error when body format is not a binary" do
      config = valid_config(body: [format: 123])

      assert {:error, {:invalid, :format, :not_binary}} =
               Common.validate(config)
    end

    test "returns error when extract_to is missing" do
      config = valid_config(extra: [])

      assert {:error, {:missing, :extract_to}} =
               Common.validate(config)
    end

    test "returns error when extract_to is empty" do
      config = valid_config(extra: [extract_to: "   "])

      assert {:error, {:invalid, :extract_to, :empty_or_whitespace}} =
               Common.validate(config)
    end

    test "returns error when extract_to is not a binary" do
      config = valid_config(extra: [extract_to: 123])

      assert {:error, {:invalid, :extract_to, :not_binary}} =
               Common.validate(config)
    end
  end

  describe "resolve_extract_to/1" do
    test "expands extract_to path" do
      extra = [extract_to: "./priv/locales"]

      assert Common.resolve_extract_to(extra) ==
               Path.expand("./priv/locales")
    end

    test "raises when extract_to is missing" do
      assert_raise KeyError, fn ->
        Common.resolve_extract_to([])
      end
    end
  end

  defp valid_config(overrides \\ []) do
    base = %Config{
      project_id: "project-id-123",
      body: [
        format: "json",
        original_filenames: true,
        directory_prefix: "",
        indentation: "2sp"
      ],
      retry: [
        max_attempts: 3,
        min_sleep_ms: 1_000,
        max_sleep_ms: 60_000,
        jitter: :centered
      ],
      poll: [
        max_attempts: 3,
        min_sleep_ms: 1_000,
        max_sleep_ms: 60_000,
        jitter: :centered
      ],
      extra: [
        extract_to: "./"
      ]
    }

    struct!(base, overrides)
  end
end
