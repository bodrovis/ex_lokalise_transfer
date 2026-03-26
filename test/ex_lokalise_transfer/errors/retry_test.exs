defmodule ExLokaliseTransfer.RetryTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Retry

  @opts_fast [max_attempts: 3, min_sleep_ms: 1, max_sleep_ms: 1, jitter: :full]

  defp with_counter(fun) do
    {:ok, pid} = Agent.start_link(fn -> 0 end)

    try do
      fun.(pid)
    after
      Agent.stop(pid)
    end
  end

  defp inc(pid), do: Agent.get_and_update(pid, fn n -> {n + 1, n + 1} end)
  defp get(pid), do: Agent.get(pid, & &1)

  describe "run/3" do
    test "returns ok without retries when operation succeeds first time" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:ok, :done}
        end

        assert {:ok, :done} = Retry.run(op, :lokalise, @opts_fast)
        assert get(counter) == 1
      end)
    end

    test "retries retryable http error and succeeds" do
      with_counter(fn counter ->
        op = fn ->
          n = inc(counter)

          if n < 3 do
            # retryable http error (429)
            {:error, {~s({"message":"msg","statusCode":429,"error":"Too Many Requests"}), 429}}
          else
            {:ok, :yay}
          end
        end

        assert {:ok, :yay} = Retry.run(op, :lokalise, @opts_fast)
        assert get(counter) == 3
      end)
    end

    test "with max_attempts 1 performs only one attempt even for retryable error" do
      opts = [max_attempts: 1, min_sleep_ms: 1, max_sleep_ms: 1, jitter: :full]

      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, {~s({"message":"msg","statusCode":429,"error":"Too Many Requests"}), 429}}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, opts)
        assert err.kind == :http
        assert err.status == 429
        assert get(counter) == 1
      end)
    end

    test "stops after max_attempts and returns normalized error (http retryable)" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, {~s({"message":"msg","statusCode":429,"error":"Too Many Requests"}), 429}}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, @opts_fast)
        assert err.kind == :http
        assert err.status == 429
        assert get(counter) == 3
      end)
    end

    test "does not retry message error" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, "plain error"}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, @opts_fast)
        assert err.kind == :message
        assert err.message == "plain error"
        assert get(counter) == 1
      end)
    end

    test "does not retry unexpected error shape" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, {:weird, :shape, 123}}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, @opts_fast)
        assert err.kind == :unexpected
        assert get(counter) == 1
      end)
    end

    test "retries transport error until max_attempts then returns error" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, :timeout}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, @opts_fast)
        assert err.kind == :transport
        assert get(counter) == 3
      end)
    end

    test "does not retry non-retryable http error (404) and returns after first attempt" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, {~s({"message":"nope","error":"Not found"}), 404}}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, @opts_fast)
        assert err.kind == :http
        assert err.status == 404
        assert get(counter) == 1
      end)
    end

    test "does not retry non-retryable transport reason (invalid_uri)" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, :invalid_uri}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, @opts_fast)
        assert err.kind == :transport
        assert get(counter) == 1
      end)
    end

    test "retries transport error and succeeds" do
      with_counter(fn counter ->
        op = fn ->
          n = inc(counter)

          if n < 2 do
            {:error, :timeout}
          else
            {:ok, :ok}
          end
        end

        assert {:ok, :ok} = Retry.run(op, :lokalise, @opts_fast)
        assert get(counter) == 2
      end)
    end

    test "transport error with unknown reason_atom IS retried (optimistic)" do
      with_counter(fn counter ->
        op = fn ->
          inc(counter)
          {:error, :weird_transport}
        end

        assert {:error, %Error{} = err} = Retry.run(op, :lokalise, @opts_fast)
        assert err.kind == :transport
        assert get(counter) == 3
      end)
    end

    test "retries generic http 503 even for non-lokalise source" do
      with_counter(fn counter ->
        op = fn ->
          n = inc(counter)

          if n < 2 do
            {:error, {"Service Unavailable", 503}}
          else
            {:ok, :ok}
          end
        end

        assert {:ok, :ok} = Retry.run(op, :s3, @opts_fast)
        assert get(counter) == 2
      end)
    end
  end
end
