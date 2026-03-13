// Core data types for Vanguard's Gambit game server

import gleam/dict.{type Dict}
import gleam/option.{type Option}

// ============================================================================
// Element types
// ============================================================================

pub type Element {
  Fire
  Ice
  Earth
  Wind
  Light
  Shadow
}

pub fn element_to_string(element: Element) -> String {
  case element {
    Fire -> "fire"
    Ice -> "ice"
    Earth -> "earth"
    Wind -> "wind"
    Light -> "light"
    Shadow -> "shadow"
  }
}

pub fn element_from_string(s: String) -> Result(Element, Nil) {
  case s {
    "fire" -> Ok(Fire)
    "ice" -> Ok(Ice)
    "earth" -> Ok(Earth)
    "wind" -> Ok(Wind)
    "light" -> Ok(Light)
    "shadow" -> Ok(Shadow)
    _ -> Error(Nil)
  }
}

// ============================================================================
// Target rules
// ============================================================================

pub type TargetRule {
  AllySingle
  EnemySingle
  Self
  AnySingle
  AllyAuto
  EnemyAuto
  AnyAuto
  NoTarget
}

pub fn target_rule_to_string(rule: TargetRule) -> String {
  case rule {
    AllySingle -> "ally_single"
    EnemySingle -> "enemy_single"
    Self -> "self"
    AnySingle -> "any_single"
    AllyAuto -> "ally_auto"
    EnemyAuto -> "enemy_auto"
    AnyAuto -> "any_auto"
    NoTarget -> "no_target"
  }
}

pub fn target_rule_from_string(s: String) -> Result(TargetRule, Nil) {
  case s {
    "ally_single" -> Ok(AllySingle)
    "enemy_single" -> Ok(EnemySingle)
    "self" -> Ok(Self)
    "any_single" -> Ok(AnySingle)
    "ally_auto" -> Ok(AllyAuto)
    "enemy_auto" -> Ok(EnemyAuto)
    "any_auto" -> Ok(AnyAuto)
    "no_target" -> Ok(NoTarget)
    _ -> Error(Nil)
  }
}

// ============================================================================
// Effect kinds
// ============================================================================

pub type EffectKind {
  Damage
  Heal
  Shield
  Status
  DamageAndStatus
  Cleanse
}

pub fn effect_kind_to_string(kind: EffectKind) -> String {
  case kind {
    Damage -> "damage"
    Heal -> "heal"
    Shield -> "shield"
    Status -> "status"
    DamageAndStatus -> "damage_and_status"
    Cleanse -> "cleanse"
  }
}

pub fn effect_kind_from_string(s: String) -> Result(EffectKind, Nil) {
  case s {
    "damage" -> Ok(Damage)
    "heal" -> Ok(Heal)
    "shield" -> Ok(Shield)
    "status" -> Ok(Status)
    "damage_and_status" -> Ok(DamageAndStatus)
    "cleanse" -> Ok(Cleanse)
    _ -> Error(Nil)
  }
}

// ============================================================================
// Status kinds
// ============================================================================

pub type StatusKind {
  Stun
  ShieldBuff
  AttackBuff
  DefenseBuff
  Dot // Damage over time
  Hot // Heal over time
}

pub fn status_kind_to_string(kind: StatusKind) -> String {
  case kind {
    Stun -> "stun"
    ShieldBuff -> "shield"
    AttackBuff -> "attack_buff"
    DefenseBuff -> "defense_buff"
    Dot -> "dot"
    Hot -> "hot"
  }
}

pub fn status_kind_from_string(s: String) -> Result(StatusKind, Nil) {
  case s {
    "stun" -> Ok(Stun)
    "shield" -> Ok(ShieldBuff)
    "attack_buff" -> Ok(AttackBuff)
    "defense_buff" -> Ok(DefenseBuff)
    "dot" -> Ok(Dot)
    "hot" -> Ok(Hot)
    _ -> Error(Nil)
  }
}

// ============================================================================
// Static content definitions
// ============================================================================

pub type HeroDef {
  HeroDef(
    slug: String,
    display_name: String,
    max_hp: Int,
    attack: Int,
    defense: Int,
    fire_affinity: Int,
    ice_affinity: Int,
    earth_affinity: Int,
    wind_affinity: Int,
    light_affinity: Int,
    shadow_affinity: Int,
  )
}

