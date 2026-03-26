defmodule ExLokaliseTransfer.Downloader.Bundle.ExtractorBehaviour do
  @moduledoc false

  @callback extract_zip(String.t(), String.t()) :: :ok | {:error, term()}
end
