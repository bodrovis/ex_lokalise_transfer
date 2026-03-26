ExUnit.start(exclude: [:integration])

Mox.defmock(ExLokaliseTransfer.HTTPClientMock,
  for: ElixirLokaliseApi.HTTPClient
)

Mox.defmock(ExLokaliseTransfer.QueuedProcessesClientMock,
  for: ExLokaliseTransfer.Processes.QueuedProcessesClient
)

Mox.defmock(ExLokaliseTransfer.BackoffMock,
  for: ExLokaliseTransfer.Helpers.BackoffBehaviour
)

Mox.defmock(ExLokaliseTransfer.SleepMock,
  for: ExLokaliseTransfer.Processes.SleepBehaviour
)

Mox.defmock(ExLokaliseTransfer.PollerMock,
  for: ExLokaliseTransfer.Processes.PollerBehaviour
)

Mox.defmock(ExLokaliseTransfer.BatchPollerMock,
  for: ExLokaliseTransfer.Processes.BatchPollerBehaviour
)

Mox.defmock(ExLokaliseTransfer.UploadFilesMock,
  for: ExLokaliseTransfer.Uploader.Files.FilesBehaviour
)

Mox.defmock(ExLokaliseTransfer.RetryMock,
  for: ExLokaliseTransfer.RetryBehaviour
)

Mox.defmock(ExLokaliseTransfer.LokaliseFilesMock,
  for: ExLokaliseTransfer.Sdk.LokaliseFilesBehaviour
)

Mox.defmock(ExLokaliseTransfer.RunnerMock,
  for: ExLokaliseTransfer.RunnerBehaviour
)

Mox.defmock(
  ExLokaliseTransfer.HTTPStreamClientMock,
  for: ExLokaliseTransfer.Downloader.Bundle.HTTPStreamClientBehaviour
)

Mox.defmock(
  ExLokaliseTransfer.BundleFetcherMock,
  for: ExLokaliseTransfer.Downloader.Bundle.FetcherBehaviour
)

Mox.defmock(
  ExLokaliseTransfer.BundleExtractorMock,
  for: ExLokaliseTransfer.Downloader.Bundle.ExtractorBehaviour
)

Mox.defmock(
  ExLokaliseTransfer.TempMock,
  for: ExLokaliseTransfer.Downloader.Bundle.TempBehaviour
)

Mox.defmock(
  ExLokaliseTransfer.TransferMock,
  for: ExLokaliseTransfer.Downloader.Bundle.TransferBehaviour
)

Mox.defmock(
  ExLokaliseTransfer.LokaliseFilesSdkMock,
  for: ExLokaliseTransfer.Sdk.LokaliseFilesBehaviour
)

Mox.defmock(
  ExLokaliseTransfer.QueuedProcessesSdkMock,
  for: ExLokaliseTransfer.Processes.QueuedProcessesClient
)

