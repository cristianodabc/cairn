defmodule Cairn.Agent do
  @moduledoc false

  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer
      @behaviour Cairn.Agent

      @before_compile Cairn.Agent

      def init(arg), do: {:ok, arg}
      def handle_message(_msg, state), do: {:noreply, state}

      def start_link(arg), do: GenServer.start_link(__MODULE__, arg)

      def child_spec(arg) do
        %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}}
      end

      @impl GenServer
      def handle_info(%Cairn.Message{} = msg, state) do
        handle_message(msg, state)
      end

      defoverridable init: 1,
                     handle_message: 2,
                     start_link: 1,
                     child_spec: 1
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Catch messages not handled by Cairn or the user's handle_info clauses.
      def handle_info(_msg, state), do: {:noreply, state}
    end
  end

  @type state :: term()

  @callback handle_message(msg :: Cairn.Message.t(), state :: state()) ::
              {:noreply, state()} | {:stop, reason :: term(), state()}
end
