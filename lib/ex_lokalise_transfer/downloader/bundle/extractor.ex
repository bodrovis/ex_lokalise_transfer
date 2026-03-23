defmodule ExLokaliseTransfer.Downloader.Bundle.Extractor do
  alias ExLokaliseTransfer.Downloader.Bundle.Safety

  @doc """
  Extracts a ZIP archive into `extract_to`.

  The target directory is created if needed before extraction.

  Before extracting, ZIP entries are validated to reject unsafe paths such as:
    - absolute paths
    - parent-directory traversal (`..`)

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec extract_zip(binary(), binary()) :: :ok | {:error, term()}
  def extract_zip(zip_path, extract_to)
      when is_binary(zip_path) and is_binary(extract_to) do
    with :ok <- File.mkdir_p(extract_to),
         {:ok, entries} <- zip_entries(zip_path),
         :ok <- Safety.validate_zip_entries(entries) do
      zip_char = String.to_charlist(zip_path)
      dest_char = String.to_charlist(extract_to)

      case :zip.extract(zip_char, cwd: dest_char) do
        {:ok, _files} -> :ok
        {:error, reason} -> {:error, {:zip_extract_failed, reason}}
      end
    end
  end

  defp zip_entries(zip_path) do
    zip_char = String.to_charlist(zip_path)

    case :zip.table(zip_char) do
      {:ok, entries} -> {:ok, entries}
      {:error, reason} -> {:error, {:zip_list_failed, reason}}
    end
  end
end
