defmodule ExLokaliseTransfer.Downloader.Bundle.ExtractorTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Downloader.Bundle.Extractor

  describe "extract_zip/2" do
    test "extracts a safe zip archive into target directory" do
      tmp_dir = unique_tmp_dir()
      zip_path = Path.join(tmp_dir, "bundle.zip")
      extract_to = Path.join(tmp_dir, "out")

      create_zip!(zip_path, [
        {"translations/en.json", ~s({"hello":"world"})},
        {"translations/lv.json", ~s({"hello":"sveiki"})}
      ])

      assert :ok = Extractor.extract_zip(zip_path, extract_to)

      assert File.read!(Path.join(extract_to, "translations/en.json")) == ~s({"hello":"world"})
      assert File.read!(Path.join(extract_to, "translations/lv.json")) == ~s({"hello":"sveiki"})
    end

    test "creates the target directory if it does not exist" do
      tmp_dir = unique_tmp_dir()
      zip_path = Path.join(tmp_dir, "bundle.zip")
      extract_to = Path.join(tmp_dir, "nested/out")

      create_zip!(zip_path, [
        {"en.json", ~s({"ok":true})}
      ])

      assert :ok = Extractor.extract_zip(zip_path, extract_to)
      assert File.dir?(extract_to)
      assert File.read!(Path.join(extract_to, "en.json")) == ~s({"ok":true})
    end

    test "returns error when zip listing fails for invalid archive" do
      tmp_dir = unique_tmp_dir()
      zip_path = Path.join(tmp_dir, "not_a_zip.zip")
      extract_to = Path.join(tmp_dir, "out")

      File.mkdir_p!(tmp_dir)
      File.write!(zip_path, "definitely not a zip archive")

      assert {:error, {:zip_list_failed, _reason}} =
               Extractor.extract_zip(zip_path, extract_to)
    end

    test "returns error when zip contains parent traversal entry" do
      tmp_dir = unique_tmp_dir()
      zip_path = Path.join(tmp_dir, "unsafe.zip")
      extract_to = Path.join(tmp_dir, "out")

      create_zip!(zip_path, [
        {"../evil.txt", "owned"}
      ])

      assert {:error, {:unsafe_zip_entry, "../evil.txt"}} =
               Extractor.extract_zip(zip_path, extract_to)

      refute File.exists?(Path.join(extract_to, "evil.txt"))
    end

    test "returns error when zip contains windows traversal entry" do
      tmp_dir = unique_tmp_dir()
      zip_path = Path.join(tmp_dir, "unsafe_windows.zip")
      extract_to = Path.join(tmp_dir, "out")

      create_zip!(zip_path, [
        {"..\\..\\evil.txt", "nope"}
      ])

      assert {:error, {:unsafe_zip_entry, "..\\..\\evil.txt"}} =
               Extractor.extract_zip(zip_path, extract_to)
    end

    test "returns mkdir_failed when target directory cannot be created" do
      tmp_dir = unique_tmp_dir()
      zip_path = Path.join(tmp_dir, "bundle.zip")
      blocked_path = Path.join(tmp_dir, "blocked")

      create_zip!(zip_path, [
        {"en.json", ~s({"ok":true})}
      ])

      File.mkdir_p!(tmp_dir)
      File.write!(blocked_path, "i am a file, not a directory")

      extract_to = Path.join(blocked_path, "out")

      assert {:error, {:mkdir_failed, _reason}} =
               Extractor.extract_zip(zip_path, extract_to)
    end

    test "returns zip_extract_failed when extraction conflicts with existing file" do
      tmp_dir = unique_tmp_dir()
      zip_path = Path.join(tmp_dir, "bundle.zip")
      extract_to = Path.join(tmp_dir, "out")

      create_zip!(zip_path, [
        {"translations/en.json", ~s({"hello":"world"})}
      ])

      File.mkdir_p!(extract_to)

      File.write!(Path.join(extract_to, "translations"), "i block directory creation")

      assert {:error, {:zip_extract_failed, _reason}} =
               Extractor.extract_zip(zip_path, extract_to)
    end
  end

  defp create_zip!(zip_path, files) do
    File.mkdir_p!(Path.dirname(zip_path))

    entries =
      Enum.map(files, fn {name, content} ->
        {String.to_charlist(name), content}
      end)

    assert {:ok, _} = :zip.create(String.to_charlist(zip_path), entries, [])
  end

  defp unique_tmp_dir do
    base = System.tmp_dir!()

    path =
      Path.join(
        base,
        "ex_lokalise_transfer_extractor_test_#{System.unique_integer([:positive, :monotonic])}"
      )

    File.rm_rf!(path)
    File.mkdir_p!(path)
    path
  end
end
