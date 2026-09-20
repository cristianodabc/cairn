defmodule Cairn.Message do
  @moduledoc false

  @enforce_keys [:from, :payload]
  defstruct [:from, :payload, :ref]

  @type from :: pid() | atom()
  @type payload :: term()
  @type ref :: term() | nil
  @type t :: %__MODULE__{from: from(), payload: payload(), ref: ref()}

  @doc false
  @spec new(from(), payload(), ref()) :: t()
  def new(from, payload, ref \\ nil) do
    %__MODULE__{from: from, payload: payload, ref: ref}
  end
end
