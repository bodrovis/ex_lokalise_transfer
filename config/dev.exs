import Config

config :elixir_lokalise_api,
  api_token: {:system, "LOKALISE_API_TOKEN"}

config :ex_lokalise_sync,
  project_id: {:system, "LOKALISE_PROJECT_ID"}
