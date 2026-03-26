defmodule ExLokaliseTransfer.LokaliseFilesBehaviour do
  @moduledoc false

  @callback upload(String.t(), map()) :: {:ok, map()} | {:error, term()}

  @callback download(String.t(), map()) :: {:ok, map()} | {:error, term()}

  @callback download_async(String.t(), map()) :: {:ok, map()} | {:error, term()}
end
