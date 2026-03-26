defmodule ExLokaliseTransfer.Sdk.LokaliseFilesImpl do
  @moduledoc false

  @behaviour ExLokaliseTransfer.Sdk.LokaliseFilesBehaviour

  alias ElixirLokaliseApi.Files

  @impl true
  def upload(project_id, payload) do
    Files.upload(project_id, payload)
  end

  @impl true
  def download(project_id, data), do: ElixirLokaliseApi.Files.download(project_id, data)

  @impl true
  def download_async(project_id, data),
    do: ElixirLokaliseApi.Files.download_async(project_id, data)
end
