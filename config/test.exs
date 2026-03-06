import Config

config :elixir_lokalise_api,
  api_token: "fake_token",
  http_client: ExLokaliseTransfer.HTTPClientMock,
  request_options: [
    receive_timeout: 5_000,
    connect_timeout: 5_000
  ]

config :ex_lokalise_transfer,
  project_id: "test-project-id"

config :logger, level: :error
