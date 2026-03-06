defmodule ExLokaliseTransfer.Downloader.Sync do
  @moduledoc """
  Sync downloader module for ExLokaliseTransfer.
  """

  require Logger

  alias ElixirLokaliseApi.Files
  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Downloader.Bundle
  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Retry

  @finch ElixirLokaliseApi.Finch

  @spec run(Config.t()) :: :ok | {:error, term()}
  def run(%Config{
        project_id: project_id,
        body: body,
        retry: retry,
        extra: extra
      }) do
    target_dir = resolve_locales_path(extra)

    Logger.debug("starting sync download",
      project_id: project_id,
      operation: :download_sync,
      locales_path: target_dir
    )

    zip_path = Bundle.temp_zip_path(:sync)
    data = normalize_body(body)

    try do
      with {:ok, bundle_url} <- request_bundle_url(project_id, data, retry),
           :ok <- download_and_extract(bundle_url, zip_path, target_dir, retry) do
        :ok
      end
    after
      File.rm(zip_path)
    end
  end

  defp normalize_body(nil), do: %{}
  defp normalize_body(body) when is_map(body), do: body
  defp normalize_body(body) when is_list(body), do: Map.new(body)

  defp resolve_locales_path(extra) do
    extra
    |> Keyword.fetch!(:locales_path)
    |> Path.expand()
  end

  defp request_bundle_url(project_id, data, retry) do
    case Retry.run(fn -> Files.download(project_id, data) end, :lokalise, retry) do
      {:ok, %{bundle_url: url}} when is_binary(url) and url != "" ->
        {:ok, url}

      {:ok, resp} ->
        {:error, {:unexpected_response, resp}}

      {:error, %Error{} = err} ->
        {:error, err}
    end
  end

  defp download_and_extract(url, zip_path, target_dir, retry) do
    with {:ok, :downloaded} <-
           Retry.run(fn -> Bundle.download_zip_stream(@finch, url, zip_path) end, :s3, retry),
         :ok <- Bundle.extract_zip(zip_path, target_dir) do
      :ok
    end
  end
end
