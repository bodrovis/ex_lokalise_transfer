defmodule ExLokaliseTransfer.Uploader.Async do
  @moduledoc """
  Uploader module for ExLokaliseTransfer.
  """

  alias ExLokaliseTransfer.Config

  @spec run(Config.t()) :: :ok
  def run(%Config{} = config) do
    IO.puts("=== ExLokaliseTransfer.Downloader Debug ===")
    IO.puts("project_id: #{inspect(config.project_id)}")
    IO.puts("body:       #{inspect(config.body)}")
    IO.puts("retry:      #{inspect(config.retry)}")
    IO.puts("====================================")

    :ok
  end
end
