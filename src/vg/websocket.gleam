// Simplified WebSocket handler for client communication

import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{None}
import mist.{type Connection, type ResponseData}

pub fn handle_websocket(
  req: Request(Connection),
) -> Response(ResponseData) {
  mist.websocket(
    request: req,
    handler: fn(state, msg, conn) {
      case msg {
        mist.Text(text) -> {
          // Echo back
          let _ = mist.send_text_frame(conn, "Echo: " <> text)
          mist.continue(state)
        }
        _ -> mist.continue(state)
      }
    },
    on_init: fn(conn) {
      let player_id = "player_" <> int.to_string(int.random(1_000_000))
      let _ = mist.send_text_frame(conn, "Connected as: " <> player_id)
      #(player_id, None)
    },
    on_close: fn(_state) {
      Nil
    },
  )
}
