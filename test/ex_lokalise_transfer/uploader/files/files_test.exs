defmodule ExLokaliseTransfer.Uploader.FilesTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Uploader.Files
  alias ExLokaliseTransfer.Uploader.Files.Entry

  describe "resolve_locales_path/1" do
    test "expands locales_path to an absolute path" do
      rel_path = "tmp/uploader_files_test/locales"

      assert Files.resolve_locales_path(locales_path: rel_path) ==
               Path.expand(rel_path)
    end

    test "raises when locales_path is missing" do
      assert_raise KeyError, fn ->
        Files.resolve_locales_path([])
      end
    end
  end

  describe "resolve_langs/2 with :basename" do
    test "resolves lang_iso from file basename without extension" do
      entries = [
        %Entry{
          abs_path: "/tmp/project/priv/locales/en.json",
          rel_path: "priv/locales/en.json",
          basename: "en.json",
          ext: ".json",
          lang_iso: ""
        },
        %Entry{
          abs_path: "/tmp/project/priv/locales/lv.yml",
          rel_path: "priv/locales/lv.yml",
          basename: "lv.yml",
          ext: ".yml",
          lang_iso: ""
        }
      ]

      assert {:ok, resolved} = Files.resolve_langs(entries, :basename)

      assert Enum.map(resolved, & &1.lang_iso) == ["en", "lv"]
    end

    test "returns error when basename rootname is empty" do
      entries = [
        %Entry{
          abs_path: "/tmp/project/priv/locales/.json",
          rel_path: "priv/locales/.json",
          basename: ".json",
          ext: ".json",
          lang_iso: ""
        }
      ]

      assert {:error, {:invalid_lang_iso, "priv/locales/.json", :empty}} =
               Files.resolve_langs(entries, :basename)
    end

    test "keeps entry order" do
      entries = [
        %Entry{
          abs_path: "/tmp/project/priv/locales/fr.json",
          rel_path: "priv/locales/fr.json",
          basename: "fr.json",
          ext: ".json",
          lang_iso: ""
        },
        %Entry{
          abs_path: "/tmp/project/priv/locales/en.json",
          rel_path: "priv/locales/en.json",
          basename: "en.json",
          ext: ".json",
          lang_iso: ""
        }
      ]

      assert {:ok, resolved} = Files.resolve_langs(entries, :basename)

      assert Enum.map(resolved, & &1.rel_path) == [
               "priv/locales/fr.json",
               "priv/locales/en.json"
             ]

      assert Enum.map(resolved, & &1.lang_iso) == ["fr", "en"]
    end
  end

  describe "resolve_langs/2 with function resolver" do
    test "uses custom resolver result" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/admin.en.json",
        rel_path: "priv/locales/admin.en.json",
        basename: "admin.en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = fn %Entry{} -> "en" end

      assert {:ok, [%Entry{lang_iso: "en"}]} = Files.resolve_langs([entry], resolver)
    end

    test "trims custom resolver result" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = fn %Entry{} -> "  en  " end

      assert {:ok, [%Entry{lang_iso: "en"}]} = Files.resolve_langs([entry], resolver)
    end

    test "returns error when custom resolver returns nil" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = fn %Entry{} -> nil end

      assert {:error, {:invalid_lang_iso, "priv/locales/en.json", nil}} =
               Files.resolve_langs([entry], resolver)
    end

    test "returns error when custom resolver returns non-binary" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = fn %Entry{} -> :en end

      assert {:error, {:invalid_lang_iso, "priv/locales/en.json", :en}} =
               Files.resolve_langs([entry], resolver)
    end

    test "returns error when custom resolver returns empty or whitespace string" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = fn %Entry{} -> "   " end

      assert {:error, {:invalid_lang_iso, "priv/locales/en.json", :empty_or_whitespace}} =
               Files.resolve_langs([entry], resolver)
    end
  end

  describe "resolve_langs/2 with MFA resolver" do
    test "uses MFA resolver result" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/dashboard.en.json",
        rel_path: "priv/locales/dashboard.en.json",
        basename: "dashboard.en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = {__MODULE__.LangResolverStub, :from_suffix, [".en.json", "en"]}

      assert {:ok, [%Entry{lang_iso: "en"}]} = Files.resolve_langs([entry], resolver)
    end

    test "trims MFA resolver result" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = {__MODULE__.LangResolverStub, :constant, ["  en  "]}

      assert {:ok, [%Entry{lang_iso: "en"}]} = Files.resolve_langs([entry], resolver)
    end

    test "returns error when MFA resolver returns nil" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = {__MODULE__.LangResolverStub, :constant, [nil]}

      assert {:error, {:invalid_lang_iso, "priv/locales/en.json", nil}} =
               Files.resolve_langs([entry], resolver)
    end

    test "returns error when MFA resolver returns non-binary" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = {__MODULE__.LangResolverStub, :constant, [:en]}

      assert {:error, {:invalid_lang_iso, "priv/locales/en.json", :en}} =
               Files.resolve_langs([entry], resolver)
    end

    test "returns error when MFA resolver returns whitespace" do
      entry = %Entry{
        abs_path: "/tmp/project/priv/locales/en.json",
        rel_path: "priv/locales/en.json",
        basename: "en.json",
        ext: ".json",
        lang_iso: ""
      }

      resolver = {__MODULE__.LangResolverStub, :constant, ["   "]}

      assert {:error, {:invalid_lang_iso, "priv/locales/en.json", :empty_or_whitespace}} =
               Files.resolve_langs([entry], resolver)
    end
  end

  describe "discover/1" do
    test "returns error when locales_path does not exist" do
      missing = unique_tmp_path("missing_locales")

      assert {:error, {:locales_path_not_found, ^missing}} =
               Files.discover(locales_path: missing)
    end

    test "discovers files and resolves lang_iso from basename by default" do
      locales_path = unique_tmp_path("discover_default")
      nested_dir = Path.join(locales_path, "nested")

      File.mkdir_p!(nested_dir)
      File.write!(Path.join(locales_path, "en.json"), "{}")
      File.write!(Path.join(nested_dir, "lv.yml"), "foo: bar")

      assert {:ok, entries} = Files.discover(locales_path: locales_path)

      assert Enum.map(entries, & &1.rel_path) == [
               project_rel(Path.join(locales_path, "en.json")),
               project_rel(Path.join(nested_dir, "lv.yml"))
             ]

      assert Enum.map(entries, & &1.basename) == ["en.json", "lv.yml"]
      assert Enum.map(entries, & &1.ext) == [".json", ".yml"]
      assert Enum.map(entries, & &1.lang_iso) == ["en", "lv"]

      assert Enum.all?(entries, &(Path.type(&1.abs_path) == :absolute))
    end

    test "uses include_patterns to limit discovered files" do
      locales_path = unique_tmp_path("discover_include")
      File.mkdir_p!(Path.join(locales_path, "nested"))

      File.write!(Path.join(locales_path, "en.json"), "{}")
      File.write!(Path.join(locales_path, "lv.yml"), "foo: bar")
      File.write!(Path.join(locales_path, "nested/fr.json"), "{}")

      assert {:ok, entries} =
               Files.discover(
                 locales_path: locales_path,
                 include_patterns: ["**/*.json"]
               )

      assert Enum.map(entries, & &1.rel_path) == [
               project_rel(Path.join(locales_path, "en.json")),
               project_rel(Path.join(locales_path, "nested/fr.json"))
             ]

      assert Enum.map(entries, & &1.lang_iso) == ["en", "fr"]
    end

    test "uses exclude_patterns to remove matched files" do
      locales_path = unique_tmp_path("discover_exclude")
      File.mkdir_p!(Path.join(locales_path, "nested"))

      en_path = Path.join(locales_path, "en.json")
      fr_path = Path.join(locales_path, "nested/fr.json")

      File.write!(en_path, "{}")
      File.write!(fr_path, "{}")

      assert {:ok, entries} =
               Files.discover(
                 locales_path: locales_path,
                 include_patterns: ["**/*.json"],
                 exclude_patterns: ["nested/*"]
               )

      assert Enum.map(entries, & &1.rel_path) == [project_rel(en_path)]
      assert Enum.map(entries, & &1.lang_iso) == ["en"]
    end

    test "does not include directories even if they match a wildcard" do
      locales_path = unique_tmp_path("discover_regular_files_only")
      nested_dir = Path.join(locales_path, "en")

      File.mkdir_p!(nested_dir)
      File.write!(Path.join(nested_dir, "messages.json"), "{}")

      assert {:ok, entries} =
               Files.discover(
                 locales_path: locales_path,
                 include_patterns: ["**/*"]
               )

      assert Enum.map(entries, & &1.rel_path) == [
               project_rel(Path.join(nested_dir, "messages.json"))
             ]
    end

    test "deduplicates files matched by multiple include patterns" do
      locales_path = unique_tmp_path("discover_dedup")
      file_path = Path.join(locales_path, "en.json")

      File.mkdir_p!(locales_path)
      File.write!(file_path, "{}")

      assert {:ok, entries} =
               Files.discover(
                 locales_path: locales_path,
                 include_patterns: ["**/*.json", "en.json", "**/*"]
               )

      assert Enum.map(entries, & &1.rel_path) == [project_rel(file_path)]
    end

    test "returns entries sorted by absolute path" do
      locales_path = unique_tmp_path("discover_sorted")

      File.mkdir_p!(Path.join(locales_path, "nested"))
      file_b = Path.join(locales_path, "z.json")
      file_a = Path.join(locales_path, "a.json")
      file_c = Path.join(locales_path, "nested/m.json")

      File.write!(file_b, "{}")
      File.write!(file_a, "{}")
      File.write!(file_c, "{}")

      assert {:ok, entries} = Files.discover(locales_path: locales_path)

      assert Enum.map(entries, & &1.abs_path) == Enum.sort([file_a, file_c, file_b])
    end

    test "supports files without extension" do
      locales_path = unique_tmp_path("discover_no_ext")
      file_path = Path.join(locales_path, "en")

      File.mkdir_p!(locales_path)
      File.write!(file_path, "{}")

      assert {:ok, [entry]} = Files.discover(locales_path: locales_path)

      assert entry.abs_path == Path.expand(file_path)
      assert entry.rel_path == project_rel(file_path)
      assert entry.basename == "en"
      assert entry.ext == ""
      assert entry.lang_iso == "en"
    end

    test "uses custom function lang_resolver during discovery" do
      locales_path = unique_tmp_path("discover_fun_resolver")
      file_path = Path.join(locales_path, "admin.en.json")

      File.mkdir_p!(locales_path)
      File.write!(file_path, "{}")

      resolver = fn %Entry{basename: basename} ->
        if String.ends_with?(basename, ".en.json"), do: "en", else: "unknown"
      end

      assert {:ok, [entry]} =
               Files.discover(
                 locales_path: locales_path,
                 lang_resolver: resolver
               )

      assert entry.rel_path == project_rel(file_path)
      assert entry.lang_iso == "en"
    end

    test "uses custom MFA lang_resolver during discovery" do
      locales_path = unique_tmp_path("discover_mfa_resolver")
      file_path = Path.join(locales_path, "backend.lv.json")

      File.mkdir_p!(locales_path)
      File.write!(file_path, "{}")

      resolver = {__MODULE__.LangResolverStub, :from_suffix, [".lv.json", "lv"]}

      assert {:ok, [entry]} =
               Files.discover(
                 locales_path: locales_path,
                 lang_resolver: resolver
               )

      assert entry.rel_path == project_rel(file_path)
      assert entry.lang_iso == "lv"
    end

    test "returns lang resolver error from custom function" do
      locales_path = unique_tmp_path("discover_fun_error")
      file_path = Path.join(locales_path, "en.json")

      File.mkdir_p!(locales_path)
      File.write!(file_path, "{}")

      resolver = fn %Entry{} -> nil end

      assert {:error, {:invalid_lang_iso, rel_path, nil}} =
               Files.discover(
                 locales_path: locales_path,
                 lang_resolver: resolver
               )

      assert rel_path == project_rel(file_path)
    end
  end

  defmodule LangResolverStub do
    def constant(_entry, value), do: value

    def from_suffix(%Entry{basename: basename}, suffix, lang_iso) do
      if String.ends_with?(basename, suffix), do: lang_iso
    end
  end

  defp unique_tmp_path(name) do
    System.tmp_dir!()
    |> Path.join("ex_lokalise_transfer")
    |> Path.join("#{name}_#{System.unique_integer([:positive])}")
    |> Path.expand()
  end

  defp project_rel(path) do
    path
    |> Path.expand()
    |> Path.relative_to_cwd()
    |> Path.split()
    |> Path.join()
  end
end
