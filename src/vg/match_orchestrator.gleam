// Match Orchestrator - runs the matchmaking loop and match ticks
import gleam/dict
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
import vg/types.{Active}

const matchmaking_interval_ms = 1000
const match_tick_interval_ms = 200

// Orchestrator state
pub type OrchestratorState {
  OrchestratorState(
    orchestrator: Subject(Message),
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
  actor.new_with_initialiser(1000, fn(orchestrator) {
    actor.initialised(
      OrchestratorState(
        orchestrator: orchestrator,
        matchmaking: matchmaking,
        match_registry: match_registry,
        connection_registry: connection_registry,
      ),
    )
    |> actor.returning(orchestrator)
    |> Ok
  })
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

      let _ =
        process.send_after(
          state.orchestrator,
          matchmaking_interval_ms,
          RunMatchmaking,
        )
      actor.continue(state)
    }

    TickMatches(now) -> {
      // Get all active matches, tick them, and push state to players
      let match_ids = match_registry.list_matches(state.match_registry)
      list.each(match_ids, fn(match_id) {
        case match_registry.get_match(state.match_registry, match_id) {
          Ok(match_actor) -> {
            let _ = match.tick_match(match_actor, now)
            // Push state updates to all players in active matches
            let match_state = match.get_state(match_actor)
            case match_state.match.phase {
              Active -> {
                let _ = dict.each(match_state.players, fn(_pid, player) {
                  let team_hand =
                    list.filter(match_state.hand_slots, fn(slot) {
                      slot.team == player.team
                    })
                  let msg =
                    game_json.encode_server_message(game_json.StateUpdate(
                      match: match_state.match,
                      players: dict.values(match_state.players),
                      team_states: dict.values(match_state.team_states),
                      heroes: dict.values(match_state.heroes),
                      hand: team_hand,
                      statuses: dict.values(match_state.statuses),
                      casts: dict.values(match_state.casts),
                    ))
                  let _ =
                    connection_registry.send_message(
                      state.connection_registry,
                      player.player_id,
                      msg,
                    )
                  Nil
                })
                Nil
              }
              _ -> Nil
            }
          }
          Error(_) -> Nil
        }
      })

      let _ =
        process.send_after(
          state.orchestrator,
          match_tick_interval_ms,
          TickMatches(get_timestamp()),
        )
      actor.continue(state)
    }
  }
}

fn get_timestamp() -> Int {
  do_get_timestamp()
}

@external(erlang, "vg_server_ffi", "timestamp_ms")
fn do_get_timestamp() -> Int

// Public API

pub fn run_matchmaking(orchestrator: Subject(Message)) -> Nil {
  process.send(orchestrator, RunMatchmaking)
}

pub fn tick_matches(orchestrator: Subject(Message), now: Int) -> Nil {
  process.send(orchestrator, TickMatches(now))
}
