// Match actor - manages individual match state and lifecycle
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import sqlight
import vg/content
import vg/db
import vg/match_logic
import vg/types.{
  type GameMatch, type MatchCast, type MatchHandSlot, type MatchHero,
  type MatchPlayer, type MatchStatus, type MatchTeamState, Active, Finished,
  GameMatch, MatchCast, MatchHandSlot, MatchPlayer, NoWinner, Team1, Team2,
  Waiting,
}

// Match actor state
pub type MatchActorState {
  MatchActorState(
    match: GameMatch,
    players: Dict(String, MatchPlayer),
    team_states: Dict(Int, MatchTeamState),
    heroes: Dict(String, MatchHero),
    hand_slots: List(MatchHandSlot),
    statuses: Dict(String, MatchStatus),
    casts: Dict(String, MatchCast),
    db_conn: Option(sqlight.Connection),
    match_saved: Bool,
    // Track if we've already saved this match to DB
  )
}

// Messages the match actor can receive
pub type Message {
  // Player actions
  JoinMatch(
    player_id: String,
    team: Int,
    reply_to: Subject(Result(Nil, String)),
  )
  // CastAction: caster_slot is the hero slot (1-3); target resolution is internal
  CastAction(
    player_id: String,
    caster_slot: Int,
    hand_slot_index: Int,
    reply_to: Subject(Result(Nil, String)),
  )
  RerollHand(
    player_id: String,
    reply_to: Subject(Result(List(MatchHandSlot), String)),
  )

  // State queries
  GetState(reply_to: Subject(MatchActorState))
  GetStateForPlayer(
    player_id: String,
    reply_to: Subject(Option(MatchActorState)),
  )

  // Lifecycle
  StartMatch(reply_to: Subject(Result(Nil, String)))
  StartMatchWithHeroes(
    hero_slugs_team1: List(String),
    hero_slugs_team2: List(String),
    reply_to: Subject(Result(Nil, String)),
  )
  Tick(now: Int, reply_to: Subject(Result(Nil, String)))
  EndMatch(winner: Int, reply_to: Subject(Nil))
}

// Start a new match actor
pub fn start(
  match_id: String,
  created_at: Int,
) -> Result(actor.Started(Subject(Message)), actor.StartError) {
  start_with_db(match_id, created_at, None)
}

// Start a new match actor with database connection
pub fn start_with_db(
  match_id: String,
  created_at: Int,
  db_conn: Option(sqlight.Connection),
) -> Result(actor.Started(Subject(Message)), actor.StartError) {
  let initial_state =
    MatchActorState(
      match: GameMatch(
        match_id: match_id,
        phase: Waiting,
        created_at: created_at,
        started_at: 0,
        winner: NoWinner,
      ),
      players: dict.new(),
      team_states: dict.new(),
      heroes: dict.new(),
      hand_slots: [],
      statuses: dict.new(),
      casts: dict.new(),
      db_conn: db_conn,
      match_saved: False,
    )

  actor.start(actor.new(initial_state) |> actor.on_message(handle_message))
}

