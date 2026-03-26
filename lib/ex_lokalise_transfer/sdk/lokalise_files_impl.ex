defmodule ExLokaliseTransfer.Sdk.LokaliseFilesImpl do
  @moduledoc false

  @behaviour ExLokaliseTransfer.Sdk.LokaliseFilesBehaviour

  @impl true
  def upload(project_id, payload) do
    files_module().upload(project_id, payload)
  end

  @impl true
  def download(project_id, data) do
    files_module().download(project_id, data)
  end

  @impl true
  def download_async(project_id, data) do
    files_module().download_async(project_id, data)
  end

  defp files_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :lokalise_files_sdk_module,
      ElixirLokaliseApi.Files
    )
  end
end
