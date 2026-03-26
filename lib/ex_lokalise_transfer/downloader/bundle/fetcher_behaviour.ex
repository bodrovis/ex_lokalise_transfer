defmodule ExLokaliseTransfer.Downloader.Bundle.FetcherBehaviour do
  @moduledoc false

  @callback download_zip_stream(term(), String.t(), String.t()) ::
              {:ok, :downloaded} | {:error, term()}
end
