defmodule ExLokaliseSync.TokenProvider do
  @moduledoc """
  Behaviour for providing an API token to ExLokaliseSync.
  """

  @callback api_token() :: String.t() | nil
end
