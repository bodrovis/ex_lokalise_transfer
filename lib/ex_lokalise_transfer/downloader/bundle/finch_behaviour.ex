defmodule ExLokaliseTransfer.Downloader.Bundle.FinchBehaviour do
  @callback build(atom(), String.t()) :: term()
  @callback stream(term(), term(), term(), (term(), term() -> term())) ::
              {:ok, term()} | {:error, term(), term()}
end
