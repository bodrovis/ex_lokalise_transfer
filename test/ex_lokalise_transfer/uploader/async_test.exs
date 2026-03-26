defmodule ExLokaliseTransfer.Uploader.AsyncTest do
  use ExLokaliseTransfer.Case, async: false

  setup {ExLokaliseTransfer.Case, :set_uploader_async_dependency_mocks}

  alias ExLokaliseTransfer.BatchPollerMock
  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.LokaliseFilesMock
  alias ExLokaliseTransfer.RetryMock
  alias ExLokaliseTransfer.UploadFilesMock
  alias ExLokaliseTransfer.Uploader.Async
  alias ExLokaliseTransfer.Uploader.Files.Entry

  @project_id "proj_123"

  @retry_opts [
    max_attempts: 3,
    min_sleep_ms: 100,
    max_sleep_ms: 1_000,
    jitter: :centered
  ]

  @poll_opts [
    max_attempts: 3,
    min_sleep_ms: 100,
    max_sleep_ms: 1_000,
    jitter: :centered
  ]

  describe "run/1" do
    test "returns {:ok, summary} when all uploads and processes succeed" do
      file1 = write_tmp_file!("hello")
      file2 = write_tmp_file!("world")

      entry1 = entry(file1, "priv/locales/en.json", "en.json", ".json", "en")
      entry2 = entry(file2, "priv/locales/lv.json", "lv.json", ".json", "lv")

      expect(UploadFilesMock, :discover, 1, fn extra ->
        assert extra == [locales_path: "./priv/locales"]
        {:ok, [entry1, entry2]}
      end)

      expect(RetryMock, :run, 2, fn fun, :lokalise, @retry_opts ->
        fun.()
      end)

      expected_data = %{
        "priv/locales/en.json" => Base.encode64("hello"),
        "priv/locales/lv.json" => Base.encode64("world")
      }

      expected_langs = %{
        "priv/locales/en.json" => "en",
        "priv/locales/lv.json" => "lv"
      }

      process_ids = %{
        "priv/locales/en.json" => "proc_en",
        "priv/locales/lv.json" => "proc_lv"
      }

      expect(LokaliseFilesMock, :upload, 2, fn project_id, payload ->
        assert project_id == @project_id
        assert payload[:format] == "json"
        assert payload[:replace_modified] == true
        assert payload[:filename] in Map.keys(expected_data)
        assert payload[:data] == Map.fetch!(expected_data, payload[:filename])
        assert payload[:lang_iso] == Map.fetch!(expected_langs, payload[:filename])

        {:ok, %{process_id: Map.fetch!(process_ids, payload[:filename])}}
      end)

      expect(BatchPollerMock, :wait_many, 1, fn project_id, ids, poll_opts ->
        assert project_id == @project_id
        assert ids == ["proc_en", "proc_lv"]
        assert poll_opts == @poll_opts

        [
          {"proc_en", {:ok, %{status: "finished"}}},
          {"proc_lv", {:ok, %{status: "finished"}}}
        ]
      end)

      config =
        config(
          body: [format: "json", replace_modified: true],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:ok, summary} = Async.run(config)

      assert summary.discovered_entries == [entry1, entry2]

      assert summary.enqueue_successes == [
               %{entry: entry1, process_id: "proc_en"},
               %{entry: entry2, process_id: "proc_lv"}
             ]

      assert summary.enqueue_errors == []

      assert summary.process_results == [
               %{entry: entry1, process_id: "proc_en", result: {:ok, %{status: "finished"}}},
               %{entry: entry2, process_id: "proc_lv", result: {:ok, %{status: "finished"}}}
             ]

      assert summary.errors == []
    end

    test "returns {:error, reason} when discovery fails" do
      expect(UploadFilesMock, :discover, 1, fn extra ->
        assert extra == [locales_path: "./priv/locales"]
        {:error, {:locales_path_not_found, "/missing"}}
      end)

      config =
        config(
          body: [format: "json"],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:error, {:locales_path_not_found, "/missing"}} = Async.run(config)
    end

    test "returns {:ok, summary} with empty results when no entries are discovered" do
      expect(UploadFilesMock, :discover, 1, fn _extra ->
        {:ok, []}
      end)

      config =
        config(
          body: [format: "json"],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:ok, summary} = Async.run(config)

      assert summary.discovered_entries == []
      assert summary.enqueue_successes == []
      assert summary.enqueue_errors == []
      assert summary.process_results == []
      assert summary.errors == []
    end

    test "returns {:error, summary} when one file cannot be read" do
      missing_path = unique_tmp_path("missing_file")
      existing_path = write_tmp_file!("ok")

      missing_entry = entry(missing_path, "priv/locales/en.json", "en.json", ".json", "en")
      good_entry = entry(existing_path, "priv/locales/lv.json", "lv.json", ".json", "lv")

      expect(UploadFilesMock, :discover, 1, fn _extra ->
        {:ok, [missing_entry, good_entry]}
      end)

      expect(RetryMock, :run, 1, fn fun, :lokalise, @retry_opts ->
        fun.()
      end)

      expect(LokaliseFilesMock, :upload, 1, fn @project_id, payload ->
        assert payload[:filename] == "priv/locales/lv.json"
        assert payload[:lang_iso] == "lv"
        {:ok, %{process_id: "proc_lv"}}
      end)

      expect(BatchPollerMock, :wait_many, 1, fn @project_id, ["proc_lv"], @poll_opts ->
        [{"proc_lv", {:ok, %{status: "finished"}}}]
      end)

      config =
        config(
          body: [],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:error, summary} = Async.run(config)

      assert summary.discovered_entries == [missing_entry, good_entry]

      assert summary.enqueue_successes == [
               %{entry: good_entry, process_id: "proc_lv"}
             ]

      assert summary.enqueue_errors == [
               %{
                 entry: missing_entry,
                 error: {:file_read_failed, missing_path, :enoent}
               }
             ]

      assert summary.process_results == [
               %{entry: good_entry, process_id: "proc_lv", result: {:ok, %{status: "finished"}}}
             ]

      assert summary.errors == [
               {:enqueue_error, "priv/locales/en.json",
                {:file_read_failed, missing_path, :enoent}}
             ]
    end

    test "returns {:error, summary} when upload response is unexpected" do
      file_path = write_tmp_file!("hello")
      entry1 = entry(file_path, "priv/locales/en.json", "en.json", ".json", "en")

      expect(UploadFilesMock, :discover, 1, fn _extra ->
        {:ok, [entry1]}
      end)

      expect(RetryMock, :run, 1, fn fun, :lokalise, @retry_opts ->
        fun.()
      end)

      expect(LokaliseFilesMock, :upload, 1, fn @project_id, payload ->
        assert payload[:filename] == "priv/locales/en.json"
        {:ok, %{foo: "bar"}}
      end)

      config =
        config(
          body: [format: "json"],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:error, summary} = Async.run(config)

      assert summary.discovered_entries == [entry1]
      assert summary.enqueue_successes == []
      assert summary.process_results == []

      assert summary.enqueue_errors == [
               %{entry: entry1, error: {:unexpected_response, %{foo: "bar"}}}
             ]

      assert summary.errors == [
               {:enqueue_error, "priv/locales/en.json", {:unexpected_response, %{foo: "bar"}}}
             ]
    end

    test "returns {:error, summary} when a queued process later fails" do
      file1 = write_tmp_file!("hello")
      file2 = write_tmp_file!("world")

      entry1 = entry(file1, "priv/locales/en.json", "en.json", ".json", "en")
      entry2 = entry(file2, "priv/locales/lv.json", "lv.json", ".json", "lv")

      expect(UploadFilesMock, :discover, 1, fn _extra ->
        {:ok, [entry1, entry2]}
      end)

      expect(RetryMock, :run, 2, fn fun, :lokalise, @retry_opts ->
        fun.()
      end)

      process_ids = %{
        "priv/locales/en.json" => "proc_en",
        "priv/locales/lv.json" => "proc_lv"
      }

      expect(LokaliseFilesMock, :upload, 2, fn @project_id, payload ->
        {:ok, %{process_id: Map.fetch!(process_ids, payload[:filename])}}
      end)

      expect(BatchPollerMock, :wait_many, 1, fn @project_id, ["proc_en", "proc_lv"], @poll_opts ->
        [
          {"proc_en", {:ok, %{status: "finished"}}},
          {"proc_lv", {:error, {:process_failed, %{status: "failed"}}}}
        ]
      end)

      config =
        config(
          body: [],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:error, summary} = Async.run(config)

      assert summary.enqueue_errors == []

      assert summary.process_results == [
               %{entry: entry1, process_id: "proc_en", result: {:ok, %{status: "finished"}}},
               %{
                 entry: entry2,
                 process_id: "proc_lv",
                 result: {:error, {:process_failed, %{status: "failed"}}}
               }
             ]

      assert summary.errors == [
               {:process_error, "priv/locales/lv.json", "proc_lv",
                {:process_failed, %{status: "failed"}}}
             ]
    end

    test "does not call batch poller when nothing was enqueued successfully" do
      file1 = write_tmp_file!("hello")
      entry1 = entry(file1, "priv/locales/en.json", "en.json", ".json", "en")

      expect(UploadFilesMock, :discover, 1, fn _extra ->
        {:ok, [entry1]}
      end)

      expect(RetryMock, :run, 1, fn fun, :lokalise, @retry_opts ->
        fun.()
      end)

      expect(LokaliseFilesMock, :upload, 1, fn @project_id, _payload ->
        {:ok, %{unexpected: true}}
      end)

      config =
        config(
          body: [],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:error, summary} = Async.run(config)

      assert summary.enqueue_successes == []
      assert summary.process_results == []
    end

    test "returns {:error, summary} when upload request returns retry error" do
      file_path = write_tmp_file!("hello")
      entry1 = entry(file_path, "priv/locales/en.json", "en.json", ".json", "en")

      err = %ExLokaliseTransfer.Errors.Error{
        source: :lokalise,
        kind: :http,
        status: 429,
        code: nil,
        message: "rate limited"
      }

      expect(UploadFilesMock, :discover, 1, fn _extra ->
        {:ok, [entry1]}
      end)

      expect(RetryMock, :run, 1, fn _fun, :lokalise, @retry_opts ->
        {:error, err}
      end)

      config =
        config(
          body: [format: "json"],
          extra: [locales_path: "./priv/locales"],
          retry: @retry_opts,
          poll: @poll_opts
        )

      assert {:error, summary} = Async.run(config)

      assert summary.discovered_entries == [entry1]
      assert summary.enqueue_successes == []
      assert summary.process_results == []

      assert summary.enqueue_errors == [
               %{entry: entry1, error: err}
             ]

      assert summary.errors == [
               {:enqueue_error, "priv/locales/en.json", err}
             ]
    end
  end

  defp config(overrides) do
    struct!(
      Config,
      Keyword.merge(
        [
          project_id: @project_id,
          body: [],
          retry: @retry_opts,
          poll: @poll_opts,
          extra: [locales_path: "./priv/locales"]
        ],
        overrides
      )
    )
  end

  defp entry(abs_path, rel_path, basename, ext, lang_iso) do
    %Entry{
      abs_path: abs_path,
      rel_path: rel_path,
      basename: basename,
      ext: ext,
      lang_iso: lang_iso
    }
  end

  defp write_tmp_file!(contents) do
    path = unique_tmp_path("upload_file")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end

  defp unique_tmp_path(prefix) do
    System.tmp_dir!()
    |> Path.join("ex_lokalise_transfer")
    |> Path.join("#{prefix}_#{System.unique_integer([:positive])}")
    |> Path.expand()
  end
end
