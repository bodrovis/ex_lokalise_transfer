defmodule ExLokaliseTransfer.Downloader.Bundle do
  @moduledoc false

  @max_err_body_bytes 8_192
  @tmp_suffix ".part"

  @spec download_zip_stream(term(), binary(), binary()) ::
          {:ok, :downloaded} | {:error, term()}
  def download_zip_stream(finch_name, url, path)
      when is_binary(url) and is_binary(path) do
    tmp_path = path <> @tmp_suffix

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- cleanup_tmp(tmp_path),
         {:ok, io} <- File.open(tmp_path, [:write, :binary]) do
      try do
        req = Finch.build(:get, url)

        acc = %{status: nil, err_body: "", write_error: nil}

        fun = fn
          {:status, status}, acc ->
            %{acc | status: status}

          {:headers, _headers}, acc ->
            acc

          {:data, chunk}, %{status: 200} = acc ->
            try do
              IO.binwrite(io, chunk)
              acc
            rescue
              e ->
                %{acc | write_error: Exception.message(e)}
            end

          {:data, chunk}, acc ->
            %{acc | err_body: append_limited(acc.err_body, chunk)}

          {:done}, acc ->
            acc
        end

        case Finch.stream(req, finch_name, acc, fun) do
          {:ok, %{write_error: reason}} when not is_nil(reason) ->
            cleanup_tmp(tmp_path)
            {:error, {:write_failed, reason}}

          {:ok, %{status: 200}} ->
            case File.rename(tmp_path, path) do
              :ok ->
                {:ok, :downloaded}

              {:error, reason} ->
                cleanup_tmp(tmp_path)
                {:error, {:rename_failed, reason}}
            end

          {:ok, %{status: status, err_body: body}} when is_integer(status) ->
            cleanup_tmp(tmp_path)
            {:error, {String.trim(body), status}}

          {:ok, _acc} ->
            cleanup_tmp(tmp_path)
            {:error, :no_status}

          {:error, exception, _stacktrace} ->
            cleanup_tmp(tmp_path)
            {:error, normalize_stream_error(exception)}
        end
      after
        File.close(io)
      end
    end
  end

  @spec extract_zip(binary(), binary()) :: :ok | {:error, term()}
  def extract_zip(zip_path, extract_to)
      when is_binary(zip_path) and is_binary(extract_to) do
    with :ok <- File.mkdir_p(extract_to),
         {:ok, entries} <- zip_entries(zip_path),
         :ok <- validate_zip_entries(entries) do
      zip_char = String.to_charlist(zip_path)
      dest_char = String.to_charlist(extract_to)

      case :zip.extract(zip_char, cwd: dest_char) do
        {:ok, _files} -> :ok
        {:error, reason} -> {:error, {:zip_extract_failed, reason}}
      end
    end
  end

  @spec temp_zip_path(atom() | binary()) :: binary()
  def temp_zip_path(kind) do
    ts =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%Y%m%dT%H%M%S")

    uniq = System.unique_integer([:positive])

    filename = "lokalise-bundle-#{kind}-#{ts}-#{uniq}.zip"
    Path.join(System.tmp_dir!(), filename)
  end

  defp append_limited(current, chunk) do
    if byte_size(current) >= @max_err_body_bytes do
      current
    else
      remaining = @max_err_body_bytes - byte_size(current)
      take = min(byte_size(chunk), remaining)
      current <> binary_part(chunk, 0, take)
    end
  end

  defp cleanup_tmp(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, {:tmp_cleanup_failed, reason}}
    end
  end

  defp normalize_stream_error(%{reason: reason}) when is_atom(reason), do: reason
  defp normalize_stream_error(_), do: :finch_error

  defp zip_entries(zip_path) do
    zip_char = String.to_charlist(zip_path)

    case :zip.table(zip_char) do
      {:ok, entries} -> {:ok, entries}
      {:error, reason} -> {:error, {:zip_list_failed, reason}}
    end
  end

  defp validate_zip_entries(entries) when is_list(entries) do
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
