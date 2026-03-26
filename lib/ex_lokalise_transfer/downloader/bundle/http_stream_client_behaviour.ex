defmodule ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClientBehaviour do
  @moduledoc false

  @callback stream(
              finch_name :: term(),
              method :: atom(),
              url :: String.t(),
              acc :: term(),
              fun :: (term(), term() -> term())
            ) ::
              {:ok, term()} | {:error, term(), term()}
end
