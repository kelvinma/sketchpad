defmodule SketchpadWeb.UserSocket do
  use Phoenix.Socket
  require Logger

  channel "pad:*", SketchpadWeb.PadChannel

  def connect(%{"token" => token}, socket, _connect_info) do
    # NOTE: use a constant for the token Salt — "user token" is no bueno
    case Phoenix.Token.verify(socket, "user token", token, max_age: 86400) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, reason} ->
        Logger.error(fn -> "failed to verify: #{inspect reason}" end)
        :error
    end
  end

  # Endpoint.broadcast("user_socket:123"), disconnect() => boots user
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
