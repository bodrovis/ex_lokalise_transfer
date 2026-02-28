defmodule ExLokaliseSync.Config do
  @moduledoc """
  Configuration loader for ExLokaliseSync.

  Handles:
    - `project_id`
    - `api_token` (with fallback to the SDK config)
    - `body` (request payload/options for Lokalise)
    - `retry` (retry/backoff configuration)

  Resolution priority for project_id and api_token:
    1. opts[:key]
    2. Application env (:ex_lokalise_sync)
    3. For api_token only: fallback to ElixirLokaliseApi.Config.api_token/0
    4. Otherwise: raises an error

  For `body` and `retry`:
    - default_opts are merged with opts (opts win)
    - then body/retry are taken from the merged keyword list
  """

  @type t :: %__MODULE__{
          project_id: String.t(),
          api_token: String.t(),
          body: Keyword.t(),
          retry: Keyword.t()
        }

  defstruct [:project_id, :api_token, body: [], retry: []]

  @app :ex_lokalise_sync

  @spec build(Keyword.t(), Keyword.t()) :: t()
  def build(opts \\ [], default_opts \\ []) do
    # project_id and api_token do NOT depend on default_opts
    project_id =
      opts[:project_id] ||
        get_from_app_env(:project_id) ||
        raise """
        ExLokaliseSync: `project_id` is required.
        Set it via config(:ex_lokalise_sync, project_id: ...) or pass project_id: in opts.
        """

    api_token =
      opts[:api_token] ||
        get_from_app_env(:api_token) ||
        sdk_api_token() ||
        raise """
        ExLokaliseSync: no `api_token` available.
        Provide it via opts, config(:ex_lokalise_sync, api_token: ...),
        or ensure the SDK token is configured in :elixir_lokalise_api.
        """

    body = :body |> do_opts_override(default_opts, opts)

    retry = :retry |> do_opts_override(default_opts, opts)

    %__MODULE__{
      project_id: project_id,
      api_token: api_token,
      body: body,
      retry: retry
    }
  end

  # === Private ===

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

  defp sdk_api_token do
    provider_mod =
      Application.get_env(@app, :token_provider, ExLokaliseSync.TokenProvider.SDK)

    try do
      provider_mod.api_token()
    rescue
      _ -> nil
    else
      nil -> nil
      token when is_binary(token) -> token
    end
  end
end
