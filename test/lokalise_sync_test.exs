defmodule ExLokaliseSyncTest do
  use ExLokaliseSync.Case, async: true
  doctest ExLokaliseSync

  describe "upload/1" do
    test "runs properly" do
      result =
        ExLokaliseSync.upload(
          body: [format: "json"],
          retry: [max_attempts: 3]
        )

      assert result == :ok
    end
  end

  describe "download/1" do
    test "runs properly" do
      result =
        ExLokaliseSync.download(
          body: [format: "json"],
          retry: [max_attempts: 3]
        )

      assert result == :ok
    end
  end
end
