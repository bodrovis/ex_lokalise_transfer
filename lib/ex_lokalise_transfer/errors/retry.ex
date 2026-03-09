defmodule ExLokaliseTransfer.Retry do
  @moduledoc """
  Retries operations that return `{:ok, term}` or `{:error, term}`.

  Errors are normalized into `%Error{}`, checked for retryability, and retried
  with exponential backoff and jitter up to the configured attempt limit.
  """

  require Logger

  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Errors.Retryable

  @type jitter_mode :: :full | :centered

  @type retry_opts :: [
          max_attempts: pos_integer(),
          min_sleep_ms: pos_integer(),
          max_sleep_ms: pos_integer(),
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
    backoff_ms(attempt_idx, opts)
  end

  defp log_retry(%Error{} = e, attempt_idx, max_attempts, sleep_ms) do
    Logger.debug("retrying after error",
      source: e.source,
      kind: e.kind,
      status: e.status,
      code: e.code,
      classification: Retryable.classify(e),
      attempt: attempt_idx,
      max_attempts: max_attempts,
      retry_in_ms: sleep_ms
    )
  end

  defp log_give_up(%Error{} = e, attempt_idx, max_attempts) do
    Logger.warning("giving up after error",
      source: e.source,
      kind: e.kind,
      status: e.status,
      attempt: attempt_idx,
      max_attempts: max_attempts,
      retryable: Retryable.retryable?(e)
    )
  end

  # failed_attempt_n: 1,2,3... (not attempt_idx)
  defp backoff_ms(failed_attempt_n, opts)
       when is_integer(failed_attempt_n) and failed_attempt_n >= 1 do
    min = Keyword.fetch!(opts, :min_sleep_ms)
    max = Keyword.fetch!(opts, :max_sleep_ms)
    jitter = Keyword.get(opts, :jitter, :centered)

    # failed_attempt_n=1 -> min*2^0 = min
    # failed_attempt_n=2 -> min*2^1 = 2*min
    exp = min * Integer.pow(2, failed_attempt_n - 1)
    base = clamp(exp, min, max)

    base
    |> apply_jitter(jitter)
    |> clamp(0, max)
  end

  defp apply_jitter(base, :full) do
    # 0..base
    :rand.uniform(base + 1) - 1
  end

  defp apply_jitter(base, :centered) do
    # base*(0.5..1.5) using ints:
    half = div(base, 2)
    half + (:rand.uniform(base + 1) - 1)
  end

  defp apply_jitter(base, _), do: base

  defp clamp(x, min, _max) when x < min, do: min
  defp clamp(x, _min, max) when x > max, do: max
  defp clamp(x, _min, _max), do: x
end
