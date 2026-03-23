defmodule ExLokaliseTransfer.Uploader.Files.Entry do
  @moduledoc """
  Represents a local file discovered for upload.

  Fields:
    - `abs_path`  - absolute filesystem path, used for reading file contents
    - `rel_path`  - path relative to the current project root, used as upload filename
    - `basename`  - file basename
    - `ext`       - file extension including the leading dot, or `""`
    - `lang_iso`  - resolved language code for Lokalise upload
  """

  @enforce_keys [:abs_path, :rel_path, :basename, :ext, :lang_iso]
  defstruct [:abs_path, :rel_path, :basename, :ext, :lang_iso]

  @type t :: %__MODULE__{
          abs_path: String.t(),
          rel_path: String.t(),
          basename: String.t(),
          ext: String.t(),
          lang_iso: String.t()
        }
end
