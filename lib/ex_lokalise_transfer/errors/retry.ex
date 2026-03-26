defmodule ExLokaliseTransfer.Retry do
  @moduledoc """
  Retries operations that return `{:ok, term}` or `{:error, term}`.

  Errors are normalized into `%Error{}`, checked for retryability, and retried
  with exponential backoff and jitter up to the configured attempt limit.
  """

  @behaviour ExLokaliseTransfer.RetryBehaviour

  require Logger

  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Helpers.Backoff
  alias ExLokaliseTransfer.Errors.Retryable

  @type jitter_mode :: :full | :centered

  @type retry_opts :: [
          max_attempts: pos_integer(),
          min_sleep_ms: non_neg_integer(),
          max_sleep_ms: non_neg_integer(),
          jitter: jitter_mode()
        ]

  @doc """
  Runs a zero-arity operation with retries.

  The operation is retried only when the normalized error is classified as retryable.
  """
  @spec run((-> {:ok, term()} | {:error, term()}), Error.source(), retry_opts()) ::
          {:ok, term()} | {:error, Error.t()}
  def run(fun, source, opts) when is_function(fun, 0) and is_list(opts) do
    max_attempts = Keyword.fetch!(opts, :max_attempts)
    do_run(fun, source, opts, 1, max_attempts)
  end

  defp do_run(fun, source, opts, attempt_idx, max_attempts) do
    case fun.() do
      {:ok, _} = ok ->
        ok

      {:error, _} = err ->
        handle_error(fun, err, source, opts, attempt_idx, max_attempts)
    end
  end

  defp handle_error(fun, err, source, opts, attempt_idx, max_attempts) do
    {:error, e} = Error.normalize(err, source)

    if should_retry?(e, attempt_idx, max_attempts) do
      sleep_ms = retry_sleep_ms(attempt_idx, opts)

      log_retry(e, attempt_idx, max_attempts, sleep_ms)
      Process.sleep(sleep_ms)

      do_run(fun, source, opts, attempt_idx + 1, max_attempts)
    else
      log_give_up(e, attempt_idx, max_attempts)
      {:error, e}
    end
  end

  defp should_retry?(%Error{} = e, attempt_idx, max_attempts) do
    Retryable.retryable?(e) and attempt_idx < max_attempts
  end

  # attempt_idx=1 -> first attempt failed -> first retry sleep
  defp retry_sleep_ms(attempt_idx, opts) do
    Backoff.backoff_ms(attempt_idx, opts)
  end

  defp log_retry(%Error{} = e, attempt_idx, max_attempts, sleep_ms) do
    source = e.source
    kind = e.kind
    status = e.status
    code = e.code

    Logger.debug("retrying after error",
      source: source,
      kind: kind,
      status: status,
      code: code,
      classification: Retryable.classify(e),
      attempt: attempt_idx,
      max_attempts: max_attempts,
      retry_in_ms: sleep_ms
    )
  end

  defp log_give_up(%Error{} = e, attempt_idx, max_attempts) do
    source = e.source
    kind = e.kind
    status = e.status

    Logger.warning("giving up after error",
      source: source,
      kind: kind,
      status: status,
      attempt: attempt_idx,
      max_attempts: max_attempts,
      retryable: Retryable.retryable?(e)
    )
  end
end
