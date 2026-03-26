defmodule ExLokaliseTransfer.Downloader.Bundle.Safety do
  @moduledoc """
  Validates ZIP entries before extraction.

  Rejects entries with unsafe paths, including:
    - absolute paths
    - parent-directory traversal (`..`)
    - unrecognized entry formats
  """

  @type validation_error ::
          {:unsafe_zip_entry, String.t()}
          | {:invalid_zip_entry, term()}

  @spec validate_zip_entries(list()) :: :ok | {:error, validation_error()}
  def validate_zip_entries(entries) when is_list(entries) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      case validate_zip_entry(entry) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec validate_zip_entry(term()) :: :ok | {:error, validation_error()}
  defp validate_zip_entry(entry) do
    case zip_entry_name(entry) do
      {:ok, name} ->
        if unsafe_entry_name?(name) do
          {:error, {:unsafe_zip_entry, name}}
        else
          :ok
        end

      :skip ->
        :ok

      :error ->
        {:error, {:invalid_zip_entry, entry}}
    end
  end

  @spec zip_entry_name(term()) :: {:ok, String.t()} | :skip | :error
  defp zip_entry_name({:zip_comment, _}), do: :skip

  defp zip_entry_name({:zip_file, name, _file_info, _comment, _offset, _comp_size})
       when is_list(name),
       do: {:ok, List.to_string(name)}

  defp zip_entry_name({:zip_file, name, _file_info, _comment, _offset, _comp_size})
       when is_binary(name),
       do: {:ok, name}

  defp zip_entry_name(name) when is_list(name), do: {:ok, List.to_string(name)}
  defp zip_entry_name(name) when is_binary(name), do: {:ok, name}
  defp zip_entry_name(_), do: :error

  @spec unsafe_entry_name?(String.t()) :: boolean()
  defp unsafe_entry_name?(name) when is_binary(name) do
    normalized = String.replace(name, "\\", "/")
    segments = Path.split(normalized)

    absolute_path?(normalized) or Enum.any?(segments, &(&1 == ".."))
  end

  @spec absolute_path?(String.t()) :: boolean()
  defp absolute_path?(path) do
    String.starts_with?(path, "/") or
      Regex.match?(~r/^[A-Za-z]:\//, path) or
      String.starts_with?(path, "//")
  end
end
