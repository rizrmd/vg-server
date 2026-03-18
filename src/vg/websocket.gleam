// WebSocket handler for game communication
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{type Option, None, Some}
import mist.{type ResponseData}
import pog
import vg/connection_registry
import vg/db
import vg/game_json.{
  type ClientMessage, type ServerMessage, Authenticate, AuthError,
  Authenticated, CastAction, Connected, Error as ServerError, GetLeaderboard,
  GetMatchHistory, GetPlayerStats, Leaderboard, LeaveMatch, MatchFound,
  MatchHistory, MatchmakingQueued, PlayerStatsResponse, ProfileUpdated,
  QueueMatchmaking, RerollHand, StateUpdate, UpsertProfile,
}
import vg/google_auth
import vg/json_parse
import vg/match
import vg/match_registry
import vg/matchmaking
import vg/player_registry

// WebSocket connection state
pub type WsState {
  WsState(
    player_id: String,
    authenticated: Bool,
    google_client_id: String,
    player_registry: Subject(player_registry.Message),
    matchmaking: Subject(matchmaking.Message),
    match_registry: Subject(match_registry.Message),
    connection_registry: Subject(connection_registry.Message),
    current_match_id: Option(String),
    current_team: Option(Int),
    db_conn: Option(pog.Connection),
    ws_conn: Option(mist.WebsocketConnection),
  )
}

pub fn handle_websocket(
  req: Request(mist.Connection),
  player_registry: Subject(player_registry.Message),
  matchmaking: Subject(matchmaking.Message),
  match_registry: Subject(match_registry.Message),
  connection_registry: Subject(connection_registry.Message),
  db_conn: Option(pog.Connection),
  google_client_id: String,
) -> Response(ResponseData) {
  mist.websocket(
    request: req,
    handler: fn(state, msg, conn) { handle_message(state, msg, conn) },
    on_init: fn(conn) {
      on_init(
        conn,
        player_registry,
        matchmaking,
        match_registry,
        connection_registry,
        db_conn,
        google_client_id,
      )
    },
    on_close: fn(state) {
      // Unregister connection when client disconnects
      connection_registry.unregister_connection(
        state.connection_registry,
        state.player_id,
      )
    },
  )
}

fn on_init(
  conn: mist.WebsocketConnection,
  player_registry: Subject(player_registry.Message),
  matchmaking: Subject(matchmaking.Message),
  match_registry: Subject(match_registry.Message),
  connection_registry: Subject(connection_registry.Message),
  db_conn: Option(pog.Connection),
  google_client_id: String,
) {
  let temp_id = "anon_" <> int.to_string(int.random(1_000_000))
  let state =
    WsState(
      player_id: temp_id,
      authenticated: False,
      google_client_id: google_client_id,
      player_registry: player_registry,
      matchmaking: matchmaking,
      match_registry: match_registry,
      connection_registry: connection_registry,
      current_match_id: None,
      current_team: None,
      db_conn: db_conn,
      ws_conn: Some(conn),
    )

  send_server_message(conn, Connected(temp_id))
  #(state, None)
}

fn handle_message(
  state: WsState,
  msg: mist.WebsocketMessage(String),
  conn: mist.WebsocketConnection,
) -> mist.Next(WsState, String) {
  case msg {
    mist.Text(text) -> {
      case json_parse.parse_client_message(text) {
        Ok(client_msg) -> handle_client_message(state, client_msg, conn)
        Error(_) -> {
          send_server_message(
            conn,
            ServerError("PARSE_ERROR", "Invalid JSON message"),
          )
          mist.continue(state)
        }
      }
    }
    _ -> mist.continue(state)
  }
}

fn handle_client_message(
  state: WsState,
  msg: ClientMessage,
  conn: mist.WebsocketConnection,
) -> mist.Next(WsState, String) {
  case msg {
    Authenticate(id_token) -> handle_authenticate(state, id_token, conn)
    _ -> {
      case state.authenticated {
        False -> {
          send_server_message(
            conn,
            AuthError("NOT_AUTHENTICATED", "Send authenticate message first"),
          )
          mist.continue(state)
        }
        True -> handle_authenticated_message(state, msg, conn)
      }
    }
  }
}

