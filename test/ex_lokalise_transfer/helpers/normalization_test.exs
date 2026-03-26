defmodule ExLokaliseTransfer.Helpers.NormalizationTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Helpers.Normalization

  describe "normalize_body/1" do
    test "returns empty map for nil" do
      assert Normalization.normalize_body(nil) == %{}
    end

    test "returns map unchanged when body is already a map" do
      body = %{"format" => "json", "original_filenames" => false}

      assert Normalization.normalize_body(body) == body
    end

    test "converts keyword list to map" do
      body = [format: "json", original_filenames: false]

      assert Normalization.normalize_body(body) == %{
               format: "json",
               original_filenames: false
             }
    end

    test "converts list of tuples to map" do
      body = [{"format", "json"}, {"original_filenames", false}]

      assert Normalization.normalize_body(body) == %{
               "format" => "json",
               "original_filenames" => false
             }
    end

    test "keeps the last value for duplicate keys in lists" do
      body = [format: "json", format: "yaml"]

      assert Normalization.normalize_body(body) == %{format: "yaml"}
    end

    test "returns empty map for an empty list" do
      assert Normalization.normalize_body([]) == %{}
    end
  end
end
