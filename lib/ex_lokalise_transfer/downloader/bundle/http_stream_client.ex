defmodule ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClient do
  @moduledoc false

  @behaviour ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClientBehaviour

  @impl true
  def stream(finch_name, method, url, acc, fun) do
    method
    |> Finch.build(url)
    |> Finch.stream(finch_name, acc, fun)
  end
end