fn handle_authenticate(
  state: WsState,
  id_token: String,
  conn: mist.WebsocketConnection,
) -> mist.Next(WsState, String) {
  case state.db_conn {
    None -> {
      send_server_message(
        conn,
        AuthError("NO_DB", "Database not available for authentication"),
      )
      mist.continue(state)
    }
    Some(db_conn) -> {
      case
        google_auth.verify_google_token(id_token, state.google_client_id)
      {
        Ok(token_info) -> {
          let now = get_timestamp()
          case
            db.get_or_create_google_player(
              db_conn,
              token_info.sub,
              token_info.email,
              token_info.name,
              token_info.picture,
              now,
            )
          {
            Ok(player) -> {
              // Register connection with persistent player_id
              connection_registry.register_connection(
                state.connection_registry,
                player.player_id,
                conn,
              )
              // Also set up player profile
              let _ =
                player_registry.upsert_profile(
                  state.player_registry,
                  player.player_id,
                  player.display_name,
                )
              send_server_message(
                conn,
                Authenticated(
                  player.player_id,
                  player.display_name,
                  player.email,
                ),
              )
              mist.continue(
                WsState(
                  ..state,
                  player_id: player.player_id,
                  authenticated: True,
                ),
              )
            }
            Error(_) -> {
              send_server_message(
                conn,
                AuthError("DB_ERROR", "Failed to create player account"),
              )
              mist.continue(state)
            }
          }
        }
        Error(err) -> {
          send_server_message(conn, AuthError("INVALID_TOKEN", err))
          mist.continue(state)
        }
      }
    }
  }
}

