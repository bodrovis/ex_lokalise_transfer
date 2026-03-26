defmodule ExLokaliseTransfer.Errors.ErrorTest do
  use ExLokaliseTransfer.Case, async: true

  alias ExLokaliseTransfer.Errors.Error

  describe "normalize/2 - transport/message/unexpected" do
    test "atom reason -> transport error with reason_atom" do
      {:error, err} = Error.normalize({:error, :timeout}, :lokalise)

      assert err.kind == :transport
      assert err.source == :lokalise
      assert err.message == "timeout"
      assert err.reason == "transport error"
      assert err.details["reason_atom"] == :timeout
      assert err.status == nil
    end

    test "binary reason -> message error (trimmed)" do
      {:error, err} = Error.normalize({:error, "  nope  \n"}, :sdk)

      assert err.kind == :message
      assert err.source == :sdk
      assert err.message == "nope"
      assert err.reason == "error message"
      assert err.raw == "nope"
    end

    test "empty binary reason -> message default" do
      {:error, err} = Error.normalize({:error, "   "}, :sdk)

      assert err.kind == :message
      assert err.message == "error message"
      assert err.raw == ""
    end

    test "unexpected shape -> unexpected error" do
      {:error, err} = Error.normalize({:error, {:wat, 9999}}, :sdk)

      assert err.kind == :unexpected
      assert err.source == :sdk
      assert err.message == "unexpected error shape"
      assert err.reason == "unexpected error shape"
      assert is_binary(err.details["error"])
    end
  end

  describe "normalize/2 - http errors (lokalise)" do
    test "lokalise shape 1: top-level {message,statusCode,error}" do
      body =
        ~s({"message":"msg","statusCode":429,"error":"Too Many Requests"})

      {:error, err} = Error.normalize({:error, {body, 429}}, :lokalise)

      assert err.kind == :http
      assert err.source == :lokalise
      assert err.status == 429
      assert err.code == 429
      assert err.message == "msg"
      assert err.reason == "Too Many Requests"
      assert err.raw == body
      assert err.details["message"] == "msg"
    end

    test "lokalise shape 2: nested error {error:{message,code,details}}" do
      body =
        ~s({"error":{"message":"msg","code":429,"details":{"bucket":"global"}}})

      {:error, err} = Error.normalize({:error, {body, 429}}, :lokalise)

      assert err.kind == :http
      assert err.status == 429
      assert err.code == 429
      assert err.message == "msg"
      assert err.reason == nil
      assert err.details == %{"bucket" => "global"}
    end

    test "lokalise shape 2: nested error details non-object preserved" do
      body =
        ~s({"error":{"message":"msg","code":429,"details":"lol"}})

      {:error, err} = Error.normalize({:error, {body, 429}}, :lokalise)

      assert err.code == 429
      assert err.message == "msg"
      assert err.details == %{"details" => "lol"}
    end

    test "lokalise shape 2: nested error without message uses HTTP status text" do
      body =
        ~s({"error":{"code":429,"details":{"bucket":"global"}}})

      {:error, err} = Error.normalize({:error, {body, 429}}, :lokalise)

      assert err.code == 429
      assert err.message == "Too Many Requests"
      assert err.details == %{"bucket" => "global"}
    end

    test "lokalise shape 3: top-level {message, code as string}" do
      body =
        ~s({"message":"msg","code":"429","details":{"x":1}})

      {:error, err} = Error.normalize({:error, {body, 429}}, :lokalise)

      assert err.code == 429
      assert err.message == "msg"
      assert err.details == %{"x" => 1}
    end

    test "lokalise shape 3: top-level {message, errorCode as number}" do
      body =
        ~s({"message":"msg","errorCode":429,"details":{"x":1}})

      {:error, err} = Error.normalize({:error, {body, 429}}, :lokalise)

      assert err.code == 429
      assert err.message == "msg"
      assert err.details == %{"x" => 1}
    end

    test "lokalise fallback: keeps message and error string reason" do
      body =
        ~s({"message":"msg","error":"nope","foo":"bar"})

      {:error, err} = Error.normalize({:error, {body, 400}}, :lokalise)

      assert err.status == 400
      assert err.message == "msg"
      assert err.reason == "nope"
      assert err.details["foo"] == "bar"
    end

    test "lokalise non-json body -> reason non-json error body" do
      body = "not json"

      {:error, err} = Error.normalize({:error, {body, 500}}, :lokalise)

      assert err.status == 500
      assert err.message == "Internal Server Error"
      assert err.reason == "non-json error body"
      assert err.raw == "not json"
      assert err.details == %{}
    end

    test "lokalise invalid json -> reason invalid json in error body" do
      body = "{"

      {:error, err} = Error.normalize({:error, {body, 500}}, :lokalise)

      assert err.status == 500
      assert err.reason == "invalid json in error body"
      assert err.raw == "{"
      assert is_binary(err.details["unmarshal_error"])
    end

    test "lokalise empty body is treated as non-json" do
      {:error, err} = Error.normalize({:error, {"", 500}}, :lokalise)

      assert err.message == "Internal Server Error"
      assert err.reason == "non-json error body"
      assert err.raw == ""
    end

    test "lokalise fallback is used when message exists but code fields are invalid" do
      body = ~s({"message":"msg","code":"abc","foo":"bar"})

      {:error, err} = Error.normalize({:error, {body, 400}}, :lokalise)

      assert err.kind == :http
      assert err.source == :lokalise
      assert err.status == 400
      assert err.message == "msg"
      assert err.reason == "unhandled error format"
      assert err.code == nil
      assert err.raw == body
      assert err.details["message"] == "msg"
      assert err.details["code"] == "abc"
      assert err.details["foo"] == "bar"
    end

    test "lokalise fallback uses http status text when message is missing" do
      body = ~s({"foo":"bar"})

      {:error, err} = Error.normalize({:error, {body, 400}}, :lokalise)

      assert err.message == "Bad Request"
      assert err.reason == "unhandled error format"
      assert err.code == nil
      assert err.details["foo"] == "bar"
    end

    test "lokalise json non-object -> unhandled error format" do
      body = ~s(["oops"])

      {:error, err} = Error.normalize({:error, {body, 500}}, :lokalise)

      assert err.kind == :http
      assert err.source == :lokalise
      assert err.status == 500
      assert err.message == "Internal Server Error"
      assert err.reason == "unhandled error format"
      assert err.code == nil
      assert err.raw == body
      assert err.details == %{"error_value" => ["oops"]}
    end

    test "lokalise fallback uses default reason when error field is missing" do
      body = ~s({"message":"msg","foo":"bar"})

      {:error, err} = Error.normalize({:error, {body, 400}}, :lokalise)

      assert err.status == 400
      assert err.message == "msg"
      assert err.reason == "unhandled error format"
      assert err.code == nil
      assert err.details["foo"] == "bar"
    end

    test "lokalise nested error without details uses default details map" do
      body = ~s({"error":{"message":"msg","code":429}})

      {:error, err} = Error.normalize({:error, {body, 429}}, :lokalise)

      assert err.code == 429
      assert err.message == "msg"
      assert err.reason == nil
      assert err.details == %{"reason" => "server error without details"}
    end
  end

  describe "normalize/2 - http errors (generic / s3-ish)" do
    test "generic empty body -> empty error body" do
      {:error, err} = Error.normalize({:error, {"   ", 404}}, :s3)

      assert err.kind == :http
      assert err.source == :s3
      assert err.status == 404
      assert err.message == "Not Found"
      assert err.reason == "empty error body"
      assert err.raw == ""
    end

    test "generic json best-effort picks message/reason/code/details" do
      body =
        ~s({"message":"nope","error":"bad","code":"403","details":{"a":"b"}})

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.status == 403
      assert err.message == "nope"
      assert err.reason == "bad"
      assert err.code == 403
      assert err.details == %{"a" => "b"}
    end

    test "generic json supports capitalized Message/Error" do
      body =
        ~s({"Message":"Denied","Error":"AccessDenied","statusCode":403})

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.message == "Denied"
      assert err.reason == "AccessDenied"
      assert err.code == 403
    end

    test "generic non-json xml best-effort extracts <Message>" do
      body =
        """
        <Error>
          <Code>AccessDenied</Code>
          <Message>Access Denied</Message>
        </Error>
        """

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.status == 403
      assert err.reason == "non-json error body"
      assert err.message == "Access Denied"
      assert String.contains?(err.raw, "<Error>")
    end

    test "generic non-json xml best-effort falls back to Code when Message missing" do
      body =
        """
        <Error>
          <Code>NoSuchKey</Code>
        </Error>
        """

      {:error, err} = Error.normalize({:error, {body, 404}}, :s3)

      assert err.status == 404
      assert err.message == "NoSuchKey (Not Found)"
    end

    test "generic invalid json -> reason invalid json in error body" do
      body = "{"

      {:error, err} = Error.normalize({:error, {body, 502}}, :s3)

      assert err.status == 502
      assert err.reason == "invalid json in error body"
      assert err.raw == "{"
      assert is_binary(err.details["unmarshal_error"])
    end

    test "generic json non-object -> unhandled error format" do
      body = ~s([1,2,3])

      {:error, err} = Error.normalize({:error, {body, 418}}, :s3)

      assert err.kind == :http
      assert err.source == :s3
      assert err.status == 418
      assert err.message == "HTTP 418"
      assert err.reason == "unhandled error format"
      assert err.code == nil
      assert err.raw == body
      assert err.details == %{"error_value" => [1, 2, 3]}
    end

    test "http error with nil body -> empty error body" do
      {:error, err} = Error.normalize({:error, {nil, 404}}, :s3)

      assert err.kind == :http
      assert err.status == 404
      assert err.message == "Not Found"
      assert err.reason == "empty error body"
      assert err.raw == ""
      assert err.details == %{}
    end

    test "http error with iodata body converts to string" do
      {:error, err} = Error.normalize({:error, {[~c"n", ~c"o", ~c"p", ~c"e"], 500}}, :s3)

      assert err.kind == :http
      assert err.status == 500
      assert err.message == "Internal Server Error"
      assert err.reason == "non-json error body"
      assert err.raw == "nope"
    end

    test "http error with map body is json-encoded before parsing" do
      {:error, err} =
        Error.normalize(
          {:error, {%{"message" => "denied", "error" => "bad", "code" => 403}, 403}},
          :s3
        )

      assert err.kind == :http
      assert err.status == 403
      assert err.message == "denied"
      assert err.reason == "bad"
      assert err.code == 403
    end

    test "http error with non-string body falls back to inspect" do
      {:error, err} = Error.normalize({:error, {12345, 500}}, :s3)

      assert err.kind == :http
      assert err.status == 500
      assert err.message == "Internal Server Error"
      assert err.reason == "non-json error body"
      assert err.raw == "12345"
    end

    test "generic json parses float code via truncation" do
      body = ~s({"message":"nope","code":429.9})

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.message == "nope"
      assert err.code == 429
    end

    test "generic json parses integer code from binary string" do
      body = ~s({"message":"nope","code":"403"})

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.message == "nope"
      assert err.code == 403
    end

    test "generic non-json xml falls back when closing Code tag is missing" do
      body = "<Error><Code>AccessDenied</Error>"

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.kind == :http
      assert err.source == :s3
      assert err.status == 403
      assert err.reason == "non-json error body"
      assert err.message == "Forbidden"
      assert err.code == nil
      assert err.raw == body
    end

    test "generic json falls back to http status text when message is missing" do
      body = ~s({"error":"something bad"})

      {:error, err} = Error.normalize({:error, {body, 418}}, :s3)

      assert err.kind == :http
      assert err.source == :s3
      assert err.status == 418
      assert err.message == "HTTP 418"
      assert err.reason == "something bad"
    end

    test "generic json ignores invalid non-numeric code" do
      body = ~s({"message":"nope","code":"abc"})

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.message == "nope"
      assert err.code == nil
    end

    test "generic json ignores invalid code type" do
      body = ~s({"message":"nope","code":{"x":1}})

      {:error, err} = Error.normalize({:error, {body, 403}}, :s3)

      assert err.message == "nope"
      assert err.code == nil
    end

    test "generic empty body is treated as non-json" do
      {:error, err} = Error.normalize({:error, {"", 404}}, :s3)

      assert err.message == "Not Found"
      assert err.reason == "empty error body"
      assert err.raw == ""
    end

    test "http status text mapping is reflected in normalized message" do
      cases = [
        {401, "Unauthorized"},
        {403, "Forbidden"},
        {408, "Request Timeout"},
        {409, "Conflict"},
        {422, "Unprocessable Entity"},
        {503, "Service Unavailable"},
        {504, "Gateway Timeout"},
        {418, "HTTP 418"}
      ]

      Enum.each(cases, fn {status, expected_message} ->
        {:error, err} = Error.normalize({:error, {"", status}}, :s3)
        assert err.message == expected_message
        assert err.reason == "empty error body"
      end)
    end
  end
end