// Message handler
fn handle_message(
  state: MatchActorState,
  message: Message,
) -> actor.Next(MatchActorState, Message) {
  case message {
    JoinMatch(player_id, team, reply_to) -> {
      case state.match.phase {
        Waiting -> {
          let player =
            MatchPlayer(
              player_id: player_id,
              match_id: state.match.match_id,
              team: team,
            )
          let new_players = dict.insert(state.players, player_id, player)
          process.send(reply_to, Ok(Nil))
          actor.continue(MatchActorState(..state, players: new_players))
        }
        _ -> {
          process.send(reply_to, Error("Match already started"))
          actor.continue(state)
        }
      }
    }

    StartMatch(reply_to) -> {
      // Default heroes if not specified
      let default_team1 = ["iron-knight", "arc-strider", "necromancer"]
      let default_team2 = ["flame-warlock", "dawn-priest", "earth-warden"]
      handle_start_match(state, reply_to, default_team1, default_team2)
    }

    StartMatchWithHeroes(hero_slugs_team1, hero_slugs_team2, reply_to) -> {
      handle_start_match(state, reply_to, hero_slugs_team1, hero_slugs_team2)
    }

    CastAction(player_id, caster_slot, hand_slot_index, reply_to) -> {
      case state.match.phase {
        Active -> {
          case get_player_team(state, player_id) {
            Ok(team) -> {
              // Get the hand slot
              case get_hand_slot(state.hand_slots, team, hand_slot_index) {
                Ok(hand_slot) -> {
                  // Get caster hero by slot
                  case get_hero_by_slot(state.heroes, team, caster_slot) {
                    Ok(caster) -> {
                      // Get action definition to determine target
                      case content.get_action_def(hand_slot.action_slug) {
                        Ok(action) -> {
                          let target_result =
                            resolve_target(
                              state.heroes,
                              team,
                              caster,
                              action.target_rule,
                            )

                          case target_result {
                            Ok(target) -> {
                              // Create cast
                              let now = get_timestamp()
                              let cast =
                                create_cast(
                                  state.match.match_id,
                                  team,
                                  caster.hero_instance_id,
                                  target.hero_instance_id,
                                  hand_slot.action_slug,
                                  now,
                                )

                              // Deduct energy
                              case dict.get(state.team_states, team) {
                                Ok(team_state) -> {
                                  let new_team_state =
                                    match_logic.spend_energy(
                                      team_state,
                                      action.energy_cost,
                                    )
                                  let new_team_states =
                                    dict.insert(
                                      state.team_states,
                                      team,
                                      new_team_state,
                                    )
                                  let new_casts =
                                    dict.insert(state.casts, cast.cast_id, cast)

                                  process.send(reply_to, Ok(Nil))
                                  actor.continue(
                                    MatchActorState(
                                      ..state,
                                      team_states: new_team_states,
                                      casts: new_casts,
                                    ),
                                  )
                                }
                                Error(_) -> {
                                  process.send(
                                    reply_to,
                                    Error("Team state not found"),
                                  )
                                  actor.continue(state)
                                }
                              }
                            }
                            Error(_) -> {
                              process.send(reply_to, Error("No valid target"))
                              actor.continue(state)
                            }
                          }
                        }
                        Error(_) -> {
                          process.send(reply_to, Error("Invalid action"))
                          actor.continue(state)
                        }
                      }
                    }
                    Error(_) -> {
                      process.send(reply_to, Error("Invalid caster"))
                      actor.continue(state)
                    }
                  }
                }
                Error(_) -> {
                  process.send(reply_to, Error("Invalid hand slot"))
                  actor.continue(state)
                }
              }
            }
            Error(_) -> {
              process.send(reply_to, Error("Player not in match"))
              actor.continue(state)
            }
          }
        }
        _ -> {
          process.send(reply_to, Error("Match not active"))
          actor.continue(state)
        }
      }
    }

    RerollHand(player_id, reply_to) -> {
      case get_player_team(state, player_id) {
        Ok(team) -> {
          case dict.get(state.team_states, team) {
            Ok(team_state) -> {
              case
                match_logic.can_spend_energy(
                  team_state,
                  match_logic.reroll_cost,
                )
              {
                True -> {
                  let new_hand = roll_hand_for_team(state.match.match_id, team)

                  // Remove old hand slots for this team
                  let other_hands =
                    list.filter(state.hand_slots, fn(h) { h.team != team })
                  let all_hands = list.append(other_hands, new_hand)

                  let new_team_state =
                    match_logic.spend_energy(
                      team_state,
                      match_logic.reroll_cost,
                    )
                  let new_team_states =
                    dict.insert(state.team_states, team, new_team_state)

                  process.send(reply_to, Ok(new_hand))
                  actor.continue(
                    MatchActorState(
                      ..state,
                      hand_slots: all_hands,
                      team_states: new_team_states,
                    ),
                  )
                }
                False -> {
                  process.send(reply_to, Error("Not enough energy"))
                  actor.continue(state)
                }
              }
            }
            Error(_) -> {
              process.send(reply_to, Error("Team state not found"))
              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          process.send(reply_to, Error("Player not in match"))
          actor.continue(state)
        }
      }
    }

    Tick(now, reply_to) -> {
      case state.match.phase {
        Active -> {
          // Regenerate energy for both teams
          let new_team_states =
            dict.fold(state.team_states, dict.new(), fn(acc, team, ts) {
              dict.insert(acc, team, match_logic.regen_energy(ts, now))
            })

          // Resolve casts that are ready
          let #(new_casts, new_heroes, new_statuses) =
            resolve_casts(state.casts, state.heroes, state.statuses, now)

          // Check win condition
          let winner = match_logic.check_win_condition(new_heroes)
          let new_phase = case winner {
            NoWinner -> Active
            _ -> Finished
          }
          let new_match =
            GameMatch(..state.match, phase: new_phase, winner: winner)

          // Save match result to database if match just ended and not already saved
          let match_saved = case winner, state.db_conn, state.match_saved {
            NoWinner, _, _ -> state.match_saved
            // Match not over
            _, None, _ -> state.match_saved
            // No DB connection
            _, _, True -> state.match_saved
            // Already saved
            _, Some(conn), False -> {
              // Save match result
              let winner_int = case winner {
                Team1 -> 1
                Team2 -> 2
                NoWinner -> 0
              }

              // Get player IDs
              let player_ids = dict.values(state.players)
              case player_ids {
                [p1, p2, ..] -> {
                  let result =
                    db.MatchResult(
                      match_id: state.match.match_id,
                      player1_id: p1.player_id,
                      player2_id: p2.player_id,
                      winner: winner_int,
                      started_at: state.match.started_at,
                      ended_at: now,
                      duration_ms: now - state.match.started_at,
                    )
                  let _ = db.save_match_result(conn, result)

                  // Update player stats
                  let p1_won = winner_int == 1
                  let p2_won = winner_int == 2
                  let _ =
                    db.update_stats_after_match(conn, p1.player_id, p1_won, now)
                  let _ =
                    db.update_stats_after_match(conn, p2.player_id, p2_won, now)

                  True
                  // Mark as saved
                }
                _ -> state.match_saved
                // Not enough players
              }
            }
          }

          process.send(reply_to, Ok(Nil))
          actor.continue(MatchActorState(
            match: new_match,
            players: state.players,
            team_states: new_team_states,
            heroes: new_heroes,
            hand_slots: state.hand_slots,
            statuses: new_statuses,
            casts: new_casts,
            db_conn: state.db_conn,
            match_saved: match_saved,
          ))
        }
        _ -> {
          process.send(reply_to, Ok(Nil))
          actor.continue(state)
        }
      }
    }

    GetState(reply_to) -> {
      process.send(reply_to, state)
      actor.continue(state)
    }

    GetStateForPlayer(player_id, reply_to) -> {
      case dict.has_key(state.players, player_id) {
        True -> {
          process.send(reply_to, Some(state))
        }
        False -> {
          process.send(reply_to, None)
        }
      }
      actor.continue(state)
    }

    EndMatch(winner, reply_to) -> {
      let winner_team = case winner {
        1 -> Team1
        2 -> Team2
        _ -> NoWinner
      }
      let ended_match =
        GameMatch(..state.match, phase: Finished, winner: winner_team)
      process.send(reply_to, Nil)
      actor.continue(MatchActorState(..state, match: ended_match))
    }
  }
}

// Helper functions

fn get_player_team(
  state: MatchActorState,
  player_id: String,
) -> Result(Int, Nil) {
  case dict.get(state.players, player_id) {
    Ok(player) -> Ok(player.team)
    Error(_) -> Error(Nil)
  }
}

fn get_hand_slot(
  slots: List(MatchHandSlot),
  team: Int,
  index: Int,
) -> Result(MatchHandSlot, Nil) {
  slots
  |> list.filter(fn(s) { s.team == team })
  |> list.find(fn(s) { s.slot_index == index })
}

fn get_hero_by_slot(
  heroes: Dict(String, MatchHero),
  team: Int,
  slot: Int,
) -> Result(MatchHero, Nil) {
  heroes
  |> dict.values()
  |> list.find(fn(h) { h.team == team && h.slot_index == slot })
}

fn get_first_alive_hero(
  heroes: Dict(String, MatchHero),
  team: Int,
) -> Result(MatchHero, Nil) {
  heroes
  |> dict.values()
  |> list.filter(fn(h) { h.team == team && h.alive })
  |> list.first()
}

fn get_first_alive_hero_any(
  heroes: Dict(String, MatchHero),
) -> Result(MatchHero, Nil) {
  heroes
  |> dict.values()
  |> list.filter(fn(h) { h.alive })
  |> list.first()
}

fn resolve_target(
  heroes: Dict(String, MatchHero),
  caster_team: Int,
  caster: MatchHero,
  target_rule: types.TargetRule,
) -> Result(MatchHero, Nil) {
  case target_rule {
    types.Self -> Ok(caster)
    types.NoTarget -> Ok(caster)
    types.AllySingle -> Ok(caster)
    types.EnemySingle -> {
      let target_team = case caster_team {
        1 -> 2
        _ -> 1
      }
      get_first_alive_hero(heroes, target_team)
    }
    types.AnySingle -> resolve_any_auto_target(heroes, caster_team, caster)
    types.AllyAuto -> Ok(caster)
    types.EnemyAuto -> {
      let target_team = case caster_team {
        1 -> 2
        _ -> 1
      }
      get_first_alive_hero(heroes, target_team)
    }
    types.AnyAuto -> resolve_any_auto_target(heroes, caster_team, caster)
  }
}

fn resolve_any_auto_target(
  heroes: Dict(String, MatchHero),
  caster_team: Int,
  caster: MatchHero,
) -> Result(MatchHero, Nil) {
  let target_team = case caster_team {
    1 -> 2
    _ -> 1
  }
  case get_first_alive_hero(heroes, target_team) {
    Ok(target) -> Ok(target)
    Error(_) -> {
      case caster.alive {
        True -> Ok(caster)
        False -> get_first_alive_hero_any(heroes)
      }
    }
  }
}

fn spawn_heroes_for_team(
  match_id: String,
  team: Int,
  hero_slugs: List(String),
  now: Int,
) -> List(#(String, MatchHero)) {
  hero_slugs
  |> list.index_map(fn(slug, index) {
    match_logic.spawn_hero(match_id, team, index + 1, slug, now)
  })
  |> list.filter(fn(r) { r != Error(Nil) })
  |> list.map(fn(r) {
    case r {
      Ok(hero) -> #(hero.hero_instance_id, hero)
      Error(_) -> panic as "unreachable"
    }
  })
}

fn roll_hand_for_team(match_id: String, team: Int) -> List(MatchHandSlot) {
  let action_slugs = match_logic.roll_hand()
  action_slugs
  |> list.index_map(fn(slug, index) {
    MatchHandSlot(
      match_id: match_id,
      team: team,
      slot_index: index + 1,
      action_slug: slug,
    )
  })
}

fn create_cast(
  match_id: String,
  team: Int,
  caster_id: String,
  target_id: String,
  action_slug: String,
  now: Int,
) -> MatchCast {
  let casting_time = case content.get_action_def(action_slug) {
    Ok(action) -> action.casting_time_ms
    Error(_) -> 1000
  }

  MatchCast(
    cast_id: "cast_"
      <> int.to_string(now)
      <> "_"
      <> int.to_string(int.random(10_000)),
    match_id: match_id,
    team: team,
    caster_hero_instance_id: caster_id,
    target_hero_instance_id: target_id,
    action_slug: action_slug,
    started_at: now,
    resolves_at: now + casting_time,
    resolved: False,
  )
}

fn resolve_casts(
  casts: Dict(String, MatchCast),
  heroes: Dict(String, MatchHero),
  statuses: Dict(String, MatchStatus),
  now: Int,
) -> #(
  Dict(String, MatchCast),
  Dict(String, MatchHero),
  Dict(String, MatchStatus),
) {
  let pending_casts =
    dict.values(casts)
    |> list.filter(fn(c) { !c.resolved && c.resolves_at <= now })

  list.fold(pending_casts, #(casts, heroes, statuses), fn(acc, cast) {
    let #(current_casts, current_heroes, current_statuses) = acc

    // Get caster and target heroes
    case
      dict.get(current_heroes, cast.caster_hero_instance_id),
      dict.get(current_heroes, cast.target_hero_instance_id)
    {
      Ok(caster), Ok(target) -> {
        // Resolve the cast
        case
          content.get_hero_def(caster.hero_slug),
          content.get_hero_def(target.hero_slug),
          content.get_action_def(cast.action_slug)
        {
          Ok(caster_def), Ok(target_def), Ok(action) -> {
            let #(resolved_cast, _, updated_target, new_statuses, _) =
              match_logic.resolve_cast(
                cast,
                action,
                caster,
                target,
                caster_def,
                target_def,
                now,
              )

            let new_casts =
              dict.insert(current_casts, resolved_cast.cast_id, resolved_cast)
            let new_heroes =
              dict.insert(
                current_heroes,
                updated_target.hero_instance_id,
                updated_target,
              )

            // Add new statuses
            let new_statuses_dict =
              list.fold(new_statuses, current_statuses, fn(acc, s) {
                dict.insert(acc, s.status_id, s)
              })

            #(new_casts, new_heroes, new_statuses_dict)
          }
          _, _, _ -> #(current_casts, current_heroes, current_statuses)
        }
      }
      _, _ -> #(current_casts, current_heroes, current_statuses)
    }
  })
}

