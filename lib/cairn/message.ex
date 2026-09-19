defmodule Cairn.Message do
  @moduledoc false

  @enforce_keys [:from, :payload]
  defstruct [:from, :payload, :ref]

  @type t :: %__MODULE__{from: pid() | atom(), payload: term(), ref: term() | nil}

  @doc false
  @spec new(pid() | atom(), term(), term() | nil) :: t()
  def new(from, payload, ref \\ nil) do
    %__MODULE__{from: from, payload: payload, ref: ref}
  end
end
