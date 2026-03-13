// JSON parsing for client messages (simple string-based parser)
import gleam/int
import gleam/result
import gleam/string
import vg/game_json.{
  type ClientMessage, CastAction, GetLeaderboard, GetMatchHistory,
  GetPlayerStats, LeaveMatch, QueueMatchmaking, RerollHand, UpsertProfile,
}

pub fn parse_client_message(json_str: String) -> Result(ClientMessage, Nil) {
  // Get the type field
  use msg_type <- result.try(get_json_string_field(json_str, "type"))

  case msg_type {
    "upsert_profile" -> {
      use display_name <- result.try(get_json_string_field(
        json_str,
        "display_name",
      ))
      Ok(UpsertProfile(display_name: display_name))
    }
    "queue_matchmaking" -> {
      use h1 <- result.try(get_json_string_field(json_str, "hero_slug_1"))
      use h2 <- result.try(get_json_string_field(json_str, "hero_slug_2"))
      use h3 <- result.try(get_json_string_field(json_str, "hero_slug_3"))
      Ok(QueueMatchmaking(hero_slug_1: h1, hero_slug_2: h2, hero_slug_3: h3))
    }
    "cast_action" -> {
      use match_id <- result.try(get_json_string_field(json_str, "match_id"))
      use caster_slot <- result.try(get_json_int_field(json_str, "caster_slot"))
      use hand_slot <- result.try(get_json_int_field(
        json_str,
        "hand_slot_index",
      ))
      Ok(CastAction(
        match_id: match_id,
        caster_slot: caster_slot,
        hand_slot_index: hand_slot,
      ))
    }
    "reroll_hand" -> {
      use match_id <- result.try(get_json_string_field(json_str, "match_id"))
      Ok(RerollHand(match_id: match_id))
    }
    "leave_match" -> {
      use match_id <- result.try(get_json_string_field(json_str, "match_id"))
      Ok(LeaveMatch(match_id: match_id))
    }
    "get_match_history" -> {
      let limit = case get_json_int_field(json_str, "limit") {
        Ok(n) if n > 0 -> n
        _ -> 10
      }
      let offset = case get_json_int_field(json_str, "offset") {
        Ok(n) if n >= 0 -> n
        _ -> 0
      }
      Ok(GetMatchHistory(limit: limit, offset: offset))
    }
    "get_leaderboard" -> {
      let limit = case get_json_int_field(json_str, "limit") {
        Ok(n) if n > 0 -> n
        _ -> 10
      }
      Ok(GetLeaderboard(limit: limit))
    }
    "get_player_stats" -> {
      use target_id <- result.try(get_json_string_field(
        json_str,
        "target_player_id",
      ))
      Ok(GetPlayerStats(target_player_id: target_id))
    }
    _ -> Error(Nil)
  }
}

// Simple JSON field extraction
fn get_json_string_field(json: String, field: String) -> Result(String, Nil) {
  let pattern = "\"" <> field <> "\":\""
  case string.split_once(json, pattern) {
    Ok(#(_, rest)) -> {
      case string.split_once(rest, "\"") {
        Ok(#(value, _)) -> Ok(value)
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn get_json_int_field(json: String, field: String) -> Result(Int, Nil) {
  let pattern = "\"" <> field <> "\":"
  case string.split_once(json, pattern) {
    Ok(#(_, rest)) -> {
      // Find end of number (comma, }, ], whitespace)
      let number_part =
        take_while(rest, fn(c) {
          c != "," && c != "}" && c != "]" && c != " " && c != "\n"
        })
      case int.parse(string.trim(number_part)) {
        Ok(n) -> Ok(n)
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn take_while(s: String, predicate: fn(String) -> Bool) -> String {
  do_take_while(s, predicate, 0)
}

fn do_take_while(s: String, predicate: fn(String) -> Bool, i: Int) -> String {
  case string_grapheme_at(s, i) {
    Ok(c) -> {
      case predicate(c) {
        True -> do_take_while(s, predicate, i + 1)
        False -> string.slice(s, 0, i)
      }
    }
    Error(_) -> string.slice(s, 0, i)
  }
}

fn string_grapheme_at(s: String, i: Int) -> Result(String, Nil) {
  let graphemes = string.to_graphemes(s)
  case list_at(graphemes, i) {
    Ok(c) -> Ok(c)
    Error(_) -> Error(Nil)
  }
}

fn list_at(lst: List(String), i: Int) -> Result(String, Nil) {
  case i {
    0 -> {
      case lst {
        [x, ..] -> Ok(x)
        [] -> Error(Nil)
      }
    }
    n if n > 0 -> {
      case lst {
        [_, ..rest] -> list_at(rest, n - 1)
        [] -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}
