defmodule ExLokaliseTransfer.Helpers.BackoffBehaviour do
  @moduledoc false

  @callback backoff_ms(pos_integer(), Keyword.t()) :: non_neg_integer()
end