Mox.defmock(
  ExLokaliseTransfer.FinchMock,
  for: ExLokaliseTransfer.Downloader.Bundle.FinchBehaviour
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

  def set_top_level_runner_mocks(_context) do
    originals = %{
      uploader_async_module: Application.get_env(:ex_lokalise_transfer, :uploader_async_module),
      downloader_sync_module: Application.get_env(:ex_lokalise_transfer, :downloader_sync_module),
      downloader_async_module:
        Application.get_env(:ex_lokalise_transfer, :downloader_async_module)
    }

    Application.put_env(
      :ex_lokalise_transfer,
      :uploader_async_module,
      ExLokaliseTransfer.RunnerMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :downloader_sync_module,
      ExLokaliseTransfer.RunnerMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :downloader_async_module,
      ExLokaliseTransfer.RunnerMock
    )

    on_exit(fn -> restore_envs(:ex_lokalise_transfer, originals) end)

    :ok
  end

  def set_downloader_sync_dependency_mocks(_context) do
    originals = %{
      retry_module: Application.get_env(:ex_lokalise_transfer, :retry_module),
      downloader_temp_module: Application.get_env(:ex_lokalise_transfer, :downloader_temp_module),
      downloader_transfer_module:
        Application.get_env(:ex_lokalise_transfer, :downloader_transfer_module),
      lokalise_files_module: Application.get_env(:ex_lokalise_transfer, :lokalise_files_module)
    }

    Application.put_env(:ex_lokalise_transfer, :retry_module, ExLokaliseTransfer.RetryMock)

    Application.put_env(
      :ex_lokalise_transfer,
      :downloader_temp_module,
      ExLokaliseTransfer.TempMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :downloader_transfer_module,
      ExLokaliseTransfer.TransferMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :lokalise_files_module,
      ExLokaliseTransfer.LokaliseFilesMock
    )

    on_exit(fn -> restore_envs(:ex_lokalise_transfer, originals) end)

    :ok
  end

  def set_downloader_transfer_dependency_mocks(_context) do
    originals = %{
      retry_module: Application.get_env(:ex_lokalise_transfer, :retry_module),
      bundle_fetcher_module: Application.get_env(:ex_lokalise_transfer, :bundle_fetcher_module),
      bundle_extractor_module:
        Application.get_env(:ex_lokalise_transfer, :bundle_extractor_module)
    }

    Application.put_env(
      :ex_lokalise_transfer,
      :retry_module,
      ExLokaliseTransfer.RetryMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :bundle_fetcher_module,
      ExLokaliseTransfer.BundleFetcherMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :bundle_extractor_module,
      ExLokaliseTransfer.BundleExtractorMock
    )

    on_exit(fn -> restore_envs(:ex_lokalise_transfer, originals) end)

    :ok
  end

  def set_process_dependency_mocks(_context) do
    originals = %{
      poller_module: Application.get_env(:ex_lokalise_transfer, :poller_module),
      queued_processes_client:
        Application.get_env(:ex_lokalise_transfer, :queued_processes_client),
      backoff_module: Application.get_env(:ex_lokalise_transfer, :backoff_module),
      sleep_module: Application.get_env(:ex_lokalise_transfer, :sleep_module)
    }

    Application.put_env(
      :ex_lokalise_transfer,
      :poller_module,
      ExLokaliseTransfer.PollerMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :queued_processes_client,
      ExLokaliseTransfer.QueuedProcessesClientMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :backoff_module,
      ExLokaliseTransfer.BackoffMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :sleep_module,
      ExLokaliseTransfer.SleepMock
    )

    on_exit(fn -> restore_envs(:ex_lokalise_transfer, originals) end)

    :ok
  end

  def set_downloader_bundle_dependency_mocks(_context) do
    originals = %{
      downloader_http_stream_client:
        Application.get_env(:ex_lokalise_transfer, :downloader_http_stream_client)
    }

    Application.put_env(
      :ex_lokalise_transfer,
      :downloader_http_stream_client,
      ExLokaliseTransfer.HTTPStreamClientMock
    )

    on_exit(fn -> restore_envs(:ex_lokalise_transfer, originals) end)

    :ok
  end

  def set_downloader_async_dependency_mocks(_context) do
    originals = %{
      retry_module: Application.get_env(:ex_lokalise_transfer, :retry_module),
      poller_module: Application.get_env(:ex_lokalise_transfer, :poller_module),
      downloader_temp_module: Application.get_env(:ex_lokalise_transfer, :downloader_temp_module),
      downloader_transfer_module:
        Application.get_env(:ex_lokalise_transfer, :downloader_transfer_module),
      lokalise_files_module: Application.get_env(:ex_lokalise_transfer, :lokalise_files_module)
    }

    Application.put_env(
      :ex_lokalise_transfer,
      :retry_module,
      ExLokaliseTransfer.RetryMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :poller_module,
      ExLokaliseTransfer.PollerMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :downloader_temp_module,
      ExLokaliseTransfer.TempMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :downloader_transfer_module,
      ExLokaliseTransfer.TransferMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :lokalise_files_module,
      ExLokaliseTransfer.LokaliseFilesMock
    )

    on_exit(fn -> restore_envs(:ex_lokalise_transfer, originals) end)

    :ok
  end

  def set_uploader_async_dependency_mocks(_context) do
    originals = %{
      upload_files_module: Application.get_env(:ex_lokalise_transfer, :upload_files_module),
      batch_poller_module: Application.get_env(:ex_lokalise_transfer, :batch_poller_module),
      retry_module: Application.get_env(:ex_lokalise_transfer, :retry_module),
      lokalise_files_module: Application.get_env(:ex_lokalise_transfer, :lokalise_files_module)
    }

    Application.put_env(
      :ex_lokalise_transfer,
      :upload_files_module,
      ExLokaliseTransfer.UploadFilesMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :batch_poller_module,
      ExLokaliseTransfer.BatchPollerMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :retry_module,
      ExLokaliseTransfer.RetryMock
    )

    Application.put_env(
      :ex_lokalise_transfer,
      :lokalise_files_module,
      ExLokaliseTransfer.LokaliseFilesMock
    )

    on_exit(fn -> restore_envs(:ex_lokalise_transfer, originals) end)

    :ok
  end

  def set_lokalise_files_impl_mocks(_context) do
    original =
      Application.get_env(:ex_lokalise_transfer, :lokalise_files_sdk_module)

    Application.put_env(
      :ex_lokalise_transfer,
      :lokalise_files_sdk_module,
      ExLokaliseTransfer.LokaliseFilesSdkMock
    )

    on_exit(fn ->
      restore_env(:ex_lokalise_transfer, :lokalise_files_sdk_module, original)
    end)

    :ok
  end

  def set_queued_processes_impl_mocks(_context) do
    original =
      Application.get_env(:ex_lokalise_transfer, :queued_processes_sdk_module)

    Application.put_env(
      :ex_lokalise_transfer,
      :queued_processes_sdk_module,
      ExLokaliseTransfer.QueuedProcessesSdkMock
    )

    on_exit(fn ->
      restore_env(
        :ex_lokalise_transfer,
        :queued_processes_sdk_module,
        original
      )
    end)

    :ok
  end

  def set_finch_mock(_context) do
    original = Application.get_env(:ex_lokalise_transfer, :finch_module)

    Application.put_env(
      :ex_lokalise_transfer,
      :finch_module,
      ExLokaliseTransfer.FinchMock
    )

    on_exit(fn ->
      restore_env(:ex_lokalise_transfer, :finch_module, original)
    end)

    :ok
  end

  defp restore_envs(app, originals) do
    Enum.each(originals, fn {key, value} ->
      restore_env(app, key, value)
    end)
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
