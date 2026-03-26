defmodule ExLokaliseTransfer.Uploader.Common do
  @moduledoc """
  Common defaults and validation for uploader flows.
  """

  alias ExLokaliseTransfer.Config

  @spec default_opts() :: Keyword.t()
  def default_opts do
    [
      body: [],
      retry: [
        max_attempts: 3,
        min_sleep_ms: 1_000,
        max_sleep_ms: 60_000,
        jitter: :centered
      ],
      poll: [
        max_attempts: 3,
        min_sleep_ms: 1_000,
        max_sleep_ms: 60_000,
        jitter: :centered
      ],
      extra: [
        locales_path: "./locales",
        include_patterns: ["**/*"],
        exclude_patterns: [],
        lang_resolver: :basename
      ]
    ]
  end

  @spec validate(Config.t()) :: :ok | {:error, term()}
  def validate(%Config{} = config) do
    with :ok <- Config.validate_common(config),
         :ok <- validate_body(config.body) do
      validate_extra(config.extra)
    end
  end

  @spec validate_body(Keyword.t()) :: :ok | {:error, term()}
  defp validate_body(_body) do
    :ok
  end

  @spec validate_extra(Keyword.t()) :: :ok | {:error, term()}
  defp validate_extra(extra) do
    with :ok <- validate_locales_path(extra),
         :ok <- validate_patterns(extra, :include_patterns),
         :ok <- validate_patterns(extra, :exclude_patterns) do
      validate_lang_resolver(extra)
    end
  end

  defp validate_locales_path(extra) do
    case Keyword.fetch(extra, :locales_path) do
      :error ->
        {:error, {:missing, :locales_path}}

      {:ok, path} when is_binary(path) ->
        case String.trim(path) do
          "" -> {:error, {:invalid, :locales_path, :empty_or_whitespace}}
          _ -> :ok
        end

      {:ok, _other} ->
        {:error, {:invalid, :locales_path, :not_binary}}
    end
  end

  defp validate_patterns(extra, field) do
    case Keyword.fetch(extra, field) do
      :error ->
        {:error, {:missing, field}}

      {:ok, patterns} when is_list(patterns) ->
        if Enum.all?(patterns, &(is_binary(&1) and String.trim(&1) != "")) do
          :ok
        else
          {:error, {:invalid, field, :must_be_non_empty_string_list}}
        end

      {:ok, _other} ->
        {:error, {:invalid, field, :not_list}}
    end
  end

  defp validate_lang_resolver(extra) do
    case Keyword.fetch(extra, :lang_resolver) do
      :error ->
        {:error, {:missing, :lang_resolver}}

      {:ok, :basename} ->
        :ok

      {:ok, fun} when is_function(fun, 1) ->
        :ok

      {:ok, {mod, fun, args}}
      when is_atom(mod) and is_atom(fun) and is_list(args) ->
        :ok

      {:ok, other} ->
        {:error, {:invalid, :lang_resolver, other}}
    end
  end
end
