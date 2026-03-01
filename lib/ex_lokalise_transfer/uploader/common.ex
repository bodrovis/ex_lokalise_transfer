defmodule ExLokaliseTransfer.Uploader.Common do
  alias ExLokaliseTransfer.Config

  @spec default_opts() :: Keyword.t()
  def default_opts do
    [
      body: [],
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

  defp validate_body(body) when is_list(body) do
    :ok
  end
end
