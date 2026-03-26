defmodule ExLokaliseTransfer.ConfigTest do
  use ExLokaliseTransfer.Case, async: false

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
  end

  describe "build/2 – project_id precedence" do
    test "opts project_id overrides app env project_id" do
      original = Application.get_env(:ex_lokalise_transfer, :project_id)

      Application.put_env(:ex_lokalise_transfer, :project_id, "from_env")

      on_exit(fn -> restore_env(:ex_lokalise_transfer, :project_id, original) end)

      config = Config.build(project_id: "from_opts")

      assert config.project_id == "from_opts"
    end

    test "raises when app env uses {:system, env} and system variable is missing" do
      original = Application.get_env(:ex_lokalise_transfer, :project_id)
      original_env = System.get_env("LOKALISE_PROJECT_ID")

      Application.put_env(:ex_lokalise_transfer, :project_id, {:system, "LOKALISE_PROJECT_ID"})
      System.delete_env("LOKALISE_PROJECT_ID")

      on_exit(fn ->
        restore_env(:ex_lokalise_transfer, :project_id, original)
        restore_system_env("LOKALISE_PROJECT_ID", original_env)
      end)

      assert_raise RuntimeError, ~r/project_id.*required/i, fn ->
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

  describe "build/2 – extra and poll" do
    test "extra defaults to empty list and poll defaults to nil" do
      config = Config.build(project_id: "pid")

      assert config.extra == []
      assert config.poll == nil
    end

    test "extra comes from opts when provided" do
      config =
        Config.build(
          project_id: "pid",
          extra: [locales_path: "./priv/locales"]
        )

      assert config.extra == [locales_path: "./priv/locales"]
    end

    test "extra is merged with defaults (opts override defaults)" do
      default_opts = [
        extra: [locales_path: "./priv/locales", unzip?: true]
      ]

      opts = [
        project_id: "pid",
        extra: [unzip?: false]
      ]

      config = Config.build(opts, default_opts)

      assert Enum.sort(config.extra) ==
               Enum.sort(locales_path: "./priv/locales", unzip?: false)
    end

    test "poll stays nil when missing in both defaults and opts" do
      config = Config.build(project_id: "pid")

      assert config.poll == nil
    end

    test "poll comes from defaults when missing in opts" do
      default_opts = [
        poll: [max_attempts: 10, min_sleep_ms: 500, max_sleep_ms: 5_000, jitter: :full]
      ]

      config = Config.build([project_id: "pid"], default_opts)

      assert config.poll == [
               max_attempts: 10,
               min_sleep_ms: 500,
               max_sleep_ms: 5_000,
               jitter: :full
             ]
    end

    test "poll comes from opts when missing in defaults" do
      config =
        Config.build(
          [
            project_id: "pid",
            poll: [max_attempts: 7, min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :centered]
          ],
          []
        )

      assert config.poll == [
               max_attempts: 7,
               min_sleep_ms: 100,
               max_sleep_ms: 1_000,
               jitter: :centered
             ]
    end

    test "poll is merged with defaults (opts override defaults)" do
      default_opts = [
        poll: [max_attempts: 10, min_sleep_ms: 500, max_sleep_ms: 5_000, jitter: :full]
      ]

      opts = [
        project_id: "pid",
        poll: [max_attempts: 20, jitter: :centered]
      ]

      config = Config.build(opts, default_opts)

      assert Enum.sort(config.poll) ==
               Enum.sort(
                 max_attempts: 20,
                 min_sleep_ms: 500,
                 max_sleep_ms: 5_000,
                 jitter: :centered
               )
    end
  end

  describe "build/2 – build does not validate shapes" do
    test "build allows non-binary project_id from env and leaves validation to validate_common/1" do
      original = Application.get_env(:ex_lokalise_transfer, :project_id)

      Application.put_env(:ex_lokalise_transfer, :project_id, 123)

      on_exit(fn -> restore_env(:ex_lokalise_transfer, :project_id, original) end)

      config = Config.build()

      assert config.project_id == 123
      assert {:error, {:invalid, :project_id, :not_binary}} = Config.validate_common(config)
    end
  end

  describe "build/2 – invalid merged option shapes" do
    test "raises when body is not a keyword list" do
      assert_raise FunctionClauseError, fn ->
        Config.build(project_id: "pid", body: :oops)
      end
    end

    test "raises when extra is not a keyword list" do
      assert_raise FunctionClauseError, fn ->
        Config.build(project_id: "pid", extra: :oops)
      end
    end

    test "raises when retry is not a keyword list" do
      assert_raise FunctionClauseError, fn ->
        Config.build(project_id: "pid", retry: :oops)
      end
    end

    test "raises when poll is not a keyword list" do
      assert_raise FunctionClauseError, fn ->
        Config.build(project_id: "pid", poll: :oops)
      end
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
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ]
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
        retry: [min_sleep_ms: 1_000, max_sleep_ms: 60_000, jitter: :centered]
      }

      assert {:error, {:invalid, :max_attempts, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when max_attempts is not an integer" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: "3", min_sleep_ms: 1_000, max_sleep_ms: 60_000, jitter: :centered]
      }

      assert {:error, {:invalid, :max_attempts, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when max_attempts is less than 1" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 0, min_sleep_ms: 1_000, max_sleep_ms: 60_000, jitter: :centered]
      }

      assert {:error, {:invalid, :max_attempts, {:lt, 1}}} =
               Config.validate_common(config)
    end

    test "fails when min_sleep_ms is missing" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, max_sleep_ms: 60_000, jitter: :centered]
      }

      assert {:error, {:invalid, :min_sleep_ms, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when min_sleep_ms is not an integer" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: "1000", max_sleep_ms: 60_000, jitter: :centered]
      }

      assert {:error, {:invalid, :min_sleep_ms, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when min_sleep_ms is negative" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: -1, max_sleep_ms: 60_000, jitter: :centered]
      }

      assert {:error, {:invalid, :min_sleep_ms, {:lt, 0}}} =
               Config.validate_common(config)
    end

    test "fails when max_sleep_ms is missing" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 1_000, jitter: :centered]
      }

      assert {:error, {:invalid, :max_sleep_ms, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when max_sleep_ms is not an integer" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 1_000, max_sleep_ms: "60000", jitter: :centered]
      }

      assert {:error, {:invalid, :max_sleep_ms, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when max_sleep_ms is negative" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 1_000, max_sleep_ms: -1, jitter: :centered]
      }

      assert {:error, {:invalid, :max_sleep_ms, {:lt, 0}}} =
               Config.validate_common(config)
    end

    test "fails when min_sleep_ms is greater than max_sleep_ms" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 10_000, max_sleep_ms: 1_000, jitter: :centered]
      }

      assert {:error, {:invalid, :retry, :min_sleep_gt_max_sleep}} =
               Config.validate_common(config)
    end

    test "fails when jitter is invalid" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 1_000, max_sleep_ms: 60_000, jitter: :wat]
      }

      assert {:error, {:invalid, :retry, {:invalid_jitter, :wat}}} =
               Config.validate_common(config)
    end
  end

  describe "validate_common/1 – body and extra" do
    test "returns :ok when body and extra are valid keyword lists" do
      config = %Config{
        project_id: "proj_123",
        body: [format: "json"],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        extra: [locales_path: "./priv/locales"]
      }

      assert :ok == Config.validate_common(config)
    end

    test "returns :ok when body is nil" do
      config = %Config{
        project_id: "proj_123",
        body: nil,
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        extra: []
      }

      assert :ok == Config.validate_common(config)
    end

    test "returns :ok when extra is nil" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        extra: nil
      }

      assert :ok == Config.validate_common(config)
    end

    test "fails when body is not a keyword list" do
      config = %Config{
        project_id: "proj_123",
        body: :oops,
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        extra: []
      }

      assert {:error, {:invalid, :body, :not_keyword}} =
               Config.validate_common(config)
    end

    test "fails when body is a plain list but not a keyword list" do
      config = %Config{
        project_id: "proj_123",
        body: [1, 2, 3],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        extra: []
      }

      assert {:error, {:invalid, :body, :not_keyword}} =
               Config.validate_common(config)
    end

    test "fails when extra is not a keyword list" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        extra: :oops
      }

      assert {:error, {:invalid, :extra, :not_keyword}} =
               Config.validate_common(config)
    end

    test "fails when extra is a plain list but not a keyword list" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        extra: [1, 2, 3]
      }

      assert {:error, {:invalid, :extra, :not_keyword}} =
               Config.validate_common(config)
    end
  end

  describe "validate_common/1 – poll" do
    test "returns :ok when poll is nil" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: nil,
        extra: []
      }

      assert :ok == Config.validate_common(config)
    end

    test "returns :ok for valid poll options" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: [
          max_attempts: 10,
          min_sleep_ms: 500,
          max_sleep_ms: 5_000,
          jitter: :full
        ],
        extra: []
      }

      assert :ok == Config.validate_common(config)
    end

    test "fails when poll is not a keyword list" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: :oops,
        extra: []
      }

      assert {:error, {:invalid, :poll, :not_keyword}} =
               Config.validate_common(config)
    end

    test "fails when poll max_attempts is missing" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: [min_sleep_ms: 500, max_sleep_ms: 5_000, jitter: :centered],
        extra: []
      }

      assert {:error, {:invalid, :max_attempts, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when poll min_sleep_ms is missing" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: [max_attempts: 10, max_sleep_ms: 5_000, jitter: :centered],
        extra: []
      }

      assert {:error, {:invalid, :min_sleep_ms, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when poll max_sleep_ms is missing" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: [max_attempts: 10, min_sleep_ms: 500, jitter: :centered],
        extra: []
      }

      assert {:error, {:invalid, :max_sleep_ms, :not_integer}} =
               Config.validate_common(config)
    end

    test "fails when poll jitter is invalid" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: [max_attempts: 10, min_sleep_ms: 500, max_sleep_ms: 5_000, jitter: :wat],
        extra: []
      }

      assert {:error, {:invalid, :poll, {:invalid_jitter, :wat}}} =
               Config.validate_common(config)
    end

    test "fails when poll min_sleep_ms is greater than max_sleep_ms" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :centered
        ],
        poll: [max_attempts: 10, min_sleep_ms: 10_000, max_sleep_ms: 1_000, jitter: :centered],
        extra: []
      }

      assert {:error, {:invalid, :poll, :min_sleep_gt_max_sleep}} =
               Config.validate_common(config)
    end
  end

  describe "validate_common/1 – retry boundaries and allowed values" do
    test "returns :ok when max_attempts is 1" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 1, min_sleep_ms: 1_000, max_sleep_ms: 60_000, jitter: :centered],
        extra: []
      }

      assert :ok == Config.validate_common(config)
    end

    test "returns :ok when min_sleep_ms equals max_sleep_ms" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 1_000, max_sleep_ms: 1_000, jitter: :centered],
        extra: []
      }

      assert :ok == Config.validate_common(config)
    end

    test "returns :ok when min_sleep_ms and max_sleep_ms are zero" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 0, max_sleep_ms: 0, jitter: :full],
        extra: []
      }

      assert :ok == Config.validate_common(config)
    end

    test "returns :ok when jitter is :full" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [max_attempts: 3, min_sleep_ms: 1_000, max_sleep_ms: 60_000, jitter: :full],
        extra: []
      }

      assert :ok == Config.validate_common(config)
    end

    test "returns :ok when retry contains extra unknown keys" do
      config = %Config{
        project_id: "proj_123",
        body: [],
        retry: [
          max_attempts: 3,
          min_sleep_ms: 1_000,
          max_sleep_ms: 60_000,
          jitter: :full,
          foo: :bar
        ],
        extra: []
      }

      assert :ok == Config.validate_common(config)
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
