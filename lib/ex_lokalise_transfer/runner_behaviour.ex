defmodule ExLokaliseTransfer.RunnerBehaviour do
  @moduledoc false

  alias ExLokaliseTransfer.Config

  @callback run(Config.t()) :: term()
end
