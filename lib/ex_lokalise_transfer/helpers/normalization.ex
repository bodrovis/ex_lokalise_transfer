defmodule ExLokaliseTransfer.Helpers.Normalization do
  @moduledoc """
  Helpers for normalizing input data structures.

  Provides utilities to convert different input formats into a consistent map.
  """

  @doc """
  Normalizes the given body into a map.
  """
  def normalize_body(nil), do: %{}
  def normalize_body(body) when is_map(body), do: body
  def normalize_body(body) when is_list(body), do: Map.new(body)
end
