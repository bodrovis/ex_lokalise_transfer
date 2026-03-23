defmodule ExLokaliseTransfer.Helpers.Normalization do
  def normalize_body(nil), do: %{}
  def normalize_body(body) when is_map(body), do: body
  def normalize_body(body) when is_list(body), do: Map.new(body)
end
