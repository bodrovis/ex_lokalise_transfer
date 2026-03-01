defmodule ExLokaliseTransfer.Config do
  @moduledoc """
  Configuration loader for ExLokaliseTransfer.

  Handles:
    - `project_id`
    - `body` (request payload/options for Lokalise)
    - `retry` (retry/backoff configuration)
  """

  @type t :: %__MODULE__{
          project_id: String.t(),
          body: Keyword.t(),
          retry: Keyword.t()
        }

  defstruct [:project_id, body: [], retry: []]

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

    body = :body |> do_opts_override(default_opts, opts)

    retry = :retry |> do_opts_override(default_opts, opts)

    %__MODULE__{
      project_id: project_id,
      body: body,
      retry: retry
    }
  end

  @spec validate_common(t()) :: :ok | {:error, term()}
  def validate_common(%__MODULE__{} = config) do
    with :ok <- validate_non_empty(config.project_id, :project_id),
         :ok <- validate_retry(config.retry) do
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

  defp validate_retry(retry) when is_list(retry) do
    max_attempts = Keyword.get(retry, :max_attempts)

    cond do
      not is_integer(max_attempts) ->
        {:error, {:invalid, :retry_max_attempts, :not_integer}}

      max_attempts < 1 ->
        {:error, {:invalid, :retry_max_attempts, :lt_1}}

      true ->
        :ok
    end
  end

  defp validate_retry(_), do: {:error, {:invalid, :retry, :not_keyword}}

  defp do_opts_override(key, default_opts, opts) do
    defaults = Keyword.get(default_opts, key, [])
    overrides = Keyword.get(opts, key, [])
    defaults |> Keyword.merge(overrides, fn _k, _d, o -> o end)
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
