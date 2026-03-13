// JSON encoding for game state using gleam/json
import gleam/json
import vg/content
import vg/db
import vg/types.{
  type GameMatch, type MatchCast, type MatchHandSlot, type MatchHero,
  type MatchPlayer, type MatchStatus, type MatchTeamState, type PlayerProfile,
  Active, AllyAuto, AllySingle, AnyAuto, AnySingle, AttackBuff, DefenseBuff, Dot,
  EnemyAuto, EnemySingle, Finished, Hot, NoTarget, NoWinner, Self, ShieldBuff,
  Stun, Team1, Team2, Waiting, target_rule_to_string,
}

// ============================================================================
// Client messages (parsed from JSON)
// ============================================================================

pub type ClientMessage {
  UpsertProfile(display_name: String)
  QueueMatchmaking(
    hero_slug_1: String,
    hero_slug_2: String,
    hero_slug_3: String,
  )
  CastAction(match_id: String, caster_slot: Int, hand_slot_index: Int)
  RerollHand(match_id: String)
  LeaveMatch(match_id: String)
  GetMatchHistory(limit: Int, offset: Int)
  GetLeaderboard(limit: Int)
  GetPlayerStats(target_player_id: String)
}

// ============================================================================
// Server messages (encoded to JSON)
// ============================================================================

pub type ServerMessage {
  Connected(player_id: String)
  ProfileUpdated(profile: PlayerProfile)
  MatchmakingQueued
  MatchmakingLeft
  MatchFound(match_id: String, team: Int)
  StateUpdate(
    match: GameMatch,
    players: List(MatchPlayer),
    team_states: List(MatchTeamState),
    heroes: List(MatchHero),
    hand: List(MatchHandSlot),
    statuses: List(MatchStatus),
    casts: List(MatchCast),
  )
  Event(event_type: String, data: json.Json)
  Error(code: String, message: String)
  MatchHistory(matches: List(db.MatchResult))
  Leaderboard(entries: List(db.LeaderboardEntry))
  PlayerStatsResponse(stats: db.PlayerStats)
}

// ============================================================================
// JSON encoding
// ============================================================================

pub fn encode_server_message(msg: ServerMessage) -> String {
  let json_obj = case msg {
    Connected(player_id) ->
      json.object([
        #("type", json.string("connected")),
        #("player_id", json.string(player_id)),
      ])
    ProfileUpdated(profile) ->
      json.object([
        #("type", json.string("profile_updated")),
        #("profile", encode_profile(profile)),
      ])
    MatchmakingQueued ->
      json.object([
        #("type", json.string("matchmaking_queued")),
      ])
    MatchmakingLeft ->
      json.object([
        #("type", json.string("matchmaking_left")),
      ])
    MatchFound(match_id, team) ->
      json.object([
        #("type", json.string("match_found")),
        #("match_id", json.string(match_id)),
        #("team", json.int(team)),
      ])
    StateUpdate(match, players, team_states, heroes, hand, statuses, casts) ->
      json.object([
        #("type", json.string("state_update")),
        #("match", encode_match(match)),
        #("players", json.array(players, encode_match_player)),
        #("team_states", json.array(team_states, encode_team_state)),
        #("heroes", json.array(heroes, encode_match_hero)),
        #("hand", json.array(hand, encode_hand_slot)),
        #("statuses", json.array(statuses, encode_status)),
        #("casts", json.array(casts, encode_cast)),
      ])
    Event(event_type, data) ->
      json.object([
        #("type", json.string("event")),
        #("event_type", json.string(event_type)),
        #("data", data),
      ])
    Error(code, message) ->
      json.object([
        #("type", json.string("error")),
        #("code", json.string(code)),
        #("message", json.string(message)),
      ])
    MatchHistory(matches) ->
      json.object([
        #("type", json.string("match_history")),
        #("matches", json.array(matches, encode_match_result)),
      ])
    Leaderboard(entries) ->
      json.object([
        #("type", json.string("leaderboard")),
        #("entries", json.array(entries, encode_leaderboard_entry)),
      ])
    PlayerStatsResponse(stats) ->
      json.object([
        #("type", json.string("player_stats")),
        #("stats", encode_player_stats(stats)),
      ])
  }
  json.to_string(json_obj)
}

fn encode_match_result(r: db.MatchResult) -> json.Json {
  json.object([
    #("match_id", json.string(r.match_id)),
    #("player1_id", json.string(r.player1_id)),
    #("player2_id", json.string(r.player2_id)),
    #("winner", json.int(r.winner)),
    #("started_at", json.int(r.started_at)),
    #("ended_at", json.int(r.ended_at)),
    #("duration_ms", json.int(r.duration_ms)),
  ])
}

fn encode_leaderboard_entry(e: db.LeaderboardEntry) -> json.Json {
  json.object([
    #("rank", json.int(e.rank)),
    #("player_id", json.string(e.player_id)),
    #("display_name", json.string(e.display_name)),
    #("matches_won", json.int(e.matches_won)),
    #("rating", json.int(e.rating)),
  ])
}

fn encode_player_stats(s: db.PlayerStats) -> json.Json {
  json.object([
    #("player_id", json.string(s.player_id)),
    #("display_name", json.string(s.display_name)),
    #("matches_played", json.int(s.matches_played)),
    #("matches_won", json.int(s.matches_won)),
    #("matches_lost", json.int(s.matches_lost)),
    #("rating", json.int(s.rating)),
    #("created_at", json.int(s.created_at)),
    #("updated_at", json.int(s.updated_at)),
  ])
}

