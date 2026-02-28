defmodule ExLokaliseSync.Uploader do
  @moduledoc """
  Uploader module for ExLokaliseSync.
  """

  alias ExLokaliseSync.Config

  @spec default_opts() :: Keyword.t()
  def default_opts do
    [
      body: [],
      retry: [
        max_attempts: 3
      ]
    ]
  end

  @spec run(Config.t()) :: :ok
  def run(%Config{} = config) do
    IO.puts("=== ExLokaliseSync.Downloader Debug ===")
    IO.puts("project_id: #{inspect(config.project_id)}")
    # IO.puts("api_token:  #{inspect(config.api_token)}")
    IO.puts("body:       #{inspect(config.body)}")
    IO.puts("retry:      #{inspect(config.retry)}")
    IO.puts("====================================")

    :ok
  end
end
