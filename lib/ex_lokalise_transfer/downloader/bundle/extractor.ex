defmodule ExLokaliseTransfer.Downloader.Bundle.Extractor do
  @moduledoc """
  Extracts a ZIP archive into a target directory.

  The destination directory is created if needed before extraction.

  Before extracting, ZIP entries are validated to reject unsafe paths such as:
    - absolute paths
    - parent-directory traversal (`..`)

  Returns `:ok` on success or `{:error, reason}` on failure.

  Note that if extraction fails partway through, some files may already have been
  written to the destination directory.
  """

  @behaviour ExLokaliseTransfer.Downloader.Bundle.ExtractorBehaviour

  alias ExLokaliseTransfer.Downloader.Bundle.Safety

  @type extract_error ::
          {:mkdir_failed, File.posix()}
          | {:zip_list_failed, term()}
          | {:zip_extract_failed, term()}
          | term()

  @spec extract_zip(String.t(), String.t()) :: :ok | {:error, extract_error()}
  def extract_zip(zip_path, extract_to)
      when is_binary(zip_path) and is_binary(extract_to) do
    with :ok <- ensure_directory(extract_to),
         {:ok, entries} <- zip_entries(zip_path),
         :ok <- Safety.validate_zip_entries(entries) do
      do_extract(zip_path, extract_to)
    end
  end

  @spec ensure_directory(String.t()) :: :ok | {:error, {:mkdir_failed, File.posix()}}
  defp ensure_directory(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  end

  @spec zip_entries(String.t()) :: {:ok, list()} | {:error, {:zip_list_failed, term()}}
  defp zip_entries(zip_path) do
    case :zip.table(to_charlist(zip_path)) do
      {:ok, entries} -> {:ok, entries}
      {:error, reason} -> {:error, {:zip_list_failed, reason}}
    end
  end

  @spec do_extract(String.t(), String.t()) :: :ok | {:error, {:zip_extract_failed, term()}}
  defp do_extract(zip_path, extract_to) do
    case :zip.extract(to_charlist(zip_path), cwd: to_charlist(extract_to)) do
      {:ok, _files} -> :ok
      {:error, reason} -> {:error, {:zip_extract_failed, reason}}
    end
  end
end
