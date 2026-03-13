// Match Orchestrator - runs the matchmaking loop and match ticks
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import vg/connection_registry
import vg/game_json
import vg/match
import vg/match_registry
import vg/matchmaking

// Orchestrator state
pub type OrchestratorState {
  OrchestratorState(
    matchmaking: Subject(matchmaking.Message),
    match_registry: Subject(match_registry.Message),
    connection_registry: Subject(connection_registry.Message),
  )
}

// Messages
pub type Message {
  RunMatchmaking
  TickMatches(now: Int)
}

pub fn start(
  matchmaking: Subject(matchmaking.Message),
  match_registry: Subject(match_registry.Message),
  connection_registry: Subject(connection_registry.Message),
) {
  let initial_state =
    OrchestratorState(
      matchmaking: matchmaking,
      match_registry: match_registry,
      connection_registry: connection_registry,
    )

  actor.new(initial_state)
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  state: OrchestratorState,
  message: Message,
) -> actor.Next(OrchestratorState, Message) {
  case message {
    RunMatchmaking -> {
      // Try to find a match
      case matchmaking.try_match(state.matchmaking) {
        Some(#(p1, p2)) -> {
          // Create a new match
          let match_id =
            "match_"
            <> int.to_string(get_timestamp())
            <> "_"
            <> int.to_string(int.random(10_000))

          case match_registry.create_match(state.match_registry, match_id) {
            Ok(match_actor) -> {
              // Add both players to the match
              let _ = match.join_match(match_actor, p1.player_id, 1)
              let _ = match.join_match(match_actor, p2.player_id, 2)

              // Start the match with players' selected heroes
              let team1_heroes = [
                p1.hero_slug_1,
                p1.hero_slug_2,
                p1.hero_slug_3,
              ]
              let team2_heroes = [
                p2.hero_slug_1,
                p2.hero_slug_2,
                p2.hero_slug_3,
              ]
              let _ =
                match.start_match_with_heroes(
                  match_actor,
                  team1_heroes,
                  team2_heroes,
                )

              // Remove players from queue
              let _ =
                matchmaking.remove_matched(
                  state.matchmaking,
                  p1.player_id,
                  p2.player_id,
                )

              // Notify players via their WebSocket connections
              let msg_p1 =
                game_json.encode_server_message(game_json.MatchFound(
                  match_id,
                  1,
                ))
              let msg_p2 =
                game_json.encode_server_message(game_json.MatchFound(
                  match_id,
                  2,
                ))
              let _ =
                connection_registry.send_message(
                  state.connection_registry,
                  p1.player_id,
                  msg_p1,
                )
              let _ =
                connection_registry.send_message(
                  state.connection_registry,
                  p2.player_id,
                  msg_p2,
                )

              Nil
            }
            Error(_) -> Nil
          }
        }
        None -> Nil
      }

      // Schedule next matchmaking attempt (every 2 seconds)
      // The actor loop will continue and we rely on external triggers or a timer
      actor.continue(state)
    }

    TickMatches(now) -> {
      // Get all active matches and tick them
      let match_ids = match_registry.list_matches(state.match_registry)
      list.each(match_ids, fn(match_id) {
        case match_registry.get_match(state.match_registry, match_id) {
          Ok(match_actor) -> {
            let _ = match.tick_match(match_actor, now)
            Nil
          }
          Error(_) -> Nil
        }
      })

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

pub fn run_matchmaking(orchestrator: Subject(Message)) -> Nil {
  process.send(orchestrator, RunMatchmaking)
}

pub fn tick_matches(orchestrator: Subject(Message), now: Int) -> Nil {
  process.send(orchestrator, TickMatches(now))
}
