defmodule ExLokaliseTransfer.Sdk.LokaliseFilesImplTest do
  use ExLokaliseTransfer.Case, async: false

  setup {ExLokaliseTransfer.Case, :set_lokalise_files_impl_mocks}

  alias ExLokaliseTransfer.Sdk.LokaliseFilesImpl
  alias ExLokaliseTransfer.LokaliseFilesSdkMock

  import Mox

  test "upload delegates to sdk" do
    expect(LokaliseFilesSdkMock, :upload, fn "proj", %{a: 1} ->
      {:ok, %{ok: true}}
    end)

    assert {:ok, %{ok: true}} =
             LokaliseFilesImpl.upload("proj", %{a: 1})
  end

  test "download delegates to sdk" do
    expect(LokaliseFilesSdkMock, :download, fn "proj", %{} ->
      {:ok, %{bundle_url: "url"}}
    end)

    assert {:ok, %{bundle_url: "url"}} =
             LokaliseFilesImpl.download("proj", %{})
  end

  test "download_async delegates to sdk" do
    expect(LokaliseFilesSdkMock, :download_async, fn "proj", %{} ->
      {:ok, %{process_id: "123"}}
    end)

    assert {:ok, %{process_id: "123"}} =
             LokaliseFilesImpl.download_async("proj", %{})
  end
end
