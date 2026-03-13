// Match Registry - manages match processes
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import sqlight
import vg/match.{type Message as MatchMessage}

pub type MatchRegistry {
  MatchRegistry(
    matches: Dict(String, Subject(MatchMessage)),
    db_conn: Option(sqlight.Connection),
  )
}

pub type Message {
  CreateMatch(
    match_id: String,
    reply_to: Subject(Result(Subject(MatchMessage), String)),
  )
  GetMatch(
    match_id: String,
    reply_to: Subject(Result(Subject(MatchMessage), Nil)),
  )
  RemoveMatch(match_id: String, reply_to: Subject(Nil))
  ListMatches(reply_to: Subject(List(String)))
  SetDbConn(conn: sqlight.Connection, reply_to: Subject(Nil))
}

pub fn start() {
  actor.new(MatchRegistry(matches: dict.new(), db_conn: None))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  state: MatchRegistry,
  message: Message,
) -> actor.Next(MatchRegistry, Message) {
  case message {
    CreateMatch(match_id, reply_to) -> {
      case dict.get(state.matches, match_id) {
        Ok(existing) -> {
          // Match already exists, return it
          process.send(reply_to, Ok(existing))
          actor.continue(state)
        }
        Error(_) -> {
          // Create new match actor with DB connection
          let now = get_timestamp()
          case match.start_with_db(match_id, now, state.db_conn) {
            Ok(actor.Started(pid: _, data: match_actor)) -> {
              let new_matches =
                dict.insert(state.matches, match_id, match_actor)
              process.send(reply_to, Ok(match_actor))
              actor.continue(MatchRegistry(
                matches: new_matches,
                db_conn: state.db_conn,
              ))
            }
            Error(_) -> {
              process.send(reply_to, Error("Failed to start match actor"))
              actor.continue(state)
            }
          }
        }
      }
    }

    SetDbConn(conn, reply_to) -> {
      process.send(reply_to, Nil)
      actor.continue(MatchRegistry(matches: state.matches, db_conn: Some(conn)))
    }

    GetMatch(match_id, reply_to) -> {
      process.send(reply_to, dict.get(state.matches, match_id))
      actor.continue(state)
    }

    RemoveMatch(match_id, reply_to) -> {
      let new_matches = dict.delete(state.matches, match_id)
      process.send(reply_to, Nil)
      actor.continue(MatchRegistry(matches: new_matches, db_conn: state.db_conn))
    }

    ListMatches(reply_to) -> {
      process.send(reply_to, dict.keys(state.matches))
      actor.continue(state)
    }
  }
}

fn get_timestamp() -> Int {
  do_get_timestamp()
}

@external(erlang, "erlang", "system_time")
fn do_get_timestamp() -> Int

// Public API

pub fn create_match(
  registry: Subject(Message),
  match_id: String,
) -> Result(Subject(MatchMessage), String) {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    CreateMatch(match_id, subject)
  })
}

pub fn get_match(
  registry: Subject(Message),
  match_id: String,
) -> Result(Subject(MatchMessage), Nil) {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    GetMatch(match_id, subject)
  })
}

pub fn remove_match(registry: Subject(Message), match_id: String) -> Nil {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    RemoveMatch(match_id, subject)
  })
}

pub fn list_matches(registry: Subject(Message)) -> List(String) {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    ListMatches(subject)
  })
}

pub fn set_db_conn(registry: Subject(Message), conn: sqlight.Connection) -> Nil {
  process.call(registry, waiting: 5000, sending: fn(subject) {
    SetDbConn(conn, subject)
  })
}
