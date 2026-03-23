defmodule ExLokaliseTransfer.Uploader.Files do
  @moduledoc """
  Discovers local files for upload.

  The module scans `extra[:locales_path]` using include/exclude glob patterns and
  returns file entries with both absolute and project-relative paths, plus a
  resolved `lang_iso` for each file.
  """

  alias ExLokaliseTransfer.Uploader.Files.Entry

  @type lang_resolver ::
          :basename
          | (Entry.t() -> String.t() | nil)
          | {module(), atom(), [term()]}

  @doc """
  Discovers files under `extra[:locales_path]`.

  Expected keys in `extra`:
    - `:locales_path`
    - `:include_patterns`
    - `:exclude_patterns`
    - optional `:lang_resolver`

  `lang_resolver` may be:
    - `:basename` (default)
    - `fn entry -> "en" end`
    - `{Mod, :fun, extra_args}` where `fun` is called as `fun(entry, ...extra_args)`

  Returns `{:ok, entries}` on success.
  """
  @spec discover(Keyword.t()) :: {:ok, [Entry.t()]} | {:error, term()}
  def discover(extra) when is_list(extra) do
    locales_path = resolve_locales_path(extra)
    include_patterns = Keyword.get(extra, :include_patterns, ["**/*"])
    exclude_patterns = Keyword.get(extra, :exclude_patterns, [])
    lang_resolver = Keyword.get(extra, :lang_resolver, :basename)

    with :ok <- ensure_dir_exists(locales_path),
         :ok <- validate_patterns(include_patterns, :include_patterns),
         :ok <- validate_patterns(exclude_patterns, :exclude_patterns),
         :ok <- validate_lang_resolver(lang_resolver),
         {:ok, entries} <- build_entries(locales_path, include_patterns, exclude_patterns),
         {:ok, entries} <- resolve_langs(entries, lang_resolver) do
      {:ok, entries}
    end
  end

  @doc """
  Resolves `extra[:locales_path]` to an absolute path.
  """
  @spec resolve_locales_path(Keyword.t()) :: String.t()
  def resolve_locales_path(extra) do
    extra
    |> Keyword.fetch!(:locales_path)
    |> Path.expand()
  end

  @doc """
  Resolves `lang_iso` for a list of discovered entries.
  """
  @spec resolve_langs([Entry.t()], lang_resolver()) :: {:ok, [Entry.t()]} | {:error, term()}
  def resolve_langs(entries, resolver) when is_list(entries) do
    entries
    |> Enum.reduce_while({:ok, []}, fn %Entry{} = entry, {:ok, acc} ->
      case resolve_lang(entry, resolver) do
        {:ok, lang_iso} ->
          {:cont, {:ok, [%Entry{entry | lang_iso: lang_iso} | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, entries_rev} -> {:ok, Enum.reverse(entries_rev)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_entries(locales_path, include_patterns, exclude_patterns) do
    included = wildcard_files(locales_path, include_patterns)
    excluded = wildcard_files(locales_path, exclude_patterns) |> MapSet.new()

    entries =
      included
      |> Enum.reject(&MapSet.member?(excluded, &1))
      |> Enum.map(&build_entry!/1)

    {:ok, entries}
  end

  defp ensure_dir_exists(path) do
    case File.dir?(path) do
      true -> :ok
      false -> {:error, {:locales_path_not_found, path}}
    end
  end

  defp validate_patterns(patterns, field) when is_list(patterns) do
    if Enum.all?(patterns, &(is_binary(&1) and String.trim(&1) != "")) do
      :ok
    else
      {:error, {:invalid, field, :must_be_non_empty_string_list}}
    end
  end

  defp validate_patterns(_patterns, field) do
    {:error, {:invalid, field, :not_list}}
  end

  defp validate_lang_resolver(:basename), do: :ok
  defp validate_lang_resolver(fun) when is_function(fun, 1), do: :ok

  defp validate_lang_resolver({mod, fun, args})
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: :ok

  defp validate_lang_resolver(other) do
    {:error, {:invalid, :lang_resolver, other}}
  end

  defp wildcard_files(_base_path, []), do: []

  defp wildcard_files(base_path, patterns) do
    patterns
    |> Enum.flat_map(fn pattern ->
      base_path
      |> Path.join(pattern)
      |> Path.wildcard()
    end)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp build_entry!(abs_path) do
    %Entry{
      abs_path: abs_path,
      rel_path: build_rel_path(abs_path),
      basename: Path.basename(abs_path),
      ext: Path.extname(abs_path),
      lang_iso: ""
    }
  end

  defp build_rel_path(abs_path) do
    abs_path
    |> Path.relative_to_cwd()
    |> normalize_rel_path()
  end

  defp normalize_rel_path(path) do
    path
    |> Path.split()
    |> Path.join()
  end

  defp resolve_lang(entry, :basename) do
    lang_iso =
      entry.basename
      |> Path.rootname()
      |> String.trim()

    if lang_iso == "" do
      {:error, {:invalid_lang_iso, entry.rel_path, :empty}}
    else
      {:ok, lang_iso}
    end
  end

  defp resolve_lang(%Entry{} = entry, fun) when is_function(fun, 1) do
    case fun.(entry) do
      lang_iso when is_binary(lang_iso) ->
        normalize_lang_iso(lang_iso, entry)

      nil ->
        {:error, {:invalid_lang_iso, entry.rel_path, nil}}

      other ->
        {:error, {:invalid_lang_iso, entry.rel_path, other}}
    end
  end

  defp resolve_lang(%Entry{} = entry, {mod, fun, args}) do
    case apply(mod, fun, [entry | args]) do
      lang_iso when is_binary(lang_iso) ->
        normalize_lang_iso(lang_iso, entry)

      nil ->
        {:error, {:invalid_lang_iso, entry.rel_path, nil}}

      other ->
        {:error, {:invalid_lang_iso, entry.rel_path, other}}
    end
  end

  defp normalize_lang_iso(lang_iso, entry) when is_binary(lang_iso) do
    trimmed = String.trim(lang_iso)

    if trimmed == "" do
      {:error, {:invalid_lang_iso, entry.rel_path, :empty_or_whitespace}}
    else
      {:ok, trimmed}
    end
  end
end
