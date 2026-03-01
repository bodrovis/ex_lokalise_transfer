import Config

config :elixir_lokalise_api,
  api_token: {:system, "LOKALISE_API_TOKEN"}

config :ex_lokalise_transfer,
  project_id: {:system, "LOKALISE_PROJECT_ID"}

config :logger, :default_handler,
  format: "[$level] $message\n",
  metadata: [:project_id, :operation],
  level: :debug
