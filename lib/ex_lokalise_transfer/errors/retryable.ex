defmodule ExLokaliseTransfer.Errors.Retryable do
  @moduledoc """
  Classifies normalized errors as retryable or non-retryable.

  The policy is based on HTTP status codes, transport failure reasons,
  and the normalized error kind.
  """

  alias ExLokaliseTransfer.Errors.Error

  @retryable_http_statuses MapSet.new([408, 429])
  @non_retryable_http_statuses MapSet.new([400, 401, 403, 404, 422])

  # These are almost certainly not fixed by retrying.
  @non_retryable_transport_reasons MapSet.new([
                                     :invalid_uri,
                                     :badarg,
                                     :nxdomain
                                   ])

  @doc """
  Returns whether the given normalized error should be retried.
  """
  @spec retryable?(Error.t()) :: boolean()
  def retryable?(%Error{kind: :http, status: status}) when status in 100..599 do
    cond do
      MapSet.member?(@retryable_http_statuses, status) -> true
      MapSet.member?(@non_retryable_http_statuses, status) -> false
      status in 500..599 -> true
      status in 400..499 -> false
      true -> false
    end
  end

  def retryable?(%Error{kind: :transport, details: %{"reason_atom" => reason}}) when is_atom(reason) do
    not MapSet.member?(@non_retryable_transport_reasons, reason)
  end

  # If we don't know the reason, assume retryable.
  def retryable?(%Error{kind: :transport}), do: true

  def retryable?(%Error{kind: :message}), do: false
  def retryable?(%Error{kind: :unexpected}), do: false
  def retryable?(_), do: false

  @type classification ::
          :rate_limited
          | :timeout
          | :server
          | :client
          | :transport
          | :message
          | :unexpected
          | :unknown

  @doc """
  Returns a coarse retry-related classification for a normalized error.
  """
  @spec classify(Error.t()) :: classification()
  def classify(%Error{kind: :http, status: 429}), do: :rate_limited
  def classify(%Error{kind: :http, status: 408}), do: :timeout
  def classify(%Error{kind: :http, status: s}) when is_integer(s) and s in 500..599, do: :server
  def classify(%Error{kind: :http, status: s}) when is_integer(s) and s in 400..499, do: :client
  def classify(%Error{kind: :transport}), do: :transport
  def classify(%Error{kind: :message}), do: :message
  def classify(%Error{kind: :unexpected}), do: :unexpected
  def classify(_), do: :unknown
end
