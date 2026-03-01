defmodule ExLokaliseTransfer.Downloader.Sync do
  @moduledoc """
  Sync downloader module for ExLokaliseTransfer.
  """

  require Logger

  alias ExLokaliseTransfer.Config
  alias ElixirLokaliseApi.Files
  alias ElixirLokaliseApi.Config, as: SDKConfig

  @spec run(Config.t()) :: :ok | {:error, term()}
  def run(%Config{project_id: project_id, body: body}) do
    Logger.debug("starting sync download",
      project_id: project_id,
      operation: :download_sync
    )

    data = Map.new(body || [])

    case Files.download(project_id, data) do
      {:ok, %{bundle_url: url} = resp} ->
        IO.puts("Lokalise sync download succeeded.")
        IO.puts("bundle_url: #{url}")
        IO.puts("full response: #{inspect(resp)}")
        :ok

      {:ok, resp} ->
        IO.puts("Lokalise sync download returned unexpected payload:")
        IO.puts(inspect(resp))
        {:error, {:unexpected_response, resp}}

      {:error, {data, status}} when is_map(data) and is_integer(status) ->
        IO.puts("Lokalise sync download FAILED with HTTP #{status}:")
        IO.puts(inspect(data))
        {:error, {:http_error, status, data}}

      {:error, reason} when is_atom(reason) ->
        IO.puts("Lokalise sync download FAILED with reason (atom):")
        IO.puts(inspect(reason))
        {:error, {:transport_error, reason}}

      {:error, reason} when is_binary(reason) ->
        IO.puts("Lokalise sync download FAILED with message:")
        IO.puts(reason)
        {:error, {:error_message, reason}}

      {:error, other} ->
        IO.puts("Lokalise sync download FAILED with unexpected error shape:")
        IO.puts(inspect(other))
        {:error, {:unknown_error, other}}
    end
  end
end
