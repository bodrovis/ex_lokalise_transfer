defmodule ExLokaliseTransfer.Downloader.Common do
  @moduledoc """
  Common defaults and validation for downloader flows.

  Provides default option values for bundle download requests, retry settings,
  and local extraction options.
  """

  alias ExLokaliseTransfer.Config
  alias ExLokaliseTransfer.Retry
  alias ExLokaliseTransfer.Downloader.Bundle.Fetcher
  alias ExLokaliseTransfer.Downloader.Bundle.Extractor

  @doc """
  Returns the default downloader options.

  Includes:
    - Lokalise bundle request options in `:body`
    - retry/backoff settings in `:retry`
    - local extraction settings in `:extra`
  """
  @spec default_opts() :: Keyword.t()
  def default_opts do
    [
      body: [
        format: "json",
        original_filenames: true,
        directory_prefix: "",
        indentation: "2sp"
      ],
      retry: [
        max_attempts: 3,
        min_sleep_ms: 1_000,
        max_sleep_ms: 60_000,
        jitter: :centered
      ],
      poll: [
        max_attempts: 3,
        min_sleep_ms: 1_000,
        max_sleep_ms: 60_000,
        jitter: :centered
      ],
      extra: [
        extract_to: "./"
      ]
    ]
  end

  @finch ElixirLokaliseApi.Finch

  @doc """
  Validates downloader configuration.

  Runs shared config validation and downloader-specific checks for required
  download body options and extraction settings.
  """
  @spec validate(Config.t()) :: :ok | {:error, term()}
  def validate(%Config{} = config) do
    with :ok <- Config.validate_common(config),
         :ok <- validate_body(config.body),
         :ok <- validate_extra(config.extra) do
      :ok
    end
  end

  def download_and_extract(url, zip_path, target_dir, retry) do
    with {:ok, :downloaded} <-
           Retry.run(fn -> Fetcher.download_zip_stream(@finch, url, zip_path) end, :s3, retry),
         do: Extractor.extract_zip(zip_path, target_dir)
  end

  def resolve_extract_to(extra) do
    extra
    |> Keyword.fetch!(:extract_to)
    |> Path.expand()
  end

  @spec validate_body(Keyword.t()) :: :ok | {:error, term()}
  defp validate_body(body) do
    case Keyword.fetch(body, :format) do
      :error ->
        {:error, {:missing, :format}}

      {:ok, format} when is_binary(format) ->
        case String.trim(format) do
          "" -> {:error, {:invalid, :format, :empty_or_whitespace}}
          _ -> :ok
        end

      {:ok, _other} ->
        {:error, {:invalid, :format, :not_binary}}
    end
  end

  @spec validate_extra(Keyword.t()) :: :ok | {:error, term()}
  defp validate_extra(extra) do
    case Keyword.fetch(extra, :extract_to) do
      :error ->
        {:error, {:missing, :extract_to}}

      {:ok, path} when is_binary(path) ->
        case String.trim(path) do
          "" -> {:error, {:invalid, :extract_to, :empty_or_whitespace}}
          _ -> :ok
        end

      {:ok, _other} ->
        {:error, {:invalid, :extract_to, :not_binary}}
    end
  end
end
