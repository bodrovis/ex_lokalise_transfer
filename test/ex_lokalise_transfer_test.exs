defmodule ExLokaliseTransferTest do
  use ExLokaliseTransfer.Case, async: true
  doctest ExLokaliseTransfer

  # describe "upload/1" do
  #   test "runs properly" do
  #     result =
  #       ExLokaliseTransfer.upload(
  #         body: [format: "json"],
  #         retry: [max_attempts: 3]
  #       )

  #     assert result == :ok
  #   end
  # end

  # describe "download/1" do
  #   test "runs properly" do
  #     result =
  #       ExLokaliseTransfer.download(
  #         body: [format: "json"],
  #         retry: [max_attempts: 3]
  #       )

  #     assert result == :ok
  #   end
  # end
end