fn get_timestamp() -> Int {
  do_get_timestamp()
}

@external(erlang, "erlang", "system_time")
fn do_get_timestamp() -> Int

// Public API helpers

pub fn join_match(
  match_actor: Subject(Message),
  player_id: String,
  team: Int,
) -> Result(Nil, String) {
  process.call(match_actor, waiting: 5000, sending: fn(subject) {
    JoinMatch(player_id, team, subject)
  })
}

pub fn get_state(match_actor: Subject(Message)) -> MatchActorState {
  process.call(match_actor, waiting: 5000, sending: fn(subject) {
    GetState(subject)
  })
}

pub fn tick_match(
  match_actor: Subject(Message),
  now: Int,
) -> Result(Nil, String) {
  process.call(match_actor, waiting: 5000, sending: fn(subject) {
    Tick(now, subject)
  })
}

pub fn start_match(match_actor: Subject(Message)) -> Result(Nil, String) {
  process.call(match_actor, waiting: 5000, sending: fn(subject) {
    StartMatch(subject)
  })
}

pub fn start_match_with_heroes(
  match_actor: Subject(Message),
  hero_slugs_team1: List(String),
  hero_slugs_team2: List(String),
) -> Result(Nil, String) {
  process.call(match_actor, waiting: 5000, sending: fn(subject) {
    StartMatchWithHeroes(hero_slugs_team1, hero_slugs_team2, subject)
  })
}

