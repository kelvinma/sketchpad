defmodule SketchpadWeb.PadChannel do
  use SketchpadWeb, :channel
  alias Sketchpad.Pad
  alias SketchpadWeb.Presence

  # Pluck off the pad id from the passed channel name
  def join("pad:" <> pad_id, _params, socket) do
    # invoke an after join in the handle info
    # to get access to state or set up Presence
    send(self(), :after_join)
    socket = socket |> assign(:pad_id, pad_id)

    {:ok, socket}
  end

  # A good place to verify the data here
  # state is the last arg
  def handle_in("stroke", stroke, socket) do
    %{pad_id: pad_id, user_id: user_id} = socket.assigns
    # bind to :ok so that it blows up if it's not "ok"
    :ok = Pad.stroke(pad_id, user_id, stroke, self())
    # broadcast_stroke_from(self(), pad_id, user_id, stroke)

    {:reply, :ok, socket}
  end

  def handle_in("clear", _, socket) do
    # broadcast_clear(socket.assigns.pad_id)
    Pad.clear(socket.assigns.pad_id)
    {:reply, :ok, socket}
  end

  def handle_in("new_message", %{"body" => body}, socket) do
    broadcast!(socket, "new_message", %{
      user_id: socket.assigns.user_id,
      body: body
    })

    {:reply, :ok, socket}
  end

  @png_prefix "data:image/png;base64,"
  def handle_in("png_ack", %{"png" => @png_prefix <> img}, socket) do
    {:ok, ascii} = Pad.png_ack(img)
    IO.puts(ascii)
    IO.puts(">> #{socket.assigns.user_id}")
    {:reply, {:ok, %{ascii: ascii}}, socket}
  end

  def broadcast_stroke_from(pid, pad_id, user_id, stroke) do
    SketchpadWeb.Endpoint.broadcast_from!(pid, "pad:#{pad_id}", "stroke", %{
      user_id: user_id,
      stroke: stroke
    })
  end

  def broadcast_clear(pad_id) do
    SketchpadWeb.Endpoint.broadcast!("pad:#{pad_id}", "clear", %{})
  end

  def handle_info(:request_png, socket) do
    push(socket, "request_png", %{})
    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    # third arg in presence track is metadata, ie %{device: "Mobile"}
    {:ok, ref} = Presence.track(socket, socket.assigns.user_id, %{})

    # Phoenix pubsub
    # subscribe to external topic
    socket.endpoint.subscribe(socket.topic <> ":#{ref}")

    for {user_id, %{strokes: strokes}} <- Pad.render(socket.assigns.pad_id) do
      for stroke <- Enum.reverse(strokes) do
        push(socket, "stroke", %{user_id: user_id, stroke: stroke})
      end
    end

    {:noreply, socket}
  end
end
