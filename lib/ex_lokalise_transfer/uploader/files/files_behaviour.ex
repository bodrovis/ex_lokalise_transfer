defmodule ExLokaliseTransfer.Uploader.Files.FilesBehaviour do
  @moduledoc false

  alias ExLokaliseTransfer.Uploader.Files.Entry

  @callback discover(Keyword.t()) :: {:ok, [Entry.t()]} | {:error, term()}
end
