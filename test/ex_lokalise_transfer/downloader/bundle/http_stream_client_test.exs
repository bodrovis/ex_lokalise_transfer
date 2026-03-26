defmodule ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClientTest do
  use ExLokaliseTransfer.Case, async: false

  setup {ExLokaliseTransfer.Case, :set_finch_mock}

  import Mox

  alias ExLokaliseTransfer.FinchMock
  alias ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClient

  test "delegates to Finch" do
    expect(FinchMock, :build, fn :get, "url" ->
      :req
    end)

    expect(FinchMock, :stream, fn :req, :finch, :acc, fun ->
      assert is_function(fun, 2)
      {:ok, :done}
    end)

    assert {:ok, :done} =
             HTTPStreamClient.stream(:finch, :get, "url", :acc, fn _, acc -> acc end)
  end
end
