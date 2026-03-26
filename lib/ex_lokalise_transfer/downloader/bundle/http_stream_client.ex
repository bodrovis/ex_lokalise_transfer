defmodule ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClient do
  @moduledoc false

  @behaviour ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClientBehaviour

  @impl true
  def stream(finch_name, method, url, acc, fun) do
    method
    |> finch_module().build(url)
    |> finch_module().stream(finch_name, acc, fun)
  end

  defp finch_module do
    Application.get_env(
      :ex_lokalise_transfer,
      :finch_module,
      Finch
    )
  end
end