fn encode_profile(p: PlayerProfile) -> json.Json {
  json.object([
    #("id", json.string(p.id)),
    #("display_name", json.string(p.display_name)),
    #("created_at", json.int(p.created_at)),
    #("updated_at", json.int(p.updated_at)),
  ])
}

fn encode_match(m: GameMatch) -> json.Json {
  json.object([
    #("match_id", json.string(m.match_id)),
    #("phase", json.int(match_phase_to_int(m.phase))),
    #("created_at", json.int(m.created_at)),
    #("started_at", json.int(m.started_at)),
    #("winner", json.int(winner_team_to_int(m.winner))),
  ])
}

fn encode_match_player(p: MatchPlayer) -> json.Json {
  json.object([
    #("player_id", json.string(p.player_id)),
    #("match_id", json.string(p.match_id)),
    #("team", json.int(p.team)),
  ])
}

fn encode_team_state(s: MatchTeamState) -> json.Json {
  json.object([
    #("match_id", json.string(s.match_id)),
    #("team", json.int(s.team)),
    #("energy", json.int(s.energy)),
    #("energy_max", json.int(s.energy_max)),
    #("last_energy_at", json.int(s.last_energy_at)),
    #("selected_caster_slot", json.int(s.selected_caster_slot)),
  ])
}

fn encode_match_hero(h: MatchHero) -> json.Json {
  json.object([
    #("hero_instance_id", json.string(h.hero_instance_id)),
    #("match_id", json.string(h.match_id)),
    #("team", json.int(h.team)),
    #("slot_index", json.int(h.slot_index)),
    #("hero_slug", json.string(h.hero_slug)),
    #("hp_current", json.int(h.hp_current)),
    #("hp_max", json.int(h.hp_max)),
    #("alive", json.bool(h.alive)),
    #("busy_until", json.int(h.busy_until)),
  ])
}

fn encode_hand_slot(s: MatchHandSlot) -> json.Json {
  case content.get_action_def(s.action_slug) {
    Ok(action) ->
      json.object([
        #("match_id", json.string(s.match_id)),
        #("team", json.int(s.team)),
        #("slot_index", json.int(s.slot_index)),
        #("action_slug", json.string(s.action_slug)),
        #("action_name", json.string(action.display_name)),
        #("energy_cost", json.int(action.energy_cost)),
        #("target_rule", json.string(target_rule_to_string(action.target_rule))),
        #("targeting", encode_targeting_rule(action.target_rule)),
      ])
    _ ->
      json.object([
        #("match_id", json.string(s.match_id)),
        #("team", json.int(s.team)),
        #("slot_index", json.int(s.slot_index)),
        #("action_slug", json.string(s.action_slug)),
      ])
  }
}

fn encode_targeting_rule(rule) -> json.Json {
  let #(side, scope, selection, allow_self) = case rule {
    AllySingle -> #("ally", "single", "manual", True)
    EnemySingle -> #("enemy", "single", "manual", False)
    Self -> #("ally", "single", "manual", True)
    AnySingle -> #("any", "single", "manual", True)
    AllyAuto -> #("ally", "single", "auto", True)
    EnemyAuto -> #("enemy", "single", "auto", False)
    AnyAuto -> #("any", "single", "auto", True)
    NoTarget -> #("ally", "none", "auto", True)
  }
  json.object([
    #("side", json.string(side)),
    #("scope", json.string(scope)),
    #("selection", json.string(selection)),
    #("allow_self", json.bool(allow_self)),
    #("allow_dead", json.bool(False)),
  ])
}

fn encode_status(s: MatchStatus) -> json.Json {
  json.object([
    #("status_id", json.string(s.status_id)),
    #("match_id", json.string(s.match_id)),
    #("hero_instance_id", json.string(s.hero_instance_id)),
    #("kind", json.string(status_kind_to_string(s.kind))),
    #("value", json.int(s.value)),
    #("expires_at", json.int(s.expires_at)),
  ])
}

fn encode_cast(c: MatchCast) -> json.Json {
  json.object([
    #("cast_id", json.string(c.cast_id)),
    #("match_id", json.string(c.match_id)),
    #("team", json.int(c.team)),
    #("caster_hero_instance_id", json.string(c.caster_hero_instance_id)),
    #("target_hero_instance_id", json.string(c.target_hero_instance_id)),
    #("action_slug", json.string(c.action_slug)),
    #("started_at", json.int(c.started_at)),
    #("resolves_at", json.int(c.resolves_at)),
    #("resolved", json.bool(c.resolved)),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn match_phase_to_int(phase: types.MatchPhase) -> Int {
  case phase {
    Waiting -> 1
    Active -> 2
    Finished -> 3
  }
}

fn winner_team_to_int(winner: types.WinnerTeam) -> Int {
  case winner {
    NoWinner -> 0
    Team1 -> 1
    Team2 -> 2
  }
}

fn status_kind_to_string(kind: types.StatusKind) -> String {
  case kind {
    Stun -> "stun"
    ShieldBuff -> "shield"
    AttackBuff -> "attack_buff"
    DefenseBuff -> "defense_buff"
    Dot -> "dot"
    Hot -> "hot"
  }
}
