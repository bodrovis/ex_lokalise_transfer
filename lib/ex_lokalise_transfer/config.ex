defmodule ExLokaliseTransfer.Config do
  @moduledoc """
  Builds and validates runtime configuration for ExLokaliseTransfer.

  The config includes:
    - `project_id`
    - `body` request options
    - `retry` backoff options
    - `poll` polling/backoff options
    - `extra` feature-specific options
  """

  @type t :: %__MODULE__{
          project_id: String.t(),
          body: Keyword.t(),
          retry: Keyword.t(),
          poll: Keyword.t() | nil,
          extra: Keyword.t()
        }

  defstruct [:project_id, body: [], retry: [], poll: nil, extra: []]

  @app :ex_lokalise_transfer

  @doc """
  Builds a `%Config{}` from explicit options and merged defaults.

  `project_id` is taken from `opts`, then application config, and raises if missing.
  """
  @spec build(Keyword.t(), Keyword.t()) :: t()
  def build(opts \\ [], default_opts \\ []) do
    project_id =
      opts[:project_id] ||
        get_from_app_env(:project_id) ||
        raise """
        ExLokaliseTransfer: `project_id` is required.
        Set it via config(:ex_lokalise_transfer, project_id: ...) or pass project_id: in opts.
        """

    body = merge_opts(:body, default_opts, opts)
    retry = merge_opts(:retry, default_opts, opts)
    poll = merge_optional_opts(:poll, default_opts, opts)
    extra = merge_opts(:extra, default_opts, opts)

    %__MODULE__{
      project_id: project_id,
      body: body,
      retry: retry,
      poll: poll,
      extra: extra
    }
  end

  @doc """
  Validates config fields shared across downloader and uploader flows.

  This includes:
    - `project_id`
    - keyword-list shape checks for `body` and `extra`
    - retry backoff validation
    - optional poll backoff validation
  """
  @spec validate_common(t()) :: :ok | {:error, term()}
  def validate_common(%__MODULE__{} = config) do
    with :ok <- validate_non_empty(config.project_id, :project_id),
         :ok <- validate_keyword_or_empty(config.body, :body),
         :ok <- validate_backoff_opts(config.retry, :retry),
         :ok <- validate_optional_backoff_opts(config.poll, :poll),
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

  defp validate_optional_backoff_opts(nil, _field), do: :ok
  defp validate_optional_backoff_opts(opts, field), do: validate_backoff_opts(opts, field)

  defp validate_backoff_opts(opts, field) when is_list(opts) do
    if Keyword.keyword?(opts) do
      with :ok <- validate_int_min(opts, :max_attempts, 1),
           :ok <- validate_int_min(opts, :min_sleep_ms, 0),
           :ok <- validate_int_min(opts, :max_sleep_ms, 0),
           :ok <- validate_min_le_max(opts, field),
           :ok <- validate_jitter(opts, field) do
        :ok
      end
    else
      {:error, {:invalid, field, :not_keyword}}
    end
  end

  defp validate_backoff_opts(_opts, field) do
    {:error, {:invalid, field, :not_keyword}}
  end

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

  defp validate_min_le_max(opts, field) do
    min = Keyword.get(opts, :min_sleep_ms)
    max = Keyword.get(opts, :max_sleep_ms)

    cond do
      not is_integer(min) or not is_integer(max) ->
        {:error, {:invalid, field, :sleep_ms_not_integer}}

      min > max ->
        {:error, {:invalid, field, :min_sleep_gt_max_sleep}}

      true ->
        :ok
    end
  end

  defp validate_jitter(opts, field) do
    case Keyword.get(opts, :jitter) do
      :full -> :ok
      :centered -> :ok
      other -> {:error, {:invalid, field, {:invalid_jitter, other}}}
    end
  end

  defp merge_opts(key, default_opts, opts) do
    defaults = Keyword.get(default_opts, key, [])
    overrides = Keyword.get(opts, key, [])

    Keyword.merge(defaults, overrides)
  end

  defp merge_optional_opts(key, default_opts, opts) do
    defaults = Keyword.get(default_opts, key)
    overrides = Keyword.get(opts, key)

    cond do
      is_nil(defaults) and is_nil(overrides) ->
        nil

      true ->
        Keyword.merge(defaults || [], overrides || [])
    end
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
