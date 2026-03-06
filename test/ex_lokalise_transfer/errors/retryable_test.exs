defmodule ExLokaliseTransfer.Errors.RetryableTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Errors.Error
  alias ExLokaliseTransfer.Errors.Retryable

  defp err(overrides) do
    struct!(Error, Keyword.merge([source: :sdk, kind: :unexpected, message: "x"], overrides))
  end

  describe "retryable?/1 - http" do
    test "429 is retryable" do
      assert Retryable.retryable?(err(kind: :http, status: 429)) == true
    end

    test "408 is retryable" do
      assert Retryable.retryable?(err(kind: :http, status: 408)) == true
    end

    test "5xx is retryable" do
      assert Retryable.retryable?(err(kind: :http, status: 500)) == true
      assert Retryable.retryable?(err(kind: :http, status: 503)) == true
      assert Retryable.retryable?(err(kind: :http, status: 599)) == true
    end

    test "non-retryable 4xx are not retryable" do
      for s <- [400, 401, 403, 404, 422] do
        assert Retryable.retryable?(err(kind: :http, status: s)) == false
      end
    end

    test "other 4xx are not retryable (e.g. 418)" do
      assert Retryable.retryable?(err(kind: :http, status: 418)) == false
    end

    test "non 4xx/5xx are not retryable by default" do
      assert Retryable.retryable?(err(kind: :http, status: 200)) == false
      assert Retryable.retryable?(err(kind: :http, status: 302)) == false
      assert Retryable.retryable?(err(kind: :http, status: 100)) == false
      assert Retryable.retryable?(err(kind: :http, status: 700)) == false
    end
  end

  describe "retryable?/1 - transport" do
    test "known transient transport reasons are retryable" do
      for reason <- [
            :timeout,
            :connect_timeout,
            :closed,
            :shutdown,
            :socket_closed,
            :econnrefused,
            :econnreset,
            :enetunreach,
            :ehostunreach
          ] do
        e = err(kind: :transport, details: %{"reason_atom" => reason})
        assert Retryable.retryable?(e) == true
      end
    end

    test "invalid_uri transport reason is not retryable" do
      e = err(kind: :transport, details: %{"reason_atom" => :invalid_uri})
      assert Retryable.retryable?(e) == false
    end

    test "transport without reason_atom defaults to retryable" do
      e = err(kind: :transport, details: %{})
      assert Retryable.retryable?(e) == true
    end

    test "unknown transport reason atom is retryable (denylist policy)" do
      e = err(kind: :transport, details: %{"reason_atom" => :weird_unknown})
      assert Retryable.retryable?(e) == true
    end
  end

  describe "retryable?/1 - other kinds" do
    test "message errors are not retryable" do
      assert Retryable.retryable?(err(kind: :message)) == false
    end

    test "unexpected errors are not retryable" do
      assert Retryable.retryable?(err(kind: :unexpected)) == false
    end

    test "unknown input returns false" do
      assert Retryable.retryable?(:wat) == false
    end
  end

  describe "classify/1" do
    test "classify http statuses" do
      assert Retryable.classify(err(kind: :http, status: 429)) == :rate_limited
      assert Retryable.classify(err(kind: :http, status: 408)) == :timeout
      assert Retryable.classify(err(kind: :http, status: 500)) == :server
      assert Retryable.classify(err(kind: :http, status: 404)) == :client
    end

    test "classify other kinds" do
      assert Retryable.classify(err(kind: :transport)) == :transport
      assert Retryable.classify(err(kind: :message)) == :message
      assert Retryable.classify(err(kind: :unexpected)) == :unexpected
    end

    test "classify fallback" do
      assert Retryable.classify(:wat) == :unknown
      assert Retryable.classify(err(kind: :http, status: nil)) == :unknown
    end
  end
end
