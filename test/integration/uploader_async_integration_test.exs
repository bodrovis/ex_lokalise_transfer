defmodule ExLokaliseTransfer.Integration.UploaderAsyncTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  setup do
    api_token = System.get_env("LOKALISE_API_TOKEN")
    project_id = System.get_env("LOKALISE_PROJECT_ID")

    if blank?(api_token) or blank?(project_id) do
      {:skip, "Missing LOKALISE_API_TOKEN or LOKALISE_PROJECT_ID"}
    else
      original_api_token = Application.get_env(:elixir_lokalise_api, :api_token)
      original_http_client = Application.get_env(:elixir_lokalise_api, :http_client)

      Application.put_env(:elixir_lokalise_api, :api_token, api_token)

      # Let the SDK use its real default client instead of the Mox mock
      Application.delete_env(:elixir_lokalise_api, :http_client)

      on_exit(fn ->
        restore_env(:elixir_lokalise_api, :api_token, original_api_token)
        restore_env(:elixir_lokalise_api, :http_client, original_http_client)
      end)

      {:ok, project_id: project_id}
    end
  end

  test "uploads multiple locale files asynchronously to Lokalise", %{project_id: project_id} do
    tmp_dir = make_tmp_dir!("uploader_async_integration")

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    write_json!(Path.join(tmp_dir, "en.json"), %{"hello" => "Hello"})
    write_json!(Path.join(tmp_dir, "fr.json"), %{"hello" => "Bonjour"})
    write_json!(Path.join(tmp_dir, "de.json"), %{"hello" => "Hallo"})

    assert {:ok, summary} =
             ExLokaliseTransfer.upload(
               project_id: project_id,
               body: [format: "json"],
               extra: [
                 locales_path: tmp_dir,
                 include_patterns: ["*.json"],
                 exclude_patterns: [],
                 lang_resolver: :basename
               ],
               poll: [
                 max_attempts: 10,
                 min_sleep_ms: 3_000,
                 max_sleep_ms: 60_000,
                 jitter: :centered
               ]
             )

    assert length(summary.discovered_entries) == 3
    assert length(summary.enqueue_successes) == 3
    assert summary.enqueue_errors == []
    assert length(summary.process_results) == 3
    assert summary.errors == []

    assert Enum.all?(summary.process_results, fn %{result: result} ->
             match?({:ok, _}, result)
           end)
  end

  defp blank?(v), do: is_nil(v) or String.trim(v) == ""

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)

  defp make_tmp_dir!(prefix) do
    path =
      System.tmp_dir!()
      |> Path.join("ex_lokalise_transfer")
      |> Path.join("#{prefix}_#{System.unique_integer([:positive])}")
      |> Path.expand()

    File.mkdir_p!(path)
    path
  end

  defp write_json!(path, data) do
    File.write!(path, Jason.encode!(data))
  end
end
