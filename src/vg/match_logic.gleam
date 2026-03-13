// Match logic - game rules and calculations

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import vg/content
import vg/types.{
  type ActionDef, type Element, type HeroDef, type MatchCast, type MatchHero,
  type MatchStatus, type MatchTeamState, type TargetRule, AllyAuto, AllySingle,
  AnyAuto, AnySingle, Cleanse, Damage, DamageAndStatus, Earth, EnemyAuto,
  EnemySingle, Fire, Heal, Ice, Light, MatchCast, MatchHero, MatchStatus,
  MatchTeamState, NoTarget, NoWinner, Self, Shadow, Shield, ShieldBuff, Status,
  Team1, Team2, Wind,
}

// ============================================================================
// Game constants
// ============================================================================

pub const max_energy = 10

pub const start_energy = 10

pub const energy_regen_per_second = 1

pub const reroll_cost = 2

pub const hand_size = 5

pub const heroes_per_team = 3

// ============================================================================
// Damage calculation
// ============================================================================

pub fn calculate_damage(
  action: ActionDef,
  _caster: MatchHero,
  _target: MatchHero,
  caster_hero_def: HeroDef,
  target_hero_def: HeroDef,
) -> Int {
  // Base power from action
  let base_power = int.to_float(action.base_power)

  // Attack multiplier
  let attack_multiplier = int.to_float(caster_hero_def.attack) /. 100.0

  // Get affinity values
  let caster_affinity =
    get_affinity_for_element(caster_hero_def, action.element)
  let target_affinity =
    get_affinity_for_element(target_hero_def, action.element)

  // Affinity calculations
  let outgoing_affinity = 1.0 +. { int.to_float(caster_affinity) /. 100.0 }
  let incoming_affinity = 1.0 -. { int.to_float(target_affinity) /. 100.0 }

  // Defense mitigation: 100 / (100 + defense)
  let defense_mitigation =
    100.0 /. { 100.0 +. int.to_float(target_hero_def.defense) }

  // Calculate final damage
  let raw_damage = base_power *. attack_multiplier *. outgoing_affinity
  let final_damage = raw_damage *. defense_mitigation *. incoming_affinity

  // Ensure at least 1 damage
  let damage = float.truncate(final_damage)
  case damage {
    d if d < 1 -> 1
    d -> d
  }
}

fn get_affinity_for_element(hero: HeroDef, element: Element) -> Int {
  case element {
    Fire -> hero.fire_affinity
    Ice -> hero.ice_affinity
    Earth -> hero.earth_affinity
    Wind -> hero.wind_affinity
    Light -> hero.light_affinity
    Shadow -> hero.shadow_affinity
  }
}

// ============================================================================
// Healing calculation
// ============================================================================

pub fn calculate_heal(
  action: ActionDef,
  _caster: MatchHero,
  caster_hero_def: HeroDef,
) -> Int {
  let base_power = int.to_float(action.base_power)
  let attack_multiplier = int.to_float(caster_hero_def.attack) /. 100.0

  // Light affinity bonus for healing
  let affinity_bonus =
    1.0 +. { int.to_float(caster_hero_def.light_affinity) /. 100.0 }

  let raw_heal = base_power *. attack_multiplier *. affinity_bonus
  let heal = float.truncate(raw_heal)

  case heal {
    h if h < 1 -> 1
    h -> h
  }
}

// ============================================================================
// Shield calculation
// ============================================================================

pub fn calculate_shield(
  action: ActionDef,
  _caster: MatchHero,
  caster_hero_def: HeroDef,
) -> Int {
  let base_power = int.to_float(action.base_power)
  let defense_multiplier = int.to_float(caster_hero_def.defense) /. 100.0

  let raw_shield = base_power *. defense_multiplier
  let shield = float.truncate(raw_shield)

  case shield {
    s if s < 1 -> 1
    s -> s
  }
}

// ============================================================================
// Energy management
// ============================================================================

pub fn calculate_energy_regen(elapsed_ms: Int) -> Int {
  let seconds = elapsed_ms / 1000
  seconds * energy_regen_per_second
}

pub fn can_spend_energy(team_state: MatchTeamState, amount: Int) -> Bool {
  team_state.energy >= amount
}

pub fn spend_energy(team_state: MatchTeamState, amount: Int) -> MatchTeamState {
  MatchTeamState(
    ..team_state,
    energy: int.max(0, team_state.energy - amount),
    last_energy_at: team_state.last_energy_at,
  )
}

pub fn regen_energy(team_state: MatchTeamState, now: Int) -> MatchTeamState {
  let elapsed = now - team_state.last_energy_at
  let regen_amount = calculate_energy_regen(elapsed)
  let new_energy =
    int.min(team_state.energy_max, team_state.energy + regen_amount)

  MatchTeamState(..team_state, energy: new_energy, last_energy_at: now)
}

// ============================================================================
// Cast resolution
// ============================================================================

