import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import mist.{type Connection, type ResponseData}
import sqlight
import vg/connection_registry
import vg/db
import vg/match_orchestrator
import vg/match_registry
import vg/matchmaking
import vg/player_registry
import vg/websocket

const default_port = 7567

const default_db_path = "vg_server.db"

pub fn main() {
  io.println("Starting Vanguard's Gambit Server...")

  let db_path = default_db_path

  io.println("Initializing database at: " <> db_path)
  let db_result = db.init(db_path)
  case db_result {
    Ok(conn) -> {
      io.println("Database initialized successfully")
      start_server_with_db(conn)
    }
    Error(err) -> {
      io.println("Failed to initialize database: " <> err.message)
      // Start without database
      start_server_without_db()
    }
  }
}

fn start_server_with_db(conn: sqlight.Connection) {
  // Start registries
  let assert Ok(actor.Started(pid: _, data: player_registry)) =
    player_registry.start()
  io.println("Player registry started")

  let assert Ok(actor.Started(pid: _, data: matchmaking_queue)) =
    matchmaking.start()
  io.println("Matchmaking queue started")

  let assert Ok(actor.Started(pid: _, data: match_registry)) =
    match_registry.start()
  io.println("Match registry started")

  // Start connection registry for WebSocket notifications
  let assert Ok(actor.Started(pid: _, data: conn_registry)) =
    connection_registry.start()
  io.println("Connection registry started")

  // Pass DB connection to match registry
  match_registry.set_db_conn(match_registry, conn)
  // Start the match orchestrator
  run_server(
    player_registry,
    matchmaking_queue,
    match_registry,
    conn_registry,
    Ok(conn),
  )
}

fn start_server_without_db() {
  io.println("WARNING: Running without database persistence")

  // Start registries
  let assert Ok(actor.Started(pid: _, data: player_registry)) =
    player_registry.start()
  io.println("Player registry started")

  let assert Ok(actor.Started(pid: _, data: matchmaking_queue)) =
    matchmaking.start()
  io.println("Matchmaking queue started")

  let assert Ok(actor.Started(pid: _, data: match_registry)) =
    match_registry.start()
  io.println("Match registry started")

  // Start connection registry for WebSocket notifications
  let assert Ok(actor.Started(pid: _, data: conn_registry)) =
    connection_registry.start()
  io.println("Connection registry started")

  run_server(
    player_registry,
    matchmaking_queue,
    match_registry,
    conn_registry,
    Error(Nil),
  )
}

fn run_server(
  player_registry: process.Subject(player_registry.Message),
  matchmaking_queue: process.Subject(matchmaking.Message),
  match_registry: process.Subject(match_registry.Message),
  conn_registry: process.Subject(connection_registry.Message),
  db_conn: Result(sqlight.Connection, Nil),
) {
  let assert Ok(actor.Started(pid: _, data: orchestrator)) =
    match_orchestrator.start(matchmaking_queue, match_registry, conn_registry)
  io.println("Match orchestrator started")

  // Start matchmaking loop
  match_orchestrator.run_matchmaking(orchestrator)
  io.println("Matchmaking loop started")

  // Start match tick loop
  match_orchestrator.tick_matches(orchestrator, 0)
  io.println("Match tick loop started")

  // Start the main supervisor
  let assert Ok(_) = start_supervisor()
  io.println("Supervisor started")

  // Start the HTTP/WebSocket server
  let opt_conn = case db_conn {
    Ok(conn) -> Some(conn)
    Error(_) -> None
  }
  let server_port = default_port
  let assert Ok(_) =
    start_http_server(
      player_registry,
      matchmaking_queue,
      match_registry,
      conn_registry,
      opt_conn,
      server_port,
    )
  io.println(
    "WebSocket server listening on port " <> int.to_string(server_port),
  )

  case db_conn {
    Ok(_) -> io.println("Database persistence: ENABLED")
    Error(_) -> io.println("Database persistence: DISABLED")
  }

  io.println("Server started successfully!")

  // Keep the main process alive
  process.sleep_forever()
}

fn start_supervisor() {
  supervisor.new(supervisor.OneForOne)
  // Future: Add supervised child processes here
  |> supervisor.start
}

fn start_http_server(
  player_registry: process.Subject(player_registry.Message),
  matchmaking_queue: process.Subject(matchmaking.Message),
  match_registry: process.Subject(match_registry.Message),
  conn_registry: process.Subject(connection_registry.Message),
  db_conn: Option(sqlight.Connection),
  port: Int,
) {
  let handler = fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      ["ws"] ->
        websocket.handle_websocket(
          req,
          player_registry,
          matchmaking_queue,
          match_registry,
          conn_registry,
          db_conn,
        )
      _ -> {
        response.new(404)
        |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
      }
    }
  }

  mist.new(handler)
  |> mist.port(port)
  |> mist.start()
}
