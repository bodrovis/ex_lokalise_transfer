defmodule ExLokaliseTransfer.ConfigTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Config

  describe "build/2 – project_id" do
    test "uses project_id from opts when provided" do
      config = Config.build(project_id: "from_opts")

      assert config.project_id == "from_opts"
    end

    test "uses project_id from app env when opts are missing" do
      original = Application.get_env(:ex_lokalise_transfer, :project_id)

      Application.put_env(:ex_lokalise_transfer, :project_id, "from_env")

      on_exit(fn -> restore_env(:ex_lokalise_transfer, :project_id, original) end)

      config = Config.build()

      assert config.project_id == "from_env"
    end

    test "resolves project_id from {:system, \"ENV\"} tuple" do
      original = Application.get_env(:ex_lokalise_transfer, :project_id)
      original_env = System.get_env("LOKALISE_PROJECT_ID")

      Application.put_env(:ex_lokalise_transfer, :project_id, {:system, "LOKALISE_PROJECT_ID"})
      System.put_env("LOKALISE_PROJECT_ID", "from_system_env")

      on_exit(fn ->
        restore_env(:ex_lokalise_transfer, :project_id, original)
        restore_system_env("LOKALISE_PROJECT_ID", original_env)
      end)

      config = Config.build()

      assert config.project_id == "from_system_env"
    end

    test "raises when project_id is missing everywhere" do
      original = Application.get_env(:ex_lokalise_transfer, :project_id)
      Application.delete_env(:ex_lokalise_transfer, :project_id)

      on_exit(fn -> restore_env(:ex_lokalise_transfer, :project_id, original) end)

      assert_raise RuntimeError, fn ->
        Config.build()
      end
    end
  end

  describe "build/2 – body and retry" do
    test "body and retry are empty by default when not provided" do
      config = Config.build(project_id: "pid")

      assert config.body == []
      assert config.retry == []
    end

    test "body and retry come from opts when provided" do
      config =
        Config.build(
          project_id: "pid",
          body: [format: "json"],
          retry: [max_attempts: 3]
        )

      assert config.body == [format: "json"]
      assert config.retry == [max_attempts: 3]
    end

    test "body and retry are merged with defaults (opts override defaults)" do
      default_opts = [
        body: [format: "json", include_tags: true],
        retry: [max_attempts: 3, initial_sleep: 1000]
      ]

      opts = [
        project_id: "pid",
        body: [format: "yaml"],
        retry: [initial_sleep: 2000]
      ]

      config = Config.build(opts, default_opts)

      assert Enum.sort(config.body) == Enum.sort(format: "yaml", include_tags: true)
      assert Enum.sort(config.retry) == Enum.sort(max_attempts: 3, initial_sleep: 2000)
    end
  end

  describe "build/2 – errors" do
    test "raises when project_id is missing everywhere" do
      original_project = Application.get_env(:ex_lokalise_transfer, :project_id)

      # ensure no project_id in app env
      Application.delete_env(:ex_lokalise_transfer, :project_id)

      on_exit(fn ->
        restore_env(:ex_lokalise_transfer, :project_id, original_project)
      end)

      assert_raise RuntimeError, ~r/project_id.*required/i, fn ->
        ExLokaliseTransfer.Config.build()
      end
    end
  end

  describe "validate_common/1" do
    test "returns :ok for a valid config" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3]
      }

      assert :ok == Config.validate_common(config)
    end

    test "fails when project_id is empty" do
      config = %Config{
        project_id: "",
        body: [],
        retry: [max_attempts: 3]
      }

      assert {:error, {:invalid, :project_id, :empty_or_whitespace}} =
               Config.validate_common(config)
    end

    test "fails when project_id is only whitespace" do
      config = %Config{
        project_id: "   ",
        body: [],
        retry: [max_attempts: 3]
      }

      assert {:error, {:invalid, :project_id, :empty_or_whitespace}} =
               Config.validate_common(config)
    end

    test "fails when project_id is not a binary" do
      config = %Config{
        project_id: 123,
        body: [],
        retry: [max_attempts: 3]
      }

      assert {:error, {:invalid, :project_id, :not_binary}} =
               Config.validate_common(config)
    end

    test "fails when retry is not a keyword list" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: :oops
      }

      assert {:error, {:invalid, :retry, :not_keyword}} =
               Config.validate_common(config)
    end

    test "fails when max_attempts is missing (nil)" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: []
      }

      assert {:error, {:invalid, :retry_max_attempts, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when max_attempts is not an integer" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: "3"]
      }

      assert {:error, {:invalid, :retry_max_attempts, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when max_attempts is less than 1" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 0]
      }

      assert {:error, {:invalid, :retry_max_attempts, :lt_1}} =
               Config.validate_common(config)
    end
  end

  # === helpers ===

  defp restore_env(app, key, nil) do
    Application.delete_env(app, key)
  end

  defp restore_env(app, key, value) do
    Application.put_env(app, key, value)
  end

  defp restore_system_env(key, nil) do
    System.delete_env(key)
  end

  defp restore_system_env(key, value) do
    System.put_env(key, value)
  end
end
