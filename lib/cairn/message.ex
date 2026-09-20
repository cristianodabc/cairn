defmodule Cairn.Message do
  @moduledoc """
  A small message envelope with sender, payload, and correlation ref.
  """

  @enforce_keys [:from, :payload]
  defstruct [:from, :payload, :ref]

  @type from :: pid() | atom()
  @type payload :: term()
  @type ref :: term()
  @type t :: %__MODULE__{from: from(), payload: payload(), ref: ref()}

  @doc """
  Builds a message.
  """
  @spec new(from(), payload(), ref()) :: t()
  def new(from, payload, ref \\ make_ref()) do
    %__MODULE__{from: from, payload: payload, ref: ref}
  end

  @doc """
  Builds a reply that preserves the original ref.
  """
  @spec reply(t(), payload()) :: t()
  def reply(%__MODULE__{ref: ref}, payload) do
    new(self(), payload, ref)
  end
end
