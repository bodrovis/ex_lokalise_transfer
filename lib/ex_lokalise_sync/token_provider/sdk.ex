defmodule ExLokaliseSync.TokenProvider.SDK do
  @moduledoc """
  Default token provider that delegates to ElixirLokaliseApi.Config.
  """

  @behaviour ExLokaliseSync.TokenProvider

  def api_token do
    ElixirLokaliseApi.Config.api_token()
  end
end
