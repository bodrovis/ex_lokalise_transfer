defmodule ExLokaliseTransfer.Downloader.Bundle.Temp do
  @moduledoc """
  Utilities for generating temporary file paths for Lokalise bundles.
  """

  @behaviour ExLokaliseTransfer.Downloader.Bundle.TempBehaviour

  @doc """
  Builds a unique temporary ZIP file path in the system temp directory.

  The generated filename includes:
    - the provided `kind`
    - a UTC timestamp
    - a unique integer suffix
  """
  @spec temp_zip_path(atom() | String.t()) :: String.t()
  def temp_zip_path(kind) do
    ts =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%Y%m%dT%H%M%S")

    uniq = System.unique_integer([:positive])

    filename = "lokalise-bundle-#{kind}-#{ts}-#{uniq}.zip"
    Path.join(System.tmp_dir!(), filename)
  end
end
