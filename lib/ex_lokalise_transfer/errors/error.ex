defmodule ExLokaliseTransfer.Errors.Error do
  @moduledoc """
  Unified error normalization for Lokalise API, S3 bundle downloads, and transport failures.
  """

  @enforce_keys [:kind, :message]
  defstruct source: :unknown,
            kind: :unexpected,
            status: nil,
            code: nil,
            message: nil,
            reason: nil,
            raw: nil,
            details: %{}

  @type source :: :lokalise | :s3 | :http | :sdk | :unknown
  @type kind :: :http | :transport | :message | :unexpected

  @type t :: %__MODULE__{
          source: source(),
          kind: kind(),
          status: integer() | nil,
          code: integer() | binary() | nil,
          message: binary(),
          reason: binary() | nil,
          raw: binary() | nil,
          details: map()
        }

  @spec normalize({:error, any()}, source()) :: {:error, t()}
  def normalize({:error, {data, status}}, source)
      when is_integer(status) and status >= 100 and status <= 599 do
    {message, reason, code, raw, details} =
      parse_http_body(data, status, source)

    {:error,
     %__MODULE__{
       source: source,
       kind: :http,
       status: status,
       code: code,
       message: message,
       reason: reason,
       raw: raw,
       details: details
     }}
  end

  def normalize({:error, reason}, source) when is_atom(reason) do
    {:error,
     %__MODULE__{
       source: source,
       kind: :transport,
       message: Atom.to_string(reason),
       reason: "transport error",
       details: %{"reason_atom" => reason}
     }}
  end

  def normalize({:error, reason}, source) when is_binary(reason) do
    trimmed = String.trim(reason)

    {:error,
     %__MODULE__{
       source: source,
       kind: :message,
       message: if(trimmed == "", do: "error message", else: trimmed),
       reason: "error message",
       raw: trimmed
     }}
  end

  def normalize({:error, other}, source) do
    {:error,
     %__MODULE__{
       source: source,
       kind: :unexpected,
       message: "unexpected error shape",
       reason: "unexpected error shape",
       details: %{"error" => inspect(other)}
     }}
  end

  # --- Parsing HTTP bodies (Lokalise-specific vs generic best-effort) ---

  defp parse_http_body(data, status, :lokalise) do
    raw = body_to_string(data)
    trimmed = String.trim(raw)

    cond do
      non_json?(trimmed) ->
        {http_status_text(status), "non-json error body", nil, trimmed, %{}}

      true ->
        case Jason.decode(trimmed) do
          {:ok, json} ->
            parse_lokalise_json(json, status, trimmed)

          {:error, err} ->
            {http_status_text(status), "invalid json in error body", nil, trimmed,
             %{"unmarshal_error" => Exception.message(err)}}
        end
    end
  end

  defp parse_http_body(data, status, _source) do
    raw = body_to_string(data)
    trimmed = String.trim(raw)

    cond do
      trimmed == "" ->
        {http_status_text(status), "empty error body", nil, trimmed, %{}}

      non_json?(trimmed) ->
        # Best-effort for S3 XML: <Code>...</Code> <Message>...</Message>
        {msg, code} = xml_best_effort(trimmed, status)
        {msg, "non-json error body", code, trimmed, %{}}

      true ->
        case Jason.decode(trimmed) do
          {:ok, json} ->
            parse_generic_json(json, status, trimmed)

          {:error, err} ->
            {http_status_text(status), "invalid json in error body", nil, trimmed,
             %{"unmarshal_error" => Exception.message(err)}}
        end
    end
  end

  # --- Lokalise JSON shapes ---

  defp parse_lokalise_json(obj, status, raw) when is_map(obj) do
    # 1) {message, statusCode, error}
    with {:ok, msg} <- get_string(obj, "message"),
         {:ok, sc} <- get_int(obj, "statusCode"),
         {:ok, reason} <- get_string(obj, "error") do
      {msg, reason, sc, raw, obj}
    else
      _ ->
        # 2) {error: {message, code, details}}
        case obj do
          %{"error" => %{} = err_obj} ->
            msg = get_string_or_nil(err_obj, "message")
            code = get_int_or(err_obj, "code", status)

            details =
              cond do
                is_map(err_obj["details"]) -> err_obj["details"]
                Map.has_key?(err_obj, "details") -> %{"details" => err_obj["details"]}
                true -> %{"reason" => "server error without details"}
              end

            {coalesce(msg, http_status_text(status)), nil, code, raw, details}

          _ ->
            # 3) {message, code|errorCode, details}
            case get_string(obj, "message") do
              {:ok, msg} ->
                cond do
                  match?({:ok, _}, get_int(obj, "code")) ->
                    {:ok, code} = get_int(obj, "code")
                    {msg, nil, code, raw, pick_details(obj)}

                  match?({:ok, _}, get_int(obj, "errorCode")) ->
                    {:ok, code} = get_int(obj, "errorCode")
                    {msg, nil, code, raw, pick_details(obj)}

                  true ->
                    fallback_lokalise(obj, status, raw)
                end

              _ ->
                fallback_lokalise(obj, status, raw)
            end
        end
    end
  end

  defp parse_lokalise_json(other, status, raw) do
    {http_status_text(status), "unhandled error format", nil, raw, %{"error_value" => other}}
  end

  defp fallback_lokalise(obj, status, raw) do
    reason = get_string_or_nil(obj, "error")
    msg = coalesce(get_string_or_nil(obj, "message"), http_status_text(status))
    {msg, coalesce(reason, "unhandled error format"), nil, raw, obj}
  end

  # --- Generic JSON best-effort ---

  defp parse_generic_json(obj, status, raw) when is_map(obj) do
    msg =
      get_string_or_nil(obj, "message") ||
        get_string_or_nil(obj, "Message") ||
        http_status_text(status)

    reason =
      get_string_or_nil(obj, "error") ||
        get_string_or_nil(obj, "Error") ||
        get_string_or_nil(obj, "reason")

    code =
      get_int_or(obj, "code", nil) ||
        get_int_or(obj, "statusCode", nil) ||
        get_int_or(obj, "errorCode", nil)

    {msg, reason, code, raw, pick_details(obj)}
  end

  defp parse_generic_json(other, status, raw) do
    {http_status_text(status), "unhandled error format", nil, raw, %{"error_value" => other}}
  end

  # --- Tiny XML best-effort (S3-style) ---

  defp xml_best_effort(raw, status) do
    code = between(raw, "<Code>", "</Code>")
    msg = between(raw, "<Message>", "</Message>")

    final_msg =
      cond do
        msg && msg != "" -> msg
        code && code != "" -> "#{code} (#{http_status_text(status)})"
        true -> http_status_text(status)
      end

    {final_msg, code}
  end

  defp between(str, a, b) do
    case String.split(str, a, parts: 2) do
      [_, rest] ->
        case String.split(rest, b, parts: 2) do
          [mid, _] -> String.trim(mid)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # --- helpers ---

  defp pick_details(obj) do
    cond do
      is_map(obj["details"]) -> obj["details"]
      Map.has_key?(obj, "details") -> %{"details" => obj["details"]}
      true -> obj
    end
  end

  defp get_string(map, key) do
    case Map.get(map, key) do
      v when is_binary(v) and byte_size(v) > 0 -> {:ok, v}
      _ -> :error
    end
  end

  defp get_string_or_nil(map, key) do
    case Map.get(map, key) do
      v when is_binary(v) and byte_size(v) > 0 -> v
      _ -> nil
    end
  end

  defp get_int(map, key) do
    case Map.get(map, key) do
      v when is_integer(v) ->
        {:ok, v}

      v when is_float(v) ->
        {:ok, trunc(v)}

      v when is_binary(v) ->
        case Integer.parse(v) do
          {i, ""} -> {:ok, i}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp get_int_or(map, key, default) do
    case get_int(map, key) do
      {:ok, i} -> i
      _ -> default
    end
  end

  defp coalesce(nil, b), do: b
  defp coalesce("", b), do: b
  defp coalesce(a, _b), do: a

  defp non_json?(""), do: true
  defp non_json?(<<c::utf8, _::binary>>) when c in [?{, ?[], do: false
  defp non_json?(_), do: true

  defp body_to_string(nil), do: ""
  defp body_to_string(body) when is_binary(body), do: body
  defp body_to_string(body) when is_list(body), do: IO.iodata_to_binary(body)
  defp body_to_string(body) when is_map(body), do: Jason.encode!(body)
  defp body_to_string(other), do: inspect(other)

  defp http_status_text(status) do
    case status do
      400 -> "Bad Request"
      401 -> "Unauthorized"
      403 -> "Forbidden"
      404 -> "Not Found"
      408 -> "Request Timeout"
      409 -> "Conflict"
      422 -> "Unprocessable Entity"
      429 -> "Too Many Requests"
      500 -> "Internal Server Error"
      502 -> "Bad Gateway"
      503 -> "Service Unavailable"
      504 -> "Gateway Timeout"
      _ -> "HTTP #{status}"
    end
  end
end
