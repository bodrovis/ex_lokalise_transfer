defmodule ExLokaliseTransfer.Downloader.Bundle.TransferBehaviour do
  @moduledoc false
  @callback download_and_extract(String.t(), String.t(), String.t(), Keyword.t()) ::
              :ok | {:error, term()}
end
