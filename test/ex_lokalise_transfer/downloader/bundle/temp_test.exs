defmodule ExLokaliseTransfer.Downloader.Bundle.TempTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Downloader.Bundle.Temp

  describe "temp_zip_path/1" do
    test "returns a path inside the system temp directory for atom kind" do
      path = Temp.temp_zip_path(:sync)

      assert_same_path(Path.dirname(path), System.tmp_dir!())
      assert String.ends_with?(path, ".zip")
      assert Path.basename(path) =~ ~r/^lokalise-bundle-sync-\d{8}T\d{6}-\d+\.zip$/
    end

    test "returns a path inside the system temp directory for binary kind" do
      path = Temp.temp_zip_path("async")

      assert_same_path(Path.dirname(path), System.tmp_dir!())
      assert String.ends_with?(path, ".zip")
      assert Path.basename(path) =~ ~r/^lokalise-bundle-async-\d{8}T\d{6}-\d+\.zip$/
    end

    test "returns different paths across calls for the same kind" do
      path1 = Temp.temp_zip_path(:sync)
      path2 = Temp.temp_zip_path(:sync)

      refute path1 == path2
    end

    test "includes the provided kind in the filename" do
      assert Path.basename(Temp.temp_zip_path(:download)) =~ "lokalise-bundle-download-"
      assert Path.basename(Temp.temp_zip_path("upload")) =~ "lokalise-bundle-upload-"
    end
  end

  defp assert_same_path(left, right) do
    assert Path.expand(left) == Path.expand(right)
  end
end
