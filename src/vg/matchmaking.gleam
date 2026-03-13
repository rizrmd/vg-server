// Matchmaking Queue - manages players waiting for matches

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import gleam/option.{type Option, Some, None}
import vg/types.{type MatchmakingEntry, MatchmakingEntry}

pub type MatchmakingQueue {
  MatchmakingQueue(entries: Dict(String, MatchmakingEntry))
}

pub type Message {
  QueuePlayer(
    player_id: String,
    hero_slugs: List(String),
    reply_to: Subject(Result(Nil, String)),
  )
  LeaveQueue(player_id: String, reply_to: Subject(Result(Nil, Nil)))
  RemoveMatched(player1: String, player2: String, reply_to: Subject(Nil))
  GetMatch(
    player_id: String,
    reply_to: Subject(Result(#(String, Int), Nil)),
  )
  TryMatch(reply_to: Subject(Option(#(MatchmakingEntry, MatchmakingEntry))))
  ListQueue(reply_to: Subject(List(MatchmakingEntry)))
}

pub fn start() {
  actor.new(MatchmakingQueue(entries: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  state: MatchmakingQueue,
  message: Message,
) -> actor.Next(MatchmakingQueue, Message) {
  case message {
    QueuePlayer(player_id, hero_slugs, reply_to) -> {
      case dict.get(state.entries, player_id) {
        Ok(_) -> {
          process.send(reply_to, Error("Already in queue"))
          actor.continue(state)
        }
        Error(_) -> {
          case list.length(hero_slugs) == 3 {
            True -> {
              let entry = MatchmakingEntry(
                player_id: player_id,
                hero_slug_1: case list.first(hero_slugs) { Ok(s) -> s Error(_) -> "" },
                hero_slug_2: case list.drop(hero_slugs, 1) |> list.first { Ok(s) -> s Error(_) -> "" },
                hero_slug_3: case list.drop(hero_slugs, 2) |> list.first { Ok(s) -> s Error(_) -> "" },
                queued_at: 0,
              )
              let new_entries = dict.insert(state.entries, player_id, entry)
              process.send(reply_to, Ok(Nil))
              actor.continue(MatchmakingQueue(entries: new_entries))
            }
            False -> {
              process.send(reply_to, Error("Must select exactly 3 heroes"))
              actor.continue(state)
            }
          }
        }
      }
    }
    LeaveQueue(player_id, reply_to) -> {
      let new_entries = dict.delete(state.entries, player_id)
      process.send(reply_to, Ok(Nil))
      actor.continue(MatchmakingQueue(entries: new_entries))
    }
    RemoveMatched(player1, player2, reply_to) -> {
      let new_entries = state.entries
      |> dict.delete(player1)
      |> dict.delete(player2)
      process.send(reply_to, Nil)
      actor.continue(MatchmakingQueue(entries: new_entries))
    }
    GetMatch(_player_id, reply_to) -> {
      process.send(reply_to, Error(Nil))
      actor.continue(state)
    }
    TryMatch(reply_to) -> {
      let entries_list = dict.values(state.entries)
      let match = case entries_list {
        [first, second, ..] -> Some(#(first, second))
        _ -> None
      }
      process.send(reply_to, match)
      actor.continue(state)
    }
    ListQueue(reply_to) -> {
      process.send(reply_to, dict.values(state.entries))
      actor.continue(state)
    }
  }
}

pub fn queue_player(
  queue: Subject(Message),
  player_id: String,
  hero_slugs: List(String),
) -> Result(Nil, String) {
  process.call(queue, waiting: 5000, sending: fn(subject) { QueuePlayer(player_id, hero_slugs, subject) })
}

pub fn leave_queue(
  queue: Subject(Message),
  player_id: String,
) -> Result(Nil, Nil) {
  process.call(queue, waiting: 5000, sending: fn(subject) { LeaveQueue(player_id, subject) })
}

pub fn try_match(
  queue: Subject(Message),
) -> Option(#(MatchmakingEntry, MatchmakingEntry)) {
  process.call(queue, waiting: 5000, sending: fn(subject) { TryMatch(subject) })
}

pub fn list_queue(queue: Subject(Message)) -> List(MatchmakingEntry) {
  process.call(queue, waiting: 5000, sending: fn(subject) { ListQueue(subject) })
}

pub fn remove_matched(
  queue: Subject(Message),
  player1: String,
  player2: String,
) -> Nil {
  process.call(queue, waiting: 5000, sending: fn(subject) { RemoveMatched(player1, player2, subject) })
}
