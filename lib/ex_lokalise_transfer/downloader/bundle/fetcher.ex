defmodule ExLokaliseTransfer.Downloader.Bundle.Fetcher do
  @moduledoc """
  Streams a remote ZIP archive into a local file.

  The response body is first written into `path <> ".part"` and renamed to the
  final path only after a successful HTTP 200 response.

  For non-200 responses, a small portion of the response body is collected and
  returned together with the status code.

  Returns `{:ok, :downloaded}` on success or `{:error, reason}` on failure.
  """

  @behaviour ExLokaliseTransfer.Downloader.Bundle.FetcherBehaviour

  alias ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClient

  @tmp_suffix ".part"
  @max_err_body_bytes 8_192

  @type stream_acc :: %{
          status: integer() | nil,
          err_body: binary(),
          write_error: binary() | nil
        }

  @type error_reason ::
          {:mkdir_failed, File.posix()}
          | {:open_failed, File.posix()}
          | {:tmp_cleanup_failed, File.posix()}
          | {:write_failed, binary()}
          | {:rename_failed, File.posix()}
          | {:http_error, integer(), binary()}
          | :no_status
          | {:stream_failed, term()}

  @spec download_zip_stream(term(), String.t(), String.t()) ::
          {:ok, :downloaded} | {:error, error_reason()}
  def download_zip_stream(finch_name, url, path)
      when is_binary(url) and is_binary(path) do
    tmp_path = path <> @tmp_suffix
    http_client = http_stream_client()

    with :ok <- prepare_tmp_file(path, tmp_path),
         {:ok, io} <- open_tmp_file(tmp_path) do
      try do
        acc = initial_stream_acc()
        fun = stream_fun(io)

        http_client
        |> apply(:stream, [finch_name, :get, url, acc, fun])
        |> handle_stream_result(tmp_path, path)
      after
        File.close(io)
      end
    end
  end

  defp http_stream_client do
    Application.get_env(
      :ex_lokalise_transfer,
      :downloader_http_stream_client,
      HTTPStreamClient
    )
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
    with :ok <- ensure_parent_dir(final_path),
         :ok <- cleanup_tmp(tmp_path) do
      :ok
    end
  end

  defp ensure_parent_dir(final_path) do
    case File.mkdir_p(Path.dirname(final_path)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  end

  defp open_tmp_file(tmp_path) do
    case File.open(tmp_path, [:write, :binary]) do
      {:ok, io} ->
        {:ok, io}

      # In reality this is very rare
      # coveralls-ignore-start
      {:error, reason} ->
        {:error, {:open_failed, reason}}
        # coveralls-ignore-stop
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
      # coveralls-ignore-start
    rescue
      e ->
        %{acc | write_error: Exception.message(e)}
        # coveralls-ignore-stop
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

  # This might happen but only in super-strange cases
  defp handle_stream_result({:ok, %{write_error: reason}}, tmp_path, _path)
       when not is_nil(reason) do
    # coveralls-ignore-start
    cleanup_tmp(tmp_path)
    # coveralls-ignore-stop
    {:error, {:write_failed, reason}}
  end

  defp handle_stream_result({:ok, %{status: 200}}, tmp_path, path) do
    finalize_download(tmp_path, path)
  end

  defp handle_stream_result({:ok, %{status: status, err_body: body}}, tmp_path, _path)
       when is_integer(status) do
    cleanup_tmp(tmp_path)
    {:error, {:http_error, status, String.trim(body)}}
  end

  defp handle_stream_result({:ok, _acc}, tmp_path, _path) do
    cleanup_tmp(tmp_path)
    {:error, :no_status}
  end

  defp handle_stream_result({:error, exception, _stacktrace}, tmp_path, _path) do
    cleanup_tmp(tmp_path)
    {:error, {:stream_failed, normalize_stream_error(exception)}}
  end

  defp normalize_stream_error(%{reason: reason}), do: reason
  defp normalize_stream_error(reason), do: reason
end
