// Match Registry - manages match processes

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/otp/actor

pub type MatchRegistry {
  MatchRegistry(matches: Dict(String, Pid))
}

pub type Message {
  CreateMatch(match_id: String, reply_to: Subject(Result(Pid, Nil)))
  GetMatch(match_id: String, reply_to: Subject(Result(Pid, Nil)))
  RemoveMatch(match_id: String)
  ListMatches(reply_to: Subject(List(String)))
}

pub fn start() {
  actor.new(MatchRegistry(matches: dict.new()))
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
        Ok(pid) -> {
          process.send(reply_to, Ok(pid))
          actor.continue(state)
        }
        Error(_) -> {
          process.send(reply_to, Error(Nil))
          actor.continue(state)
        }
      }
    }
    GetMatch(match_id, reply_to) -> {
      process.send(reply_to, dict.get(state.matches, match_id))
      actor.continue(state)
    }
    RemoveMatch(match_id) -> {
      let new_matches = dict.delete(state.matches, match_id)
      actor.continue(MatchRegistry(matches: new_matches))
    }
    ListMatches(reply_to) -> {
      process.send(reply_to, dict.keys(state.matches))
      actor.continue(state)
    }
  }
}

pub fn create_match(
  registry: Subject(Message),
  match_id: String,
) -> Result(Pid, Nil) {
  process.call(registry, waiting: 5000, sending: fn(subject) { CreateMatch(match_id, subject) })
}

pub fn get_match(
  registry: Subject(Message),
  match_id: String,
) -> Result(Pid, Nil) {
  process.call(registry, waiting: 5000, sending: fn(subject) { GetMatch(match_id, subject) })
}

pub fn remove_match(registry: Subject(Message), match_id: String) -> Nil {
  process.send(registry, RemoveMatch(match_id))
}

pub fn list_matches(registry: Subject(Message)) -> List(String) {
  process.call(registry, waiting: 5000, sending: fn(subject) { ListMatches(subject) })
}
