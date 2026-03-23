defmodule ExLokaliseTransfer.Downloader.Bundle.Fetcher do
  @tmp_suffix ".part"
  @max_err_body_bytes 8_192

  @type stream_acc :: %{
          status: integer() | nil,
          err_body: binary(),
          write_error: binary() | nil
        }

  @doc """
  Streams a remote ZIP archive into `path`.

  The download is first written into `path <> ".part"` and renamed to the final path
  only after a successful HTTP 200 response.

  For non-200 responses, a small portion of the response body is collected and returned
  alongside the status code.

  Returns `{:ok, :downloaded}` on success or `{:error, reason}` on failure.
  """
  @spec download_zip_stream(term(), binary(), binary()) ::
          {:ok, :downloaded} | {:error, term()}
  def download_zip_stream(finch_name, url, path)
      when is_binary(url) and is_binary(path) do
    tmp_path = path <> @tmp_suffix

    with :ok <- prepare_tmp_file(path, tmp_path),
         {:ok, io} <- File.open(tmp_path, [:write, :binary]) do
      try do
        req = :get |> Finch.build(url)
        acc = initial_stream_acc()
        fun = stream_fun(io)

        req
        |> Finch.stream(finch_name, acc, fun)
        |> handle_stream_result(tmp_path, path)
      after
        File.close(io)
      end
    end
  end

  defp stream_fun(io) do
    fn
      {:status, status}, acc ->
        %{acc | status: status}

      {:headers, _headers}, acc ->
        acc

      {:data, chunk}, %{status: 200} = acc ->
        write_chunk(io, chunk, acc)

      {:data, chunk}, acc ->
        collect_error_chunk(chunk, acc)

      {:done}, acc ->
        acc
    end
  end

  defp initial_stream_acc do
    %{
      status: nil,
      err_body: "",
      write_error: nil
    }
  end

  defp prepare_tmp_file(final_path, tmp_path) do
    with :ok <- File.mkdir_p(Path.dirname(final_path)),
         :ok <- cleanup_tmp(tmp_path) do
      :ok
    end
  end

  defp finalize_download(tmp_path, path) do
    case File.rename(tmp_path, path) do
      :ok ->
        {:ok, :downloaded}

      {:error, reason} ->
        cleanup_tmp(tmp_path)
        {:error, {:rename_failed, reason}}
    end
  end

  defp cleanup_tmp(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, {:tmp_cleanup_failed, reason}}
    end
  end

  defp write_chunk(io, chunk, acc) do
    try do
      IO.binwrite(io, chunk)
      acc
    rescue
      e ->
        %{acc | write_error: Exception.message(e)}
    end
  end

  defp collect_error_chunk(chunk, acc) do
    %{acc | err_body: append_limited(acc.err_body, chunk)}
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

  defp handle_stream_result({:ok, %{write_error: reason}}, tmp_path, _path)
       when not is_nil(reason) do
    cleanup_tmp(tmp_path)
    {:error, {:write_failed, reason}}
  end

  defp handle_stream_result({:ok, %{status: 200}}, tmp_path, path) do
    finalize_download(tmp_path, path)
  end

  defp handle_stream_result({:ok, %{status: status, err_body: body}}, tmp_path, _path)
       when is_integer(status) do
    cleanup_tmp(tmp_path)
    {:error, {String.trim(body), status}}
  end

  defp handle_stream_result({:ok, _acc}, tmp_path, _path) do
    cleanup_tmp(tmp_path)
    {:error, :no_status}
  end

  defp handle_stream_result({:error, exception, _stacktrace}, tmp_path, _path) do
    cleanup_tmp(tmp_path)
    {:error, normalize_stream_error(exception)}
  end

  defp normalize_stream_error(%{reason: reason}) when is_atom(reason), do: reason
  defp normalize_stream_error(_), do: :finch_error
end