fn handle_authenticated_message(
  state: WsState,
  msg: ClientMessage,
  conn: mist.WebsocketConnection,
) -> mist.Next(WsState, String) {
  case msg {
    Authenticate(_) -> mist.continue(state)
    UpsertProfile(display_name) -> {
      case
        player_registry.upsert_profile(
          state.player_registry,
          state.player_id,
          display_name,
        )
      {
        Ok(profile) -> {
          send_server_message(conn, ProfileUpdated(profile))
          mist.continue(state)
        }
        Error(err) -> {
          send_server_message(conn, ServerError("PROFILE_ERROR", err))
          mist.continue(state)
        }
      }
    }

    QueueMatchmaking(h1, h2, h3) -> {
      case
        matchmaking.queue_player(state.matchmaking, state.player_id, [
          h1,
          h2,
          h3,
        ])
      {
        Ok(Nil) -> {
          send_server_message(conn, MatchmakingQueued)
          mist.continue(state)
        }
        Error(err) -> {
          send_server_message(conn, ServerError("MATCHMAKING_ERROR", err))
          mist.continue(state)
        }
      }
    }

    CastAction(match_id, caster_slot, hand_slot_index) -> {
      case state.current_match_id {
        Some(current_id) if current_id == match_id -> {
          case match_registry.get_match(state.match_registry, match_id) {
            Ok(match_actor) -> {
              case
                match.cast_action_with_caster(
                  match_actor,
                  state.player_id,
                  caster_slot,
                  hand_slot_index,
                )
              {
                Ok(Nil) -> {
                  send_match_state(conn, match_actor, state)
                  mist.continue(state)
                }
                Error(err) -> {
                  send_server_message(conn, ServerError("CAST_ERROR", err))
                  mist.continue(state)
                }
              }
            }
            Error(_) -> {
              send_server_message(
                conn,
                ServerError("MATCH_NOT_FOUND", "Match not found"),
              )
              mist.continue(state)
            }
          }
        }
        _ -> {
          send_server_message(
            conn,
            ServerError("NOT_IN_MATCH", "You are not in this match"),
          )
          mist.continue(state)
        }
      }
    }

    RerollHand(match_id) -> {
      case state.current_match_id {
        Some(current_id) if current_id == match_id -> {
          case match_registry.get_match(state.match_registry, match_id) {
            Ok(match_actor) -> {
              case match.reroll_hand(match_actor, state.player_id) {
                Ok(_) -> {
                  send_match_state(conn, match_actor, state)
                  mist.continue(state)
                }
                Error(err) -> {
                  send_server_message(conn, ServerError("REROLL_ERROR", err))
                  mist.continue(state)
                }
              }
            }
            Error(_) -> {
              send_server_message(
                conn,
                ServerError("MATCH_NOT_FOUND", "Match not found"),
              )
              mist.continue(state)
            }
          }
        }
        _ -> {
          send_server_message(
            conn,
            ServerError("NOT_IN_MATCH", "You are not in this match"),
          )
          mist.continue(state)
        }
      }
    }

    LeaveMatch(_match_id) -> {
      send_server_message(
        conn,
        ServerError("NOT_IMPLEMENTED", "leave_match not yet fully implemented"),
      )
      mist.continue(
        WsState(..state, current_match_id: None, current_team: None),
      )
    }

    GetMatchHistory(limit, offset) -> {
      case state.db_conn {
        Some(db) -> {
          case db.get_player_match_history(db, state.player_id, limit, offset) {
            Ok(matches) -> {
              send_server_message(conn, MatchHistory(matches))
              mist.continue(state)
            }
            Error(_) -> {
              send_server_message(
                conn,
                ServerError("DB_ERROR", "Failed to fetch match history"),
              )
              mist.continue(state)
            }
          }
        }
        None -> {
          send_server_message(
            conn,
            ServerError("NO_DB", "Database not available"),
          )
          mist.continue(state)
        }
      }
    }

    GetLeaderboard(limit) -> {
      case state.db_conn {
        Some(db) -> {
          case db.get_leaderboard(db, limit) {
            Ok(entries) -> {
              send_server_message(conn, Leaderboard(entries))
              mist.continue(state)
            }
            Error(_) -> {
              send_server_message(
                conn,
                ServerError("DB_ERROR", "Failed to fetch leaderboard"),
              )
              mist.continue(state)
            }
          }
        }
        None -> {
          send_server_message(
            conn,
            ServerError("NO_DB", "Database not available"),
          )
          mist.continue(state)
        }
      }
    }

    GetPlayerStats(target_id) -> {
      case state.db_conn {
        Some(db) -> {
          case db.get_player_stats(db, target_id) {
            Ok(Some(stats)) -> {
              send_server_message(conn, PlayerStatsResponse(stats))
              mist.continue(state)
            }
            Ok(None) -> {
              send_server_message(
                conn,
                ServerError("PLAYER_NOT_FOUND", "Player not found"),
              )
              mist.continue(state)
            }
            Error(_) -> {
              send_server_message(
                conn,
                ServerError("DB_ERROR", "Failed to fetch player stats"),
              )
              mist.continue(state)
            }
          }
        }
        None -> {
          send_server_message(
            conn,
            ServerError("NO_DB", "Database not available"),
          )
          mist.continue(state)
        }
      }
    }
  }
}

fn send_match_state(
  conn: mist.WebsocketConnection,
  match_actor: Subject(match.Message),
  _state: WsState,
) -> Nil {
  let match_state = match.get_state(match_actor)

  let team_states_list = dict.values(match_state.team_states)
  let heroes_list = dict.values(match_state.heroes)
  let statuses_list = dict.values(match_state.statuses)
  let casts_list = dict.values(match_state.casts)
  let players_list = dict.values(match_state.players)

  send_server_message(
    conn,
    StateUpdate(
      match: match_state.match,
      players: players_list,
      team_states: team_states_list,
      heroes: heroes_list,
      hand: match_state.hand_slots,
      statuses: statuses_list,
      casts: casts_list,
    ),
  )
}

fn send_server_message(
  conn: mist.WebsocketConnection,
  msg: ServerMessage,
) -> Nil {
  let json_str = game_json.encode_server_message(msg)
  let _ = mist.send_text_frame(conn, json_str)
  Nil
}

// Public helper to notify player of match found
pub fn notify_match_found(
  conn: mist.WebsocketConnection,
  match_id: String,
  team: Int,
) -> Nil {
  send_server_message(conn, MatchFound(match_id, team))
}

fn get_timestamp() -> Int {
  do_get_timestamp()
}

@external(erlang, "erlang", "system_time")
fn do_get_timestamp() -> Int
