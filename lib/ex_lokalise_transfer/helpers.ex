defmodule ExLokaliseTransfer.Helpers do
  def normalize_body(nil), do: %{}
  def normalize_body(body) when is_map(body), do: body
  def normalize_body(body) when is_list(body), do: Map.new(body)

  def resolve_extract_to(extra) do
    extra
    |> Keyword.fetch!(:extract_to)
    |> Path.expand()
  end
end
