defmodule ExLokaliseTransfer.Integration.DownloaderAsyncTest do
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

      original_project_id = Application.get_env(:ex_lokalise_transfer, :project_id)

      original_downloader_async_module =
        Application.get_env(:ex_lokalise_transfer, :downloader_async_module)

      Application.put_env(:elixir_lokalise_api, :api_token, api_token)

      # Let the SDK use its real default client instead of the Mox mock
      Application.delete_env(:elixir_lokalise_api, :http_client)

      Application.put_env(:ex_lokalise_transfer, :project_id, project_id)
      Application.delete_env(:ex_lokalise_transfer, :downloader_async_module)

      on_exit(fn ->
        restore_env(:elixir_lokalise_api, :api_token, original_api_token)
        restore_env(:elixir_lokalise_api, :http_client, original_http_client)
        restore_env(:ex_lokalise_transfer, :project_id, original_project_id)

        restore_env(
          :ex_lokalise_transfer,
          :downloader_async_module,
          original_downloader_async_module
        )
      end)

      {:ok, project_id: project_id}
    end
  end

  test "downloads and extracts Lokalise bundle asynchronously", %{project_id: project_id} do
    extract_to = make_tmp_dir!("downloader_async_integration")

    on_exit(fn ->
      File.rm_rf!(extract_to)
    end)

    assert :ok =
             ExLokaliseTransfer.download_async(
               project_id: project_id,
               body: [
                 format: "json",
                 original_filenames: false
               ],
               retry: [
                 max_attempts: 3,
                 min_sleep_ms: 1_000,
                 max_sleep_ms: 10_000,
                 jitter: :centered
               ],
               poll: [
                 max_attempts: 15,
                 min_sleep_ms: 3_000,
                 max_sleep_ms: 60_000,
                 jitter: :centered
               ],
               extra: [
                 extract_to: extract_to
               ]
             )

    all_files = list_files_recursive!(extract_to)

    refute all_files == []

    json_files =
      Enum.filter(all_files, fn path ->
        Path.extname(path) == ".json"
      end)

    refute json_files == []

    en_json =
      Enum.find(json_files, fn path ->
        Path.basename(path) == "en.json"
      end)

    assert is_binary(en_json), """
    Expected extracted bundle to contain en.json, got files:
    #{Enum.map_join(json_files, "\n", &Path.relative_to(&1, extract_to))}
    """

    en_content = File.read!(en_json)
    refute String.trim(en_content) == ""

    assert {:ok, decoded} = Jason.decode(en_content)
    assert is_map(decoded)
    refute map_size(decoded) == 0
  end

  defp list_files_recursive!(root) do
    root
    |> do_list_files_recursive()
    |> Enum.sort()
  end

  defp do_list_files_recursive(path) do
    case File.ls!(path) do
      [] ->
        []

      entries ->
        Enum.flat_map(entries, fn entry ->
          full_path = Path.join(path, entry)

          if File.dir?(full_path) do
            do_list_files_recursive(full_path)
          else
            [full_path]
          end
        end)
    end
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

    File.rm_rf!(path)
    File.mkdir_p!(path)
    path
  end
end
