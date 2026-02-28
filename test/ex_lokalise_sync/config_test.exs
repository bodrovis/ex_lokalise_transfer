defmodule ExLokaliseSync.ConfigTest do
  use ExLokaliseSync.Case, async: true

  alias ExLokaliseSync.Config

  describe "build/2 – project_id" do
    test "uses project_id from opts when provided" do
      config = Config.build(project_id: "from_opts", api_token: "token")

      assert config.project_id == "from_opts"
    end

    test "uses project_id from app env when opts are missing" do
      original = Application.get_env(:ex_lokalise_sync, :project_id)

      Application.put_env(:ex_lokalise_sync, :project_id, "from_env")

      on_exit(fn -> restore_env(:ex_lokalise_sync, :project_id, original) end)

      config = Config.build(api_token: "token")

      assert config.project_id == "from_env"
    end

    test "resolves project_id from {:system, \"ENV\"} tuple" do
      original = Application.get_env(:ex_lokalise_sync, :project_id)
      original_env = System.get_env("LOKALISE_PROJECT_ID")

      Application.put_env(:ex_lokalise_sync, :project_id, {:system, "LOKALISE_PROJECT_ID"})
      System.put_env("LOKALISE_PROJECT_ID", "from_system_env")

      on_exit(fn ->
        restore_env(:ex_lokalise_sync, :project_id, original)
        restore_system_env("LOKALISE_PROJECT_ID", original_env)
      end)

      config = Config.build(api_token: "token")

      assert config.project_id == "from_system_env"
    end

    test "raises when project_id is missing everywhere" do
      original = Application.get_env(:ex_lokalise_sync, :project_id)
      Application.delete_env(:ex_lokalise_sync, :project_id)

      on_exit(fn -> restore_env(:ex_lokalise_sync, :project_id, original) end)

      assert_raise RuntimeError, fn ->
        Config.build(api_token: "token")
      end
    end
  end

  describe "build/2 – api_token" do
    test "uses api_token from opts when provided" do
      config = Config.build(project_id: "pid", api_token: "from_opts")

      assert config.api_token == "from_opts"
    end

    test "uses api_token from app env when opts are missing" do
      original = Application.get_env(:ex_lokalise_sync, :api_token)
      Application.put_env(:ex_lokalise_sync, :api_token, "from_env")

      on_exit(fn -> restore_env(:ex_lokalise_sync, :api_token, original) end)

      config = Config.build(project_id: "pid")

      assert config.api_token == "from_env"
    end

    test "resolves api_token from {:system, \"ENV\"} tuple" do
      original = Application.get_env(:ex_lokalise_sync, :api_token)
      original_env = System.get_env("LOKALISE_API_TOKEN")

      Application.put_env(:ex_lokalise_sync, :api_token, {:system, "LOKALISE_API_TOKEN"})
      System.put_env("LOKALISE_API_TOKEN", "from_system_env")

      on_exit(fn ->
        restore_env(:ex_lokalise_sync, :api_token, original)
        restore_system_env("LOKALISE_API_TOKEN", original_env)
      end)

      config = Config.build(project_id: "pid")

      assert config.api_token == "from_system_env"
    end

    test "falls back to SDK api_token when plugin-level token is missing" do
      original_plugin = Application.get_env(:ex_lokalise_sync, :api_token)
      original_sdk = Application.get_env(:elixir_lokalise_api, :api_token)

      Application.delete_env(:ex_lokalise_sync, :api_token)
      Application.put_env(:elixir_lokalise_api, :api_token, "from_sdk")

      on_exit(fn ->
        restore_env(:ex_lokalise_sync, :api_token, original_plugin)
        restore_env(:elixir_lokalise_api, :api_token, original_sdk)
      end)

      config = Config.build(project_id: "pid")

      assert config.api_token == "from_sdk"
    end

    test "raises when api_token is missing everywhere" do
      original_plugin = Application.get_env(:ex_lokalise_sync, :api_token)
      original_sdk = Application.get_env(:elixir_lokalise_api, :api_token)

      Application.delete_env(:ex_lokalise_sync, :api_token)
      Application.delete_env(:elixir_lokalise_api, :api_token)

      on_exit(fn ->
        restore_env(:ex_lokalise_sync, :api_token, original_plugin)
        restore_env(:elixir_lokalise_api, :api_token, original_sdk)
      end)

      assert_raise RuntimeError, fn ->
        Config.build(project_id: "pid")
      end
    end
  end

  describe "build/2 – body and retry" do
    test "body and retry are empty by default when not provided" do
      config = Config.build(project_id: "pid", api_token: "tok")

      assert config.body == []
      assert config.retry == []
    end

    test "body and retry come from opts when provided" do
      config =
        Config.build(
          project_id: "pid",
          api_token: "tok",
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
        api_token: "tok",
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
      original_project = Application.get_env(:ex_lokalise_sync, :project_id)

      # ensure no project_id in app env
      Application.delete_env(:ex_lokalise_sync, :project_id)

      on_exit(fn ->
        restore_env(:ex_lokalise_sync, :project_id, original_project)
      end)

      # we still pass api_token so it does not fail earlier
      assert_raise RuntimeError, ~r/project_id.*required/i, fn ->
        ExLokaliseSync.Config.build(api_token: "some-token")
      end
    end

    test "raises when api_token is missing in opts, plugin env and SDK env" do
      original_plugin_token = Application.get_env(:ex_lokalise_sync, :api_token)
      original_sdk_token = Application.get_env(:elixir_lokalise_api, :api_token)

      # remove both plugin-level and SDK-level tokens
      Application.delete_env(:ex_lokalise_sync, :api_token)
      Application.delete_env(:elixir_lokalise_api, :api_token)

      on_exit(fn ->
        restore_env(:ex_lokalise_sync, :api_token, original_plugin_token)
        restore_env(:elixir_lokalise_api, :api_token, original_sdk_token)
      end)

      # we pass project_id so it does not fail earlier
      assert_raise RuntimeError, ~r/no `api_token` available/i, fn ->
        ExLokaliseSync.Config.build(project_id: "pid-123")
      end
    end
  end

  describe "sdk_api_token" do
    test "returns error when token provider crashes and we hit rescue path" do
      # backup current env
      original_provider = Application.get_env(:ex_lokalise_sync, :token_provider)
      original_plugin_token = Application.get_env(:ex_lokalise_sync, :api_token)
      original_sdk_token = Application.get_env(:elixir_lokalise_api, :api_token)

      # ensure no other token sources interfere
      Application.delete_env(:ex_lokalise_sync, :api_token)
      Application.delete_env(:elixir_lokalise_api, :api_token)
      Application.put_env(:ex_lokalise_sync, :token_provider, ExLokaliseSync.TokenProviderMock)

      on_exit(fn ->
        restore_env(:ex_lokalise_sync, :token_provider, original_provider)
        restore_env(:ex_lokalise_sync, :api_token, original_plugin_token)
        restore_env(:elixir_lokalise_api, :api_token, original_sdk_token)
      end)

      expect(ExLokaliseSync.TokenProviderMock, :api_token, fn ->
        raise "boom"
      end)

      # project_id is present, token must go through provider -> raises -> rescue -> nil
      # then build/2 should raise our "no `api_token` available" error
      assert_raise RuntimeError, ~r/no `api_token` available/i, fn ->
        Config.build(project_id: "pid-123")
      end
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
