ExUnit.start()

Mox.defmock(ExLokaliseTransfer.HTTPClientMock,
  for: ElixirLokaliseApi.HTTPClient
)

defmodule ExLokaliseTransfer.Case do
  @moduledoc false
  use ExUnit.CaseTemplate

  using opts do
    quote do
      use ExUnit.Case, unquote(opts)

      import Mox

      setup :set_mox_from_context
      setup :verify_on_exit!
    end
  end
end