// Cast action with the dropped-on hero as the acting slot.
pub fn cast_action_with_caster(
  match_actor: Subject(Message),
  player_id: String,
  caster_slot: Int,
  hand_slot_index: Int,
) -> Result(Nil, String) {
  process.call(match_actor, waiting: 5000, sending: fn(subject) {
    CastAction(player_id, caster_slot, hand_slot_index, subject)
  })
}

pub fn cast_action(
  match_actor: Subject(Message),
  player_id: String,
  caster_slot: Int,
  hand_slot_index: Int,
) -> Result(Nil, String) {
  cast_action_with_caster(match_actor, player_id, caster_slot, hand_slot_index)
}

pub fn reroll_hand(
  match_actor: Subject(Message),
  player_id: String,
) -> Result(List(types.MatchHandSlot), String) {
  process.call(match_actor, waiting: 5000, sending: fn(subject) {
    RerollHand(player_id, subject)
  })
}

// Helper to handle StartMatch with custom heroes
fn handle_start_match(
  state: MatchActorState,
  reply_to: Subject(Result(Nil, String)),
  hero_slugs_team1: List(String),
  hero_slugs_team2: List(String),
) -> actor.Next(MatchActorState, Message) {
  case state.match.phase {
    Waiting -> {
      // Check we have 2 players
      case dict.size(state.players) == 2 {
        True -> {
          let now = get_timestamp()
          let started_match =
            GameMatch(..state.match, phase: Active, started_at: now)

          // Initialize team states
          let team1_state =
            match_logic.init_team_state(state.match.match_id, 1, now)
          let team2_state =
            match_logic.init_team_state(state.match.match_id, 2, now)
          let new_team_states =
            dict.from_list([
              #(1, team1_state),
              #(2, team2_state),
            ])

          // Spawn heroes for both teams using provided hero slugs
          let team1_heroes =
            spawn_heroes_for_team(
              state.match.match_id,
              1,
              hero_slugs_team1,
              now,
            )
          let team2_heroes =
            spawn_heroes_for_team(
              state.match.match_id,
              2,
              hero_slugs_team2,
              now,
            )
          let all_heroes =
            dict.from_list(list.append(team1_heroes, team2_heroes))

          // Roll initial hands for both teams
          let hand1 = roll_hand_for_team(state.match.match_id, 1)
          let hand2 = roll_hand_for_team(state.match.match_id, 2)
          let all_hands = list.append(hand1, hand2)

          let new_state =
            MatchActorState(
              match: started_match,
              players: state.players,
              team_states: new_team_states,
              heroes: all_heroes,
              hand_slots: all_hands,
              statuses: dict.new(),
              casts: dict.new(),
              db_conn: state.db_conn,
              match_saved: False,
            )

          process.send(reply_to, Ok(Nil))
          actor.continue(new_state)
        }
        False -> {
          process.send(reply_to, Error("Need 2 players to start"))
          actor.continue(state)
        }
      }
    }
    _ -> {
      process.send(reply_to, Error("Match already started"))
      actor.continue(state)
    }
  }
}
