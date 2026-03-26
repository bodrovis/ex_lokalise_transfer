defmodule ExLokaliseTransfer.Uploader.CommonTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Uploader.Common

  describe "default_opts/0" do
    test "returns expected default sections" do
      opts = Common.default_opts()

      assert Keyword.has_key?(opts, :body)
      assert Keyword.has_key?(opts, :retry)
      assert Keyword.has_key?(opts, :poll)
      assert Keyword.has_key?(opts, :extra)
    end

    test "returns expected retry and poll defaults" do
      opts = Common.default_opts()

      assert Keyword.fetch!(opts, :retry) == [
               max_attempts: 3,
               min_sleep_ms: 1_000,
               max_sleep_ms: 60_000,
               jitter: :centered
             ]

      assert Keyword.fetch!(opts, :poll) == [
               max_attempts: 3,
               min_sleep_ms: 1_000,
               max_sleep_ms: 60_000,
               jitter: :centered
             ]
    end

    test "returns expected extra defaults" do
      opts = Common.default_opts()

      assert Keyword.fetch!(opts, :extra) == [
               locales_path: "./locales",
               include_patterns: ["**/*"],
               exclude_patterns: [],
               lang_resolver: :basename
             ]
    end
  end

  describe "validate/1" do
    test "returns :ok for a valid uploader config" do
      config = valid_config()

      assert :ok == Common.validate(config)
    end

    test "returns error from Config.validate_common/1 for invalid project_id" do
      config = %Config{
        project_id: "",
        body: [],
        retry: valid_backoff_opts(),
        poll: valid_backoff_opts(),
        extra: valid_extra()
      }

      assert {:error, {:invalid, :project_id, :empty_or_whitespace}} =
               Common.validate(config)
    end

    test "returns :ok when lang_resolver is :basename" do
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, :basename))

      assert :ok == Common.validate(config)
    end

    test "returns :ok when lang_resolver is a function of arity 1" do
      resolver = fn _entry -> "en" end
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, resolver))

      assert :ok == Common.validate(config)
    end

    test "returns :ok when lang_resolver is an MFA tuple" do
      resolver = {String, :trim, []}
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, resolver))

      assert :ok == Common.validate(config)
    end
  end

  describe "validate/1 – locales_path" do
    test "returns error when locales_path is missing" do
      extra = Keyword.delete(valid_extra(), :locales_path)
      config = valid_config(extra: extra)

      assert {:error, {:missing, :locales_path}} = Common.validate(config)
    end

    test "returns error when locales_path is an empty string" do
      config = valid_config(extra: Keyword.put(valid_extra(), :locales_path, ""))

      assert {:error, {:invalid, :locales_path, :empty_or_whitespace}} =
               Common.validate(config)
    end

    test "returns error when locales_path is whitespace only" do
      config = valid_config(extra: Keyword.put(valid_extra(), :locales_path, "   "))

      assert {:error, {:invalid, :locales_path, :empty_or_whitespace}} =
               Common.validate(config)
    end

    test "returns error when locales_path is not a binary" do
      config = valid_config(extra: Keyword.put(valid_extra(), :locales_path, 123))

      assert {:error, {:invalid, :locales_path, :not_binary}} =
               Common.validate(config)
    end
  end

  describe "validate/1 – include_patterns" do
    test "returns error when include_patterns is missing" do
      extra = Keyword.delete(valid_extra(), :include_patterns)
      config = valid_config(extra: extra)

      assert {:error, {:missing, :include_patterns}} = Common.validate(config)
    end

    test "returns error when include_patterns is not a list" do
      config = valid_config(extra: Keyword.put(valid_extra(), :include_patterns, :oops))

      assert {:error, {:invalid, :include_patterns, :not_list}} =
               Common.validate(config)
    end

    test "returns error when include_patterns contains an empty string" do
      config =
        valid_config(extra: Keyword.put(valid_extra(), :include_patterns, ["**/*", ""]))

      assert {:error, {:invalid, :include_patterns, :must_be_non_empty_string_list}} =
               Common.validate(config)
    end

    test "returns error when include_patterns contains whitespace only string" do
      config =
        valid_config(extra: Keyword.put(valid_extra(), :include_patterns, ["**/*", "   "]))

      assert {:error, {:invalid, :include_patterns, :must_be_non_empty_string_list}} =
               Common.validate(config)
    end

    test "returns error when include_patterns contains non-binary values" do
      config =
        valid_config(extra: Keyword.put(valid_extra(), :include_patterns, ["**/*", 123]))

      assert {:error, {:invalid, :include_patterns, :must_be_non_empty_string_list}} =
               Common.validate(config)
    end

    test "allows empty include_patterns list" do
      config = valid_config(extra: Keyword.put(valid_extra(), :include_patterns, []))

      assert :ok == Common.validate(config)
    end
  end

  describe "validate/1 – exclude_patterns" do
    test "returns error when exclude_patterns is missing" do
      extra = Keyword.delete(valid_extra(), :exclude_patterns)
      config = valid_config(extra: extra)

      assert {:error, {:missing, :exclude_patterns}} = Common.validate(config)
    end

    test "returns error when exclude_patterns is not a list" do
      config = valid_config(extra: Keyword.put(valid_extra(), :exclude_patterns, :oops))

      assert {:error, {:invalid, :exclude_patterns, :not_list}} =
               Common.validate(config)
    end

    test "returns error when exclude_patterns contains an empty string" do
      config =
        valid_config(extra: Keyword.put(valid_extra(), :exclude_patterns, ["nested/*", ""]))

      assert {:error, {:invalid, :exclude_patterns, :must_be_non_empty_string_list}} =
               Common.validate(config)
    end

    test "returns error when exclude_patterns contains whitespace only string" do
      config =
        valid_config(extra: Keyword.put(valid_extra(), :exclude_patterns, ["nested/*", "   "]))

      assert {:error, {:invalid, :exclude_patterns, :must_be_non_empty_string_list}} =
               Common.validate(config)
    end

    test "returns error when exclude_patterns contains non-binary values" do
      config =
        valid_config(extra: Keyword.put(valid_extra(), :exclude_patterns, ["nested/*", 123]))

      assert {:error, {:invalid, :exclude_patterns, :must_be_non_empty_string_list}} =
               Common.validate(config)
    end

    test "allows empty exclude_patterns list" do
      config = valid_config(extra: Keyword.put(valid_extra(), :exclude_patterns, []))

      assert :ok == Common.validate(config)
    end
  end

  describe "validate/1 – lang_resolver" do
    test "returns error when lang_resolver is missing" do
      extra = Keyword.delete(valid_extra(), :lang_resolver)
      config = valid_config(extra: extra)

      assert {:error, {:missing, :lang_resolver}} = Common.validate(config)
    end

    test "returns error when lang_resolver is an unsupported atom" do
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, :wat))

      assert {:error, {:invalid, :lang_resolver, :wat}} =
               Common.validate(config)
    end

    test "returns error when lang_resolver is a function with wrong arity" do
      resolver = fn _, _ -> "en" end
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, resolver))

      assert {:error, {:invalid, :lang_resolver, ^resolver}} =
               Common.validate(config)
    end

    test "returns error when lang_resolver MFA tuple has wrong shape" do
      resolver = {String, :trim}
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, resolver))

      assert {:error, {:invalid, :lang_resolver, ^resolver}} =
               Common.validate(config)
    end

    test "returns error when lang_resolver MFA has non-atom module" do
      resolver = {"String", :trim, []}
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, resolver))

      assert {:error, {:invalid, :lang_resolver, ^resolver}} =
               Common.validate(config)
    end

    test "returns error when lang_resolver MFA has non-atom function" do
      resolver = {String, "trim", []}
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, resolver))

      assert {:error, {:invalid, :lang_resolver, ^resolver}} =
               Common.validate(config)
    end

    test "returns error when lang_resolver MFA has non-list args" do
      resolver = {String, :trim, :oops}
      config = valid_config(extra: Keyword.put(valid_extra(), :lang_resolver, resolver))

      assert {:error, {:invalid, :lang_resolver, ^resolver}} =
               Common.validate(config)
    end
  end

  defp valid_config(overrides \\ []) do
    struct!(
      Config,
      Keyword.merge(
        [
          project_id: "proj_123",
          body: [],
          retry: valid_backoff_opts(),
          poll: valid_backoff_opts(),
          extra: valid_extra()
        ],
        overrides
      )
    )
  end

  defp valid_backoff_opts do
    [
      max_attempts: 3,
      min_sleep_ms: 1_000,
      max_sleep_ms: 60_000,
      jitter: :centered
    ]
  end

  defp valid_extra do
    [
      locales_path: "./locales",
      include_patterns: ["**/*"],
      exclude_patterns: [],
      lang_resolver: :basename
    ]
  end
end
