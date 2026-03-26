defmodule ExLokaliseTransfer.Helpers.Backoff do
  @behaviour ExLokaliseTransfer.Helpers.BackoffBehaviour

  # failed_attempt_n: 1,2,3... (not attempt_idx)
  def backoff_ms(failed_attempt_n, opts)
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
