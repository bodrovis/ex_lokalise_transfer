# ExLokaliseTransfer

![CI](https://github.com/bodrovis/ex_lokalise_transfer/actions/workflows/ci.yml/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/bodrovis/ex_lokalise_transfer/badge.svg?branch=master)](https://coveralls.io/github/lokalise/elixir-lokalise-api?branch=master)
[![Module Version](https://img.shields.io/hexpm/v/ex_lokalise_transfer.svg)](https://hex.pm/packages/ex_lokalise_transfer)
[![Total Download](https://img.shields.io/hexpm/dt/elixir_lokalise_api.svg)](https://hex.pm/packages/elixir_lokalise_api)

`ExLokaliseTransfer` is a wrapper around Lokalise API download and upload endpoints for Elixir projects.

It provides:

- sync and async download of translation bundles
- async upload of locale files
- retry/backoff handling
- polling for async processes
- local extraction utilities

## Getting started

### Requirements

- Lokalise project
- Lokalise API token with read/write access  
  (read-only tokens work for downloads only)

### Installation

```elixir
def deps do
  [
    {:ex_lokalise_transfer, "~> 0.1.0"}
  ]
end
```

## Required application config

The following config is required globally.

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

### Sync download

Downloads a bundle directly and extracts it locally.

```elixir
# You can also use ExLokaliseTransfer.download_sync()
ExLokaliseTransfer.download(
  body: [
    format: "json",
    original_filenames: false
  ],
  extra: [
    extract_to: "./priv/locales"
  ]
)
```

Returns: `:ok | {:error, reason}`.

### Async download

Enqueues a bundle build in Lokalise, waits for completion, then downloads and extracts it.

```elixir
ExLokaliseTransfer.download_async(
  body: [
    format: "json"
  ],
  poll: [
    max_attempts: 15,
    min_sleep_ms: 3_000,
    max_sleep_ms: 60_000,
    jitter: :centered
  ],
  extra: [
    extract_to: "./priv/locales"
  ]
)
```

## Uploading translations

### Async upload

Uploads multiple locale files and processes them asynchronously.

```elixir
{:ok, summary} =
  ExLokaliseTransfer.upload(
    body: [
      format: "json"
    ],
    extra: [
      locales_path: "./priv/locales",
      include_patterns: ["*.json"],
      exclude_patterns: [],
      lang_resolver: :basename
    ],
    poll: [
      max_attempts: 10,
      min_sleep_ms: 3_000,
      max_sleep_ms: 60_000,
      jitter: :centered
    ]
  )
```

Returns: `{:ok, summary} | {:error, summary}`

#### Summary structure

```elixir
%{
  discovered_entries: [Entry.t()],
  enqueue_successes: [
    %{entry: Entry.t(), process_id: String.t()}
  ],
  enqueue_errors: [
    %{entry: Entry.t(), error: term()}
  ],
  process_results: [
    %{
      entry: Entry.t(),
      process_id: String.t(),
      result: {:ok, map()} | {:error, term()}
    }
  ],
  errors: [term()]
}
```

## Options

All flows share a common structure of options:

```elixir
[
  body: [...],
  retry: [...],
  poll: [...],
  extra: [...]
]
```

### body — Lokalise API options

Passed directly to Lokalise bundle/upload requests.

Example:

```elixir
body: [
  format: "json",
  original_filenames: true,
  directory_prefix: "",
  indentation: "2sp"
]
```

- `format` (required for download)
- any other fields supported by Lokalise API

### retry — retry/backoff configuration

Used for API calls and downloads.

```elixir
retry: [
  max_attempts: 3,
  min_sleep_ms: 1_000,
  max_sleep_ms: 60_000,
  jitter: :centered
]
```

- `max_attempts` — total attempts (including first)
- `min_sleep_ms` — minimum delay
- `max_sleep_ms` — maximum delay
- `jitter` — `:centered` or `:full`

### poll — async polling configuration

Used only in async flows.

```elixir
poll: [
  max_attempts: 10,
  min_sleep_ms: 3_000,
  max_sleep_ms: 60_000,
  jitter: :centered
]
```

Controls how long the system waits for Lokalise async processes.

### extra — local behaviour options

#### Download

```elixir
extra: [
  extract_to: "./priv/locales"
]
```

- `extract_to` — target directory for extracted files (automatically expanded to absolute path)

## Testing

Run:

```
mix test
```

To see coverage:

```
mix coveralls.html
```

### Integration testing

To run integration tests:

```
mix test --include integration
```

Note that in this case you'll need to set `LOKALISE_API_TOKEN` and `LOKALISE_PROJECT_ID` environment variables.

## License

MIT (c) [Elijah S. Krukowski](https://bodrovis.tech)