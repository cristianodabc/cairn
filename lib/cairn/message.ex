defmodule Cairn.Message do
  @moduledoc false

  @enforce_keys [:from, :payload]
  defstruct [:from, :payload, :ref]

  @type from :: pid() | atom()
  @type payload :: term()
  @type ref :: term()
  @type t :: %__MODULE__{from: from(), payload: payload(), ref: ref()}

  @doc false
  @spec new(from(), payload(), ref()) :: t()
  def new(from, payload, ref \\ make_ref()) do
    %__MODULE__{from: from, payload: payload, ref: ref}
  end

  @doc false
  @spec reply(t(), payload()) :: t()
  def reply(%__MODULE__{ref: ref}, payload) do
    new(self(), payload, ref)
  end
end
