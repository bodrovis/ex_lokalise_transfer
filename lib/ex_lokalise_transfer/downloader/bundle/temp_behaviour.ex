defmodule ExLokaliseTransfer.Downloader.Bundle.TempBehaviour do
  @moduledoc false
  @callback temp_zip_path(atom() | String.t()) :: String.t()
end
