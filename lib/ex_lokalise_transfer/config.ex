defmodule ExLokaliseTransfer.Config do
  @moduledoc """
  Configuration loader for ExLokaliseTransfer.

  Handles:
    - `project_id`
    - `body` (request payload/options for Lokalise)
    - `retry` (retry/backoff configuration)
    - `extra` (feature-specific extra options)
  """

  @type t :: %__MODULE__{
          project_id: String.t(),
          body: Keyword.t(),
          retry: Keyword.t(),
          extra: Keyword.t()
        }

  defstruct [:project_id, body: [], retry: [], extra: []]

  @app :ex_lokalise_transfer

  @spec build(Keyword.t(), Keyword.t()) :: t()
  def build(opts \\ [], default_opts \\ []) do
    project_id =
      opts[:project_id] ||
        get_from_app_env(:project_id) ||
        raise """
        ExLokaliseTransfer: `project_id` is required.
        Set it via config(:ex_lokalise_transfer, project_id: ...) or pass project_id: in opts.
        """

    body = do_opts_override(:body, default_opts, opts)
    retry = do_opts_override(:retry, default_opts, opts)
    extra = do_opts_override(:extra, default_opts, opts)

    %__MODULE__{
      project_id: project_id,
      body: body,
      retry: retry,
      extra: extra
    }
  end

  @spec validate_common(t()) :: :ok | {:error, term()}
  def validate_common(%__MODULE__{} = config) do
    with :ok <- validate_non_empty(config.project_id, :project_id),
         :ok <- validate_keyword_or_empty(config.body, :body),
         :ok <- validate_retry(config.retry),
         :ok <- validate_keyword_or_empty(config.extra, :extra) do
      :ok
    end
  end

  # === Private ===

  defp validate_non_empty(value, field) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, {:invalid, field, :empty_or_whitespace}}
      _ -> :ok
    end
  end

  defp validate_non_empty(_value, field) do
    {:error, {:invalid, field, :not_binary}}
  end

  defp validate_keyword_or_empty(nil, _field), do: :ok

  defp validate_keyword_or_empty(value, field) when is_list(value) do
    if Keyword.keyword?(value) do
      :ok
    else
      {:error, {:invalid, field, :not_keyword}}
    end
  end

  defp validate_keyword_or_empty(_value, field) do
    {:error, {:invalid, field, :not_keyword}}
  end

  defp validate_retry(retry) when is_list(retry) do
    if Keyword.keyword?(retry) do
      with :ok <- validate_int_min(retry, :max_attempts, 1),
           :ok <- validate_int_min(retry, :min_sleep_ms, 0),
           :ok <- validate_int_min(retry, :max_sleep_ms, 0),
           :ok <- validate_min_le_max(retry, :min_sleep_ms, :max_sleep_ms),
           :ok <- validate_jitter(retry) do
        :ok
      end
    else
      {:error, {:invalid, :retry, :not_keyword}}
    end
  end

  defp validate_retry(_), do: {:error, {:invalid, :retry, :not_keyword}}

  defp validate_int_min(opts, key, min) do
    val = Keyword.get(opts, key)

    cond do
      not is_integer(val) ->
        {:error, {:invalid, key, :not_integer}}

      val < min ->
        {:error, {:invalid, key, {:lt, min}}}

      true ->
        :ok
    end
  end

  defp validate_min_le_max(opts, min_key, max_key) do
    min = Keyword.get(opts, min_key)
    max = Keyword.get(opts, max_key)

    cond do
      not is_integer(min) or not is_integer(max) ->
        {:error, {:invalid, :retry_sleep_ms, :not_integer}}

      min > max ->
        {:error, {:invalid, :retry_sleep_ms, :min_gt_max}}

      true ->
        :ok
    end
  end

  defp validate_jitter(opts) do
    case Keyword.get(opts, :jitter) do
      :full -> :ok
      :centered -> :ok
      other -> {:error, {:invalid, :retry_jitter, other}}
    end
  end

  defp do_opts_override(key, default_opts, opts) do
    defaults = Keyword.get(default_opts, key, [])
    overrides = Keyword.get(opts, key, [])

    defaults
    |> Keyword.merge(overrides, fn _k, _d, o -> o end)
  end

  defp get_from_app_env(key) do
    case Application.get_env(@app, key) do
      nil ->
        nil

      {:system, env_name} when is_binary(env_name) ->
        System.get_env(env_name)

      value ->
        value
    end
  end
end
