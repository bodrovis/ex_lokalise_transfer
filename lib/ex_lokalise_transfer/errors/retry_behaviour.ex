defmodule ExLokaliseTransfer.RetryBehaviour do
  @moduledoc false

  alias ExLokaliseTransfer.Errors.Error

  @callback run((-> {:ok, term()} | {:error, term()}), Error.source(), Keyword.t()) ::
              {:ok, term()} | {:error, ExLokaliseTransfer.Errors.Error.t()}
end
