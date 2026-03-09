# ExLokaliseTransfer

`ExLokaliseTransfer` provides a wrapper around Lokalise download and upload flows for Elixir projects.

## Getting started

### Requirements

- Lokalise project
- Lokalise API token with read/write access (read-only tokens would work only for downloads)

### Installation

```elixir
def deps do
  [
    {:ex_lokalise_transfer, "~> 0.1.0"}
  ]
end
```

## Required application config

The following config is required globally and is used by both download and upload flows.

Configure the Lokalise API token:

```elixir
config :elixir_lokalise_api,
  api_token: {:system, "LOKALISE_API_TOKEN"}
```

Configure the Lokalise project id:

```elixir
config :ex_lokalise_transfer,
  project_id: {:system, "LOKALISE_PROJECT_ID"}
```

## Downloading translation files

### Download options

You can configure the following options in the form of keyword lists. Most have sensible defaults:

* `body` — options sent to the Lokalise bundle download request. At the very least, `body` must contain the `format` param.
* `extra` — local extraction options
* `retry` — retry/backoff settings

Example:

```elixir
# These are used as defaults:

[
  body: [
    format: "json",
    original_filenames: true,
    directory_prefix: "",
    indentation: "2sp"
    # provide any other params supported by Lokalise API
  ],
  retry: [
    max_attempts: 3,
    min_sleep_ms: 1_000,
    max_sleep_ms: 60_000,
    jitter: :centered
  ],
  extra: [
    # If the path is relative, it is expanded relative
    # to the current working directory
    locales_path: "./locales"
  ]
]
```

### Sync download

To run the sync download flow:

```elixir
opts = [
  body: [
    format: "json",
    original_filenames: false,
    directory_prefix: "translations/",
    indentation: "4sp"
  ],
  extra: [
    locales_path: "./priv/locales"
  ]
]

# Returns :ok or {:error, reason}:
ExLokaliseTransfer.download_sync(opts)
```

The default `download/0` entrypoint curntly uses the same sync download flow:

```elixir
case ExLokaliseTransfer.download() do
  :ok ->
    IO.puts("Download completed")

  {:error, reason} ->
    IO.inspect(reason, label: "Download failed")
end
```

## Retry options

Retry settings are optional and are similar across download and upload flows.

Default retry config:

```elixir
retry: [
  max_attempts: 3,
  min_sleep_ms: 1_000,
  max_sleep_ms: 60_000,
  jitter: :centered
]
```

- `max_attempts` — total number of attempts, including the first one
- `min_sleep_ms` — minimum backoff delay in milliseconds
- `max_sleep_ms` — maximum backoff delay in milliseconds
- `jitter` — backoff jitter mode (`:centered` or `:full`)