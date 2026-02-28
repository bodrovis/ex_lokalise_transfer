ExUnit.start()

Mox.defmock(ExLokaliseSync.TokenProviderMock, for: ExLokaliseSync.TokenProvider)

defmodule ExLokaliseSync.Case do
  @moduledoc false
  use ExUnit.CaseTemplate

  using opts do
    quote do
      use ExUnit.Case, unquote(opts)

      import Mox
      alias ExLokaliseSync.TokenProviderMock

      setup :set_mox_from_context
      setup :verify_on_exit!
    end
  end
end
