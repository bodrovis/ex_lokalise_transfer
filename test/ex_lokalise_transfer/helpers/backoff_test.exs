defmodule ExLokaliseTransfer.Helpers.BackoffTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Helpers.Backoff

  describe "backoff_ms/2 – base exponential backoff" do
    test "returns min_sleep_ms on first failed attempt" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :unknown]

      assert Backoff.backoff_ms(1, opts) == 100
    end

    test "doubles on each failed attempt before reaching max_sleep_ms" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :unknown]

      assert Backoff.backoff_ms(1, opts) == 100
      assert Backoff.backoff_ms(2, opts) == 200
      assert Backoff.backoff_ms(3, opts) == 400
      assert Backoff.backoff_ms(4, opts) == 800
    end

    test "caps exponential growth at max_sleep_ms" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :unknown]

      assert Backoff.backoff_ms(5, opts) == 1_000
      assert Backoff.backoff_ms(6, opts) == 1_000
      assert Backoff.backoff_ms(10, opts) == 1_000
    end

    test "uses :centered jitter by default when jitter option is missing" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000]

      value = Backoff.backoff_ms(1, opts)

      assert value >= 50
      assert value <= 150
    end

    test "uses base value unchanged for unknown jitter" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :wat]

      assert Backoff.backoff_ms(1, opts) == 100
      assert Backoff.backoff_ms(2, opts) == 200
      assert Backoff.backoff_ms(3, opts) == 400
    end
  end

  describe "backoff_ms/2 – :full jitter" do
    test "returns a value within 0..base before max is reached" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :full]

      for failed_attempt_n <- 1..4 do
        value = Backoff.backoff_ms(failed_attempt_n, opts)
        base = min(100 * Integer.pow(2, failed_attempt_n - 1), 1_000)

        assert value >= 0
        assert value <= base
      end
    end

    test "returns a value within 0..max when exponential backoff is capped" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :full]

      for failed_attempt_n <- 5..8 do
        value = Backoff.backoff_ms(failed_attempt_n, opts)

        assert value >= 0
        assert value <= 1_000
      end
    end

    test "returns 0 when min_sleep_ms and max_sleep_ms are zero" do
      opts = [min_sleep_ms: 0, max_sleep_ms: 0, jitter: :full]

      assert Backoff.backoff_ms(1, opts) == 0
      assert Backoff.backoff_ms(5, opts) == 0
    end
  end

  describe "backoff_ms/2 – :centered jitter" do
    test "returns a value within centered range before max is reached" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :centered]

      for failed_attempt_n <- 1..4 do
        value = Backoff.backoff_ms(failed_attempt_n, opts)
        base = min(100 * Integer.pow(2, failed_attempt_n - 1), 1_000)
        half = div(base, 2)

        assert value >= half
        assert value <= half + base
      end
    end

    test "returns a value clamped to max_sleep_ms after centered jitter overshoots max" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :centered]

      for _ <- 1..50 do
        value = Backoff.backoff_ms(10, opts)

        assert value >= 500
        assert value <= 1_000
      end
    end

    test "returns 0 when base is zero" do
      opts = [min_sleep_ms: 0, max_sleep_ms: 0, jitter: :centered]

      assert Backoff.backoff_ms(1, opts) == 0
      assert Backoff.backoff_ms(3, opts) == 0
    end

    test "works with odd base values using integer division for half" do
      opts = [min_sleep_ms: 101, max_sleep_ms: 1_000, jitter: :centered]

      value = Backoff.backoff_ms(1, opts)

      assert value >= 50
      assert value <= 151
    end
  end

  describe "backoff_ms/2 – clamp behavior" do
    test "never returns a negative value for :full jitter" do
      opts = [min_sleep_ms: 1, max_sleep_ms: 10, jitter: :full]

      for _ <- 1..50 do
        assert Backoff.backoff_ms(1, opts) >= 0
      end
    end

    test "never returns more than max_sleep_ms for :centered jitter" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :centered]

      for failed_attempt_n <- 1..10 do
        for _ <- 1..20 do
          assert Backoff.backoff_ms(failed_attempt_n, opts) <= 1_000
        end
      end
    end

    test "never returns more than max_sleep_ms for :full jitter" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :full]

      for failed_attempt_n <- 1..10 do
        for _ <- 1..20 do
          assert Backoff.backoff_ms(failed_attempt_n, opts) <= 1_000
        end
      end
    end
  end

  describe "backoff_ms/2 – required options" do
    test "raises when min_sleep_ms is missing" do
      opts = [max_sleep_ms: 1_000, jitter: :full]

      assert_raise KeyError, fn ->
        Backoff.backoff_ms(1, opts)
      end
    end

    test "raises when max_sleep_ms is missing" do
      opts = [min_sleep_ms: 100, jitter: :full]

      assert_raise KeyError, fn ->
        Backoff.backoff_ms(1, opts)
      end
    end
  end

  describe "backoff_ms/2 – invalid failed attempt number" do
    test "raises when failed_attempt_n is zero" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :full]

      assert_raise FunctionClauseError, fn ->
        Backoff.backoff_ms(0, opts)
      end
    end

    test "raises when failed_attempt_n is negative" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :full]

      assert_raise FunctionClauseError, fn ->
        Backoff.backoff_ms(-1, opts)
      end
    end

    test "raises when failed_attempt_n is not an integer" do
      opts = [min_sleep_ms: 100, max_sleep_ms: 1_000, jitter: :full]

      assert_raise FunctionClauseError, fn ->
        Backoff.backoff_ms("1", opts)
      end
    end
  end
end
