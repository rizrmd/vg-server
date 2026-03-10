// Player Registry - manages player profiles

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import vg/types.{type PlayerProfile, PlayerProfile}

pub type PlayerRegistry {
  PlayerRegistry(profiles: Dict(String, PlayerProfile))
}

pub type Message {
  UpsertProfile(player_id: String, display_name: String, reply_to: Subject(Result(PlayerProfile, String)))
  GetProfile(player_id: String, reply_to: Subject(Result(PlayerProfile, Nil)))
  RemoveProfile(player_id: String)
}

pub fn start() {
  actor.new(PlayerRegistry(profiles: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  state: PlayerRegistry,
  message: Message,
) -> actor.Next(PlayerRegistry, Message) {
  case message {
    UpsertProfile(player_id, display_name, reply_to) -> {
      let profile = case dict.get(state.profiles, player_id) {
        Ok(existing) -> PlayerProfile(
          ..existing,
          display_name: display_name,
          updated_at: 0,
        )
        Error(_) -> PlayerProfile(
          id: player_id,
          display_name: display_name,
          created_at: 0,
          updated_at: 0,
        )
      }
      
      let result = case string.length(display_name) > 0 && string.length(display_name) <= 32 {
        True -> {
          let new_profiles = dict.insert(state.profiles, player_id, profile)
          process.send(reply_to, Ok(profile))
          actor.continue(PlayerRegistry(profiles: new_profiles))
        }
        False -> {
          process.send(reply_to, Error("Display name must be 1-32 characters"))
          actor.continue(state)
        }
      }
      result
    }
    GetProfile(player_id, reply_to) -> {
      process.send(reply_to, dict.get(state.profiles, player_id))
      actor.continue(state)
    }
    RemoveProfile(player_id) -> {
      let new_profiles = dict.delete(state.profiles, player_id)
      actor.continue(PlayerRegistry(profiles: new_profiles))
    }
  }
}

import gleam/string

pub fn upsert_profile(
  registry: Subject(Message),
  player_id: String,
  display_name: String,
) -> Result(PlayerProfile, String) {
  process.call(registry, waiting: 5000, sending: fn(subject) { UpsertProfile(player_id, display_name, subject) })
}

pub fn get_profile(
  registry: Subject(Message),
  player_id: String,
) -> Result(PlayerProfile, Nil) {
  process.call(registry, waiting: 5000, sending: fn(subject) { GetProfile(player_id, subject) })
}

pub fn remove_profile(registry: Subject(Message), player_id: String) -> Nil {
  process.send(registry, RemoveProfile(player_id))
}
