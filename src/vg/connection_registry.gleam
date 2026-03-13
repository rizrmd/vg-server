// Connection Registry - tracks active WebSocket connections
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, Some, None}
import gleam/otp/actor
import mist

pub type ConnectionRegistry {
  ConnectionRegistry(connections: Dict(String, mist.WebsocketConnection))
}

pub type Message {
  RegisterConnection(player_id: String, conn: mist.WebsocketConnection, reply_to: Subject(Nil))
  UnregisterConnection(player_id: String, reply_to: Subject(Nil))
  GetConnection(player_id: String, reply_to: Subject(Option(mist.WebsocketConnection)))
  SendMessage(player_id: String, msg: String, reply_to: Subject(Result(Nil, Nil)))
}

pub fn start() {
  actor.new(ConnectionRegistry(connections: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  state: ConnectionRegistry,
  message: Message,
) -> actor.Next(ConnectionRegistry, Message) {
  case message {
    RegisterConnection(player_id, conn, reply_to) -> {
      let new_connections = dict.insert(state.connections, player_id, conn)
      process.send(reply_to, Nil)
      actor.continue(ConnectionRegistry(connections: new_connections))
    }
    UnregisterConnection(player_id, reply_to) -> {
      let new_connections = dict.delete(state.connections, player_id)
      process.send(reply_to, Nil)
      actor.continue(ConnectionRegistry(connections: new_connections))
    }
    GetConnection(player_id, reply_to) -> {
      let result = case dict.get(state.connections, player_id) {
        Ok(conn) -> Some(conn)
        Error(_) -> None
      }
      process.send(reply_to, result)
      actor.continue(state)
    }
    SendMessage(player_id, msg, reply_to) -> {
      case dict.get(state.connections, player_id) {
        Ok(conn) -> {
          let _ = mist.send_text_frame(conn, msg)
          process.send(reply_to, Ok(Nil))
        }
        Error(_) -> {
          process.send(reply_to, Error(Nil))
        }
      }
      actor.continue(state)
    }
  }
}

// Public API

pub fn register_connection(
  registry: Subject(Message),
  player_id: String,
  conn: mist.WebsocketConnection,
) -> Nil {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    RegisterConnection(player_id, conn, subject)
  })
}

pub fn unregister_connection(
  registry: Subject(Message),
  player_id: String,
) -> Nil {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    UnregisterConnection(player_id, subject)
  })
}

pub fn get_connection(
  registry: Subject(Message),
  player_id: String,
) -> Option(mist.WebsocketConnection) {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    GetConnection(player_id, subject)
  })
}

pub fn send_message(
  registry: Subject(Message),
  player_id: String,
  msg: String,
) -> Result(Nil, Nil) {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    SendMessage(player_id, msg, subject)
  })
}