pub type ActionDef {
  ActionDef(
    slug: String,
    display_name: String,
    element: Element,
    target_rule: TargetRule,
    energy_cost: Int,
    casting_time_ms: Int,
    effect_kind: EffectKind,
    base_power: Int,
    status_kind: Option(StatusKind),
    status_duration_ms: Int,
    status_value: Int,
  )
}

// ============================================================================
// Match phases
// ============================================================================

pub type MatchPhase {
  Waiting
  Active
  Finished
}

pub fn match_phase_to_int(phase: MatchPhase) -> Int {
  case phase {
    Waiting -> 1
    Active -> 2
    Finished -> 3
  }
}

pub fn match_phase_from_int(n: Int) -> Result(MatchPhase, Nil) {
  case n {
    1 -> Ok(Waiting)
    2 -> Ok(Active)
    3 -> Ok(Finished)
    _ -> Error(Nil)
  }
}

// ============================================================================
// Winner team
// ============================================================================

pub type WinnerTeam {
  NoWinner
  Team1
  Team2
}

pub fn winner_team_to_int(winner: WinnerTeam) -> Int {
  case winner {
    NoWinner -> 0
    Team1 -> 1
    Team2 -> 2
  }
}

pub fn winner_team_from_int(n: Int) -> Result(WinnerTeam, Nil) {
  case n {
    0 -> Ok(NoWinner)
    1 -> Ok(Team1)
    2 -> Ok(Team2)
    _ -> Error(Nil)
  }
}

// ============================================================================
// Runtime match entities
// ============================================================================

pub type PlayerId = String
pub type MatchId = String
pub type HeroInstanceId = String
pub type CastId = String
pub type StatusId = String

pub type PlayerProfile {
  PlayerProfile(
    id: PlayerId,
    display_name: String,
    created_at: Int,
    updated_at: Int,
  )
}

pub type MatchPlayer {
  MatchPlayer(
    player_id: PlayerId,
    match_id: MatchId,
    team: Int, // 1 or 2
  )
}

pub type MatchTeamState {
  MatchTeamState(
    match_id: MatchId,
    team: Int,
    energy: Int,
    energy_max: Int,
    last_energy_at: Int,
    selected_caster_slot: Int, // 1, 2, or 3
  )
}

pub type MatchHero {
  MatchHero(
    hero_instance_id: HeroInstanceId,
    match_id: MatchId,
    team: Int,
    slot_index: Int, // 1, 2, or 3
    hero_slug: String,
    hp_current: Int,
    hp_max: Int,
    alive: Bool,
    busy_until: Int, // timestamp when no longer busy
  )
}

pub type MatchHandSlot {
  MatchHandSlot(
    match_id: MatchId,
    team: Int,
    slot_index: Int, // 1-5
    action_slug: String,
  )
}

pub type MatchStatus {
  MatchStatus(
    status_id: StatusId,
    match_id: MatchId,
    hero_instance_id: HeroInstanceId,
    kind: StatusKind,
    value: Int,
    expires_at: Int,
  )
}

pub type MatchCast {
  MatchCast(
    cast_id: CastId,
    match_id: MatchId,
    team: Int,
    caster_hero_instance_id: HeroInstanceId,
    target_hero_instance_id: HeroInstanceId,
    action_slug: String,
    started_at: Int,
    resolves_at: Int,
    resolved: Bool,
  )
}

pub type GameMatch {
  GameMatch(
    match_id: MatchId,
    phase: MatchPhase,
    created_at: Int,
    started_at: Int,
    winner: WinnerTeam,
  )
}

// ============================================================================
// Matchmaking
// ============================================================================

pub type MatchmakingEntry {
  MatchmakingEntry(
    player_id: PlayerId,
    hero_slug_1: String,
    hero_slug_2: String,
    hero_slug_3: String,
    queued_at: Int,
  )
}

// ============================================================================
// Game state container
// ============================================================================

pub type MatchState {
  MatchState(
    match: GameMatch,
    players: Dict(PlayerId, MatchPlayer),
    team_states: Dict(Int, MatchTeamState), // key is team number (1 or 2)
    heroes: Dict(HeroInstanceId, MatchHero),
    hand_slots: List(MatchHandSlot),
    statuses: Dict(StatusId, MatchStatus),
    casts: Dict(CastId, MatchCast),
  )
}

// Using gleam/option.Option instead of custom Option type