pub fn resolve_cast(
  cast: MatchCast,
  action: ActionDef,
  caster: MatchHero,
  target: MatchHero,
  caster_def: HeroDef,
  target_def: HeroDef,
  now: Int,
) -> #(MatchCast, MatchHero, MatchHero, List(MatchStatus), Int) {
  // Mark cast as resolved
  let resolved_cast = MatchCast(..cast, resolved: True)

  // Apply effects based on action type
  case action.effect_kind {
    Damage -> {
      let damage =
        calculate_damage(action, caster, target, caster_def, target_def)
      let new_target = apply_damage(target, damage)
      #(resolved_cast, caster, new_target, [], damage)
    }
    Heal -> {
      let heal = calculate_heal(action, caster, caster_def)
      let new_target = apply_heal(target, heal)
      #(resolved_cast, caster, new_target, [], heal)
    }
    Shield -> {
      let shield = calculate_shield(action, caster, caster_def)
      let status =
        create_shield_status(
          cast.match_id,
          target.hero_instance_id,
          shield,
          now + 5000,
          now,
        )
      #(resolved_cast, caster, target, [status], shield)
    }
    Status -> {
      let status =
        create_status_from_action(
          action,
          cast.match_id,
          target.hero_instance_id,
          now,
        )
      #(resolved_cast, caster, target, [status], 0)
    }
    DamageAndStatus -> {
      let damage =
        calculate_damage(action, caster, target, caster_def, target_def)
      let new_target = apply_damage(target, damage)
      let status =
        create_status_from_action(
          action,
          cast.match_id,
          target.hero_instance_id,
          now,
        )
      #(resolved_cast, caster, new_target, [status], damage)
    }
    Cleanse -> {
      // Cleanse removes negative statuses
      #(resolved_cast, caster, target, [], 0)
    }
  }
}

fn apply_damage(hero: MatchHero, damage: Int) -> MatchHero {
  let new_hp = int.max(0, hero.hp_current - damage)
  MatchHero(..hero, hp_current: new_hp, alive: new_hp > 0)
}

fn apply_heal(hero: MatchHero, heal: Int) -> MatchHero {
  let new_hp = int.min(hero.hp_max, hero.hp_current + heal)
  MatchHero(..hero, hp_current: new_hp)
}

fn create_shield_status(
  match_id: String,
  hero_instance_id: String,
  value: Int,
  expires_at: Int,
  now: Int,
) -> MatchStatus {
  MatchStatus(
    status_id: generate_id("shield", now),
    match_id: match_id,
    hero_instance_id: hero_instance_id,
    kind: ShieldBuff,
    value: value,
    expires_at: expires_at,
  )
}

fn create_status_from_action(
  action: ActionDef,
  match_id: String,
  hero_instance_id: String,
  now: Int,
) -> MatchStatus {
  let status_kind = case action.status_kind {
    Some(k) -> k
    None -> ShieldBuff
  }

  MatchStatus(
    status_id: generate_id("status", now),
    match_id: match_id,
    hero_instance_id: hero_instance_id,
    kind: status_kind,
    value: action.status_value,
    expires_at: now + action.status_duration_ms,
  )
}

// ============================================================================
// Hand management
// ============================================================================

pub fn roll_hand() -> List(String) {
  let all_actions = content.get_all_action_slugs()
  // Take random 5 actions from the pool
  // For now, just take first 5 for simplicity
  // TODO: Implement proper random selection
  list.take(all_actions, hand_size)
}

pub fn reroll_hand() -> #(List(String), Int) {
  let new_hand = roll_hand()
  #(new_hand, reroll_cost)
}

// ============================================================================
// Win condition checking
// ============================================================================

pub fn check_win_condition(heroes: Dict(String, MatchHero)) -> types.WinnerTeam {
  let team1_alive = count_alive_heroes(heroes, 1)
  let team2_alive = count_alive_heroes(heroes, 2)

  case team1_alive, team2_alive {
    0, _ -> Team2
    _, 0 -> Team1
    _, _ -> NoWinner
  }
}

fn count_alive_heroes(heroes: Dict(String, MatchHero), team: Int) -> Int {
  heroes
  |> dict.values()
  |> list.filter(fn(h) { h.team == team && h.alive })
  |> list.length()
}

// ============================================================================
// ID generation (simple counter-based for now)
// ============================================================================

fn generate_id(prefix: String, timestamp: Int) -> String {
  prefix
  <> "_"
  <> int.to_string(timestamp)
  <> "_"
  <> int.to_string(int.random(10_000))
}

// ============================================================================
// Target validation
// ============================================================================

pub fn is_valid_target(
  target_rule: TargetRule,
  caster_team: Int,
  target_team: Int,
  target_alive: Bool,
) -> Bool {
  case target_rule {
    Self -> caster_team == target_team && target_alive
    AllySingle -> caster_team == target_team && target_alive
    AllyAuto -> caster_team == target_team && target_alive
    EnemySingle -> caster_team != target_team && target_alive
    EnemyAuto -> caster_team != target_team && target_alive
    AnySingle -> target_alive
    AnyAuto -> target_alive
    NoTarget -> True
  }
}

// ============================================================================
// Hero spawning
// ============================================================================

pub fn spawn_hero(
  match_id: String,
  team: Int,
  slot_index: Int,
  hero_slug: String,
  now: Int,
) -> Result(MatchHero, Nil) {
  case content.get_hero_def(hero_slug) {
    Ok(hero_def) -> {
      Ok(MatchHero(
        hero_instance_id: generate_id("hero", now),
        match_id: match_id,
        team: team,
        slot_index: slot_index,
        hero_slug: hero_slug,
        hp_current: hero_def.max_hp,
        hp_max: hero_def.max_hp,
        alive: True,
        busy_until: 0,
      ))
    }
    Error(_) -> Error(Nil)
  }
}

// ============================================================================
// Team state initialization
// ============================================================================

pub fn init_team_state(match_id: String, team: Int, now: Int) -> MatchTeamState {
  MatchTeamState(
    match_id: match_id,
    team: team,
    energy: start_energy,
    energy_max: max_energy,
    last_energy_at: now,
    selected_caster_slot: 1,
  )
}
