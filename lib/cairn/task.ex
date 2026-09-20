defmodule Cairn.Task do
  @moduledoc false

  @type ref :: Cairn.Message.ref()
  @type value :: term()
  @type reason :: Exception.t()
  @type result :: {:ok, value()} | {:error, reason()}
  @type fun :: (-> value())

  @spec run(ref(), fun()) :: {:ok, pid()}
  def run(ref, fun) when is_function(fun, 0) do
    if Cairn.Server.__callback__?() do
      start(ref, fun)
    else
      raise ArgumentError, "Cairn.Task.run/2 must be called from a Cairn.Server callback"
    end
  end

  @spec start(ref(), fun()) :: {:ok, pid()}
  defp start(ref, fun) do
    owner = self()
    {:ok, supervisor} = Cairn.Server.__task_supervisor__()

    Task.Supervisor.start_child(supervisor, fn ->
      send(owner, {__MODULE__, ref, call(fun)})
    end)
  end

  @spec call(fun()) :: result()
  defp call(fun) do
    {:ok, fun.()}
  rescue
    exception ->
      {:error, exception}
  end
end
