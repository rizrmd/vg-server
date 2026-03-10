import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/otp/static_supervisor as supervisor
import mist.{type Connection, type ResponseData}
import gleam/bytes_tree
import vg/websocket

pub fn main() {
  io.println("Starting Vanguard's Gambit Server...")
  io.println("WebSocket server will listen on port 8080")

  // Start the main supervisor
  let assert Ok(_) = start_supervisor()

  // Start the HTTP/WebSocket server
  let assert Ok(_) = start_http_server()

  io.println("Server started successfully!")
  
  // Keep the main process alive
  process.sleep_forever()
}

fn start_supervisor() {
  supervisor.new(supervisor.OneForOne)
  // TODO: Add child processes here
  // 1. Match Registry (DynamicSupervisor for matches)
  // 2. Player Registry
  // 3. Matchmaking Queue
  |> supervisor.start
}

fn start_http_server() {
  let handler = fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      ["ws"] -> websocket.handle_websocket(req)
      _ -> {
        response.new(404)
        |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
      }
    }
  }

  mist.new(handler)
  |> mist.port(8080)
  |> mist.start()
}
