defmodule ExLokaliseTransfer.Downloader.Common do
  alias ExLokaliseTransfer.Config

  @spec default_opts() :: Keyword.t()
  def default_opts do
    [
      body: [
        format: "json"
      ],
      retry: [
        max_attempts: 3,
        min_sleep_ms: 1_000,
        max_sleep_ms: 60_000,
        jitter: :centered
      ],
      extra: [
        locales_path: "./locales"
      ]
    ]
  end

  @spec validate(Config.t()) :: :ok | {:error, term()}
  def validate(%Config{} = config) do
    with :ok <- Config.validate_common(config),
         :ok <- validate_body(config.body),
         :ok <- validate_extra(config.extra) do
      :ok
    end
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
    case Keyword.fetch(extra, :locales_path) do
      :error ->
        {:error, {:missing, :locales_path}}

      {:ok, path} when is_binary(path) ->
        case String.trim(path) do
          "" -> {:error, {:invalid, :locales_path, :empty_or_whitespace}}
          _ -> :ok
        end

      {:ok, _other} ->
        {:error, {:invalid, :locales_path, :not_binary}}
    end
  end
end
