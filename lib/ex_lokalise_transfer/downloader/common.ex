defmodule ExLokaliseTransfer.Downloader.Common do
  alias ExLokaliseTransfer.Config

  @spec default_opts() :: Keyword.t()
  def default_opts do
    [
      body: [
        format: "json"
      ],
      retry: [
        max_attempts: 3
      ]
    ]
  end

  @spec validate(Config.t()) :: :ok | {:error, term()}
  def validate(%Config{} = config) do
    with :ok <- Config.validate_common(config),
         :ok <- validate_body(config.body) do
      :ok
    end
  end

  @spec validate_body(Keyword.t()) :: :ok | {:error, term()}
  defp validate_body(body) when is_list(body) do
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
end
