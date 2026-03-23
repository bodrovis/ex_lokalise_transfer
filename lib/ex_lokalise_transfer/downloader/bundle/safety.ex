defmodule ExLokaliseTransfer.Downloader.Bundle.Safety do
  def validate_zip_entries(entries) when is_list(entries) do
    case Enum.find(entries, &dangerous_zip_entry?/1) do
      nil -> :ok
      bad -> {:error, {:unsafe_zip_entry, inspect(bad)}}
    end
  end

  defp dangerous_zip_entry?(entry) do
    case zip_entry_name(entry) do
      {:ok, name} -> unsafe_entry_name?(name)
      :skip -> false
      :error -> true
    end
  end

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

  defp unsafe_entry_name?(name) when is_binary(name) do
    normalized = String.replace(name, "\\", "/")

    Path.type(normalized) == :absolute or
      Enum.any?(Path.split(normalized), &(&1 == ".."))
  end
end
