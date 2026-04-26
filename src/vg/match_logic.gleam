// Match logic - game rules and calculations

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import vg/actions
import vg/content
import vg/types.{
  type AbilityDef, type AbilityEffect, type ActionDef, type Element,
  type HeroDef, type MatchCast, type MatchHero, type MatchStatus,
  type MatchTeamState, type TargetRule, AllyAuto, AllySingle, AnyAuto, AnySingle,
  AttackBuff, Cleanse, Damage, DamageAndStatus, DefenseBuff, Dot, Earth,
  EffApplyStatus, EffDamage, EffHeal, EnemyAuto, EnemySingle, Fire, Heal, Hot,
  Ice, Light, MatchCast, MatchHero, MatchStatus, MatchTeamState, NoTarget,
  NoWinner, Self, Shadow, Shield, ShieldBuff, Status, Stun, Team1, Team2,
  TgtAllAllies, TgtAllEnemies, TgtAttacker, TgtLowestHpAlly, TgtPrimary,
  TgtRandomEnemy, TgtSelf, Wind,
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

// Tick interval for DoT/Hot effects (ms)
pub const dot_tick_interval_ms = 1000

// Hero mana defaults
pub const hero_mana_max = 10

pub const hero_mana_regen_per_second = 1

// ============================================================================
// Active status helpers
// ============================================================================

// Returns all active (non-expired) statuses for a hero
fn active_statuses_for(
  statuses: Dict(String, MatchStatus),
  hero_instance_id: String,
  now: Int,
) -> List(MatchStatus) {
  statuses
  |> dict.values()
  |> list.filter(fn(s) { s.hero_instance_id == hero_instance_id && s.expires_at > now })
}

// Sum of all status_kind values for a hero (e.g. total attack buff from multiple Rally Cry)
fn sum_status_by_kind(
  statuses: Dict(String, MatchStatus),
  hero_instance_id: String,
  kind: types.StatusKind,
  now: Int,
) -> Int {
  active_statuses_for(statuses, hero_instance_id, now)
  |> list.filter(fn(s) { s.kind == kind })
  |> list.fold(0, fn(acc, s) { acc + s.value })
}

// Get all active shield buffs for a hero (for absorption)
fn active_shields(
  statuses: Dict(String, MatchStatus),
  hero_instance_id: String,
  now: Int,
) -> List(MatchStatus) {
  active_statuses_for(statuses, hero_instance_id, now)
  |> list.filter(fn(s) { s.kind == ShieldBuff })
}

// Check if hero has a stun status active
pub fn is_stunned(
  statuses: Dict(String, MatchStatus),
  hero_instance_id: String,
  now: Int,
) -> Bool {
  active_statuses_for(statuses, hero_instance_id, now)
  |> list.any(fn(s) { s.kind == Stun })
}

// Apply one DoT/Hot tick for all active statuses.
// Returns updated heroes dict (HP changed) and unchanged statuses dict.
// Called when dot_tick_interval_ms has elapsed since the last tick.
pub fn apply_dot_hot_ticks(
  heroes: Dict(String, MatchHero),
  statuses: Dict(String, MatchStatus),
  now: Int,
) -> Dict(String, MatchHero) {
  let active =
    statuses
    |> dict.values()
    |> list.filter(fn(s) { s.expires_at > now })

  list.fold(active, heroes, fn(current_heroes, status) {
    case status.kind {
      Dot ->
        case dict.get(current_heroes, status.hero_instance_id) {
          Ok(hero) if hero.alive -> {
            let new_hero = apply_damage(hero, status.value)
            dict.insert(current_heroes, hero.hero_instance_id, new_hero)
          }
          _ -> current_heroes
        }
      Hot ->
        case dict.get(current_heroes, status.hero_instance_id) {
          Ok(hero) if hero.alive -> {
            let new_hero = apply_heal(hero, status.value)
            dict.insert(current_heroes, hero.hero_instance_id, new_hero)
          }
          _ -> current_heroes
        }
      _ -> current_heroes
    }
  })
}

// ============================================================================
// Damage calculation
// ============================================================================

pub fn calculate_damage(
  action: ActionDef,
  caster: MatchHero,
  target: MatchHero,
  caster_hero_def: HeroDef,
  target_hero_def: HeroDef,
) -> Int {
  calculate_damage_with_buffs(action, caster, target, caster_hero_def, target_hero_def, dict.new(), dict.new())
}

pub fn calculate_damage_with_buffs(
  action: ActionDef,
  caster: MatchHero,
  target: MatchHero,
  caster_hero_def: HeroDef,
  target_hero_def: HeroDef,
  caster_statuses: Dict(String, MatchStatus),
  target_statuses: Dict(String, MatchStatus),
) -> Int {
  // Base power from action
  let base_power = int.to_float(action.base_power)

  // Attack multiplier
  let attack_multiplier = int.to_float(caster_hero_def.attack) /. 100.0

  // Active status buffs/debuffs
  let attack_buff = sum_status_by_kind(caster_statuses, caster.hero_instance_id, AttackBuff, 0)
  let defense_debuff = sum_status_by_kind(target_statuses, target.hero_instance_id, DefenseBuff, 0)

  // Status buff multiplier: each point of buff = +1% bonus
  let caster_buff_mult = 1.0 +. { int.to_float(attack_buff) /. 100.0 }
  let target_debuff_mult = 1.0 +. { int.to_float(defense_debuff) /. 100.0 }

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
  let final_damage = raw_damage *. defense_mitigation *. incoming_affinity *. caster_buff_mult *. target_debuff_mult

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
  caster: MatchHero,
  caster_hero_def: HeroDef,
) -> Int {
  calculate_heal_with_buffs(action, caster, caster_hero_def, dict.new())
}

pub fn calculate_heal_with_buffs(
  action: ActionDef,
  caster: MatchHero,
  caster_hero_def: HeroDef,
  caster_statuses: Dict(String, MatchStatus),
) -> Int {
  let base_power = int.to_float(action.base_power)
  let attack_multiplier = int.to_float(caster_hero_def.attack) /. 100.0

  // Light affinity bonus for healing
  let affinity_bonus =
    1.0 +. { int.to_float(caster_hero_def.light_affinity) /. 100.0 }

  // Hot (lifesteal) bonus: each point of Hot = +1% healing
  let hot_value = sum_status_by_kind(caster_statuses, caster.hero_instance_id, Hot, 0)
  let hot_mult = 1.0 +. { int.to_float(hot_value) /. 100.0 }

  let raw_heal = base_power *. attack_multiplier *. affinity_bonus *. hot_mult
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
  case regen_amount > 0 {
    True -> {
      let new_energy =
        int.min(team_state.energy_max, team_state.energy + regen_amount)
      let consumed_ms = regen_amount * 1000 / energy_regen_per_second
      MatchTeamState(
        ..team_state,
        energy: new_energy,
        last_energy_at: team_state.last_energy_at + consumed_ms,
      )
    }
    False -> team_state
  }
}

// ============================================================================
// Cast resolution
// ============================================================================

// Result of resolving a cast: (resolved_cast, updated_caster, updated_target, kept_statuses, removed_status_ids, effect_value)
pub type CastResult {
  CastResult(
    cast: MatchCast,
    caster: MatchHero,
    target: MatchHero,
    kept_statuses: List(MatchStatus),
    removed_ids: List(String),
    value: Int,
  )
}

pub fn resolve_cast(
  cast: MatchCast,
  action: ActionDef,
  caster: MatchHero,
  target: MatchHero,
  caster_def: HeroDef,
  target_def: HeroDef,
  now: Int,
  statuses: Dict(String, MatchStatus),
) -> CastResult {
  let resolved_cast = MatchCast(..cast, resolved: True)

  case action.effect_kind {
    Damage -> {
      let damage =
        calculate_damage_with_buffs(action, caster, target, caster_def, target_def, statuses, statuses)
      let #(new_target, updated_statuses, removed_ids) =
        apply_damage_with_shields(target, damage, statuses, now)
      let kept =
        dict.values(updated_statuses)
        |> list.filter(fn(s) { s.expires_at > now })
      CastResult(resolved_cast, caster, new_target, kept, removed_ids, damage)
    }
    Heal -> {
      let heal =
        calculate_heal_with_buffs(action, caster, caster_def, statuses)
      let new_caster = apply_heal(caster, heal)
      CastResult(resolved_cast, new_caster, target, [], [], heal)
    }
    Shield -> {
      let shield = calculate_shield(action, caster, caster_def)
      let status =
        create_shield_status(
          action,
          cast.match_id,
          target.hero_instance_id,
          shield,
          now,
        )
      let #(_, kept_statuses, removed_ids) = upsert_and_get_diff(statuses, status, now)
      CastResult(resolved_cast, caster, target, kept_statuses, removed_ids, shield)
    }
    Status -> {
      let status =
        create_status_from_action(
          action,
          cast.match_id,
          target.hero_instance_id,
          now,
        )
      let #(_, kept_statuses, removed_ids) = upsert_and_get_diff(statuses, status, now)
      CastResult(resolved_cast, caster, target, kept_statuses, removed_ids, 0)
    }
    DamageAndStatus -> {
      let damage =
        calculate_damage_with_buffs(action, caster, target, caster_def, target_def, statuses, statuses)
      let status =
        create_status_from_action(
          action,
          cast.match_id,
          target.hero_instance_id,
          now,
        )
      let #(target_after_shield, statuses_after_shield, shield_removed) =
        apply_damage_with_shields(target, damage, statuses, now)
      let #(_, final_kept, final_removed) =
        upsert_and_get_diff_from_dict(statuses_after_shield, status, now, shield_removed)
      CastResult(resolved_cast, caster, target_after_shield, final_kept, final_removed, damage)
    }
    Cleanse -> {
      let #(new_statuses, removed) =
        cleanse_negative_statuses(target.hero_instance_id, statuses, now)
      let removed_ids = list.map(removed, fn(s) { s.status_id })
      let kept =
        dict.values(new_statuses)
        |> list.filter(fn(s) { s.expires_at > now })
      CastResult(resolved_cast, caster, target, kept, removed_ids, 0)
    }
  }
}

pub fn apply_damage(hero: MatchHero, damage: Int) -> MatchHero {
  let new_hp = int.max(0, hero.hp_current - damage)
  MatchHero(..hero, hp_current: new_hp, alive: new_hp > 0)
}

// Apply damage to a target, absorbing from active shields first.
// Returns (updated_target, updated_statuses_dict, removed_shield_ids).
fn apply_damage_with_shields(
  target: MatchHero,
  damage: Int,
  statuses: Dict(String, MatchStatus),
  now: Int,
) -> #(MatchHero, Dict(String, MatchStatus), List(String)) {
  let shields = active_shields(statuses, target.hero_instance_id, now)
  case list.is_empty(shields) {
    True -> #(apply_damage(target, damage), statuses, [])
    False -> {
      // Sort shields by value descending (largest first)
      let sorted_shields =
        list.sort(shields, fn(a, b) { int.compare(b.value, a.value) })
      let shield_ids = list.map(sorted_shields, fn(s) { s.status_id })

      // Fold through shields, absorbing damage until none remains
      let #(remaining_damage, final_statuses, removed_ids) =
        list.fold(
          shield_ids,
          #(damage, statuses, []),
          fn(acc, shield_id) {
            let #(dmg_left, current_statuses, removed) = acc
            case dmg_left <= 0 {
              True -> acc
              False ->
                case dict.get(current_statuses, shield_id) {
                  Ok(shield) if shield.value > 0 -> {
                    let absorbed = int.min(dmg_left, shield.value)
                    let new_value = shield.value - absorbed
                    let new_dmg_left = int.max(0, dmg_left - absorbed)
                    case new_value <= 0 {
                      True -> {
                        // Shield fully consumed — remove it
                        #(
                          new_dmg_left,
                          dict.delete(current_statuses, shield_id),
                          [shield_id, ..removed],
                        )
                      }
                      False -> {
                        // Shield partially consumed — update value
                        let updated = MatchStatus(..shield, value: new_value)
                        #(
                          new_dmg_left,
                          dict.insert(current_statuses, shield_id, updated),
                          removed,
                        )
                      }
                    }
                  }
                  _ -> acc
                }
            }
          },
        )

      let new_target = case remaining_damage > 0 {
        True -> apply_damage(target, remaining_damage)
        False -> target
      }
      #(new_target, final_statuses, removed_ids)
    }
  }
}

// Upsert a new status into `statuses`, replacing any existing status of the
// same kind on the same hero. Returns (updated_dict, kept_active, removed_ids)
// where kept_active is all still-active statuses and removed_ids is IDs removed.
fn upsert_and_get_diff(
  statuses: Dict(String, MatchStatus),
  new_status: MatchStatus,
  now: Int,
) -> #(Dict(String, MatchStatus), List(MatchStatus), List(String)) {
  upsert_and_get_diff_from_dict(statuses, new_status, now, [])
}

// Same as upsert_and_get_diff but merges already_removed into the returned removed_ids.
fn upsert_and_get_diff_from_dict(
  statuses: Dict(String, MatchStatus),
  new_status: MatchStatus,
  now: Int,
  already_removed: List(String),
) -> #(Dict(String, MatchStatus), List(MatchStatus), List(String)) {
  let existing =
    dict.values(statuses)
    |> list.filter(fn(s) {
      s.hero_instance_id == new_status.hero_instance_id
      && s.kind == new_status.kind
      && s.expires_at > now
    })

  let #(new_dict, extra_removed) = case existing {
    [] -> {
      // Insert fresh
      #(dict.insert(statuses, new_status.status_id, new_status), [])
    }
    [old, ..] -> {
      // Replace old with new (refresh duration) using old's key so clients
      // don't need to remove the old entry separately
      let d =
        statuses
        |> dict.delete(old.status_id)
        |> dict.insert(new_status.status_id, new_status)
      #(d, [old.status_id])
    }
  }

  let all_removed = list.append(already_removed, extra_removed)
  let kept =
    dict.values(new_dict)
    |> list.filter(fn(s) { s.expires_at > now })
  #(new_dict, kept, all_removed)
}

// Remove negative statuses from a hero (for Cleanse).
// Negative = AttackBuff/DefenseBuff with negative value, or DoT/Hot.
// Returns (updated_dict, removed_statuses).
fn cleanse_negative_statuses(
  hero_instance_id: String,
  statuses: Dict(String, MatchStatus),
  now: Int,
) -> #(Dict(String, MatchStatus), List(MatchStatus)) {
  let active = active_statuses_for(statuses, hero_instance_id, now)
  let negative =
    list.filter(active, fn(s) {
      s.kind == AttackBuff || s.kind == DefenseBuff || s.kind == Dot || s.kind == Hot
    })
  // Remove them from dict
  let new_statuses =
    list.fold(negative, statuses, fn(acc, s) { dict.delete(acc, s.status_id) })
  #(new_statuses, negative)
}

pub fn apply_heal(hero: MatchHero, heal: Int) -> MatchHero {
  let new_hp = int.min(hero.hp_max, hero.hp_current + heal)
  MatchHero(..hero, hp_current: new_hp)
}

fn create_shield_status(
  action: ActionDef,
  match_id: String,
  hero_instance_id: String,
  value: Int,
  now: Int,
) -> MatchStatus {
  let duration = case action.status_duration_ms {
    0 -> 5000  // fallback to 5s for Shield-kind actions (which have duration_ms=0 in data)
    d -> d
  }
  MatchStatus(
    status_id: generate_id("shield", now),
    match_id: match_id,
    hero_instance_id: hero_instance_id,
    kind: ShieldBuff,
    value: value,
    expires_at: now + duration,
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
  let all_actions = actions.get_all_action_slugs()
  sample_without_replacement(all_actions, hand_size)
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

fn sample_without_replacement(
  items: List(a),
  count: Int,
) -> List(a) {
  case count <= 0 || list.is_empty(items) {
    True -> []
    False -> {
      let index = int.random(list.length(items))
      let #(picked, remaining) = remove_at(items, index)
      [picked, ..sample_without_replacement(remaining, count - 1)]
    }
  }
}

fn remove_at(items: List(a), index: Int) -> #(a, List(a)) {
  case items, index {
    [item, ..rest], 0 -> #(item, rest)
    [item, ..rest], _ -> {
      let #(picked, remaining) = remove_at(rest, index - 1)
      #(picked, [item, ..remaining])
    }
    [], _ -> panic as "remove_at called with invalid index"
  }
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
        mana_current: 0,
        mana_max: hero_mana_max,
        last_mana_at: now,
      ))
    }
    Error(_) -> Error(Nil)
  }
}

// ============================================================================
// Team state initialization
// ============================================================================

// ============================================================================
// Mana management
// ============================================================================

pub fn regen_hero_mana(hero: MatchHero, now: Int) -> MatchHero {
  let elapsed = now - hero.last_mana_at
  let regen_amount = elapsed / 1000 * hero_mana_regen_per_second
  case regen_amount > 0 {
    True -> {
      let new_mana = int.min(hero.mana_max, hero.mana_current + regen_amount)
      let consumed_ms = regen_amount * 1000 / hero_mana_regen_per_second
      MatchHero(
        ..hero,
        mana_current: new_mana,
        last_mana_at: hero.last_mana_at + consumed_ms,
      )
    }
    False -> hero
  }
}

pub fn can_spend_mana(hero: MatchHero, amount: Int) -> Bool {
  hero.mana_current >= amount
}

pub fn spend_mana(hero: MatchHero, amount: Int) -> MatchHero {
  MatchHero(..hero, mana_current: int.max(0, hero.mana_current - amount))
}

// ============================================================================
// Ability target resolution
// ============================================================================

pub fn resolve_ability_targets(
  ability: AbilityDef,
  caster: MatchHero,
  heroes: Dict(String, MatchHero),
) -> List(MatchHero) {
  case ability.target {
    TgtSelf -> [caster]
    TgtAllAllies -> alive_allies(heroes, caster.team)
    TgtAllEnemies -> alive_enemies(heroes, caster.team)
    TgtLowestHpAlly ->
      case lowest_hp_hero(alive_allies(heroes, caster.team)) {
        Ok(h) -> [h]
        Error(_) -> []
      }
    TgtPrimary ->
      case alive_enemies(heroes, caster.team) {
        [first, ..] -> [first]
        [] -> []
      }
    TgtAttacker -> [caster]
    TgtRandomEnemy ->
      case alive_enemies(heroes, caster.team) {
        [] -> []
        enemies -> {
          let idx = int.random(list.length(enemies))
          case list_at_index(enemies, idx) {
            Ok(h) -> [h]
            Error(_) -> []
          }
        }
      }
  }
}

fn alive_allies(heroes: Dict(String, MatchHero), team: Int) -> List(MatchHero) {
  heroes
  |> dict.values()
  |> list.filter(fn(h) { h.team == team && h.alive })
}

fn alive_enemies(heroes: Dict(String, MatchHero), team: Int) -> List(MatchHero) {
  heroes
  |> dict.values()
  |> list.filter(fn(h) { h.team != team && h.alive })
}

fn lowest_hp_hero(heroes: List(MatchHero)) -> Result(MatchHero, Nil) {
  case heroes {
    [] -> Error(Nil)
    [first, ..rest] ->
      Ok(list.fold(rest, first, fn(acc, h) {
        case h.hp_current < acc.hp_current {
          True -> h
          False -> acc
        }
      }))
  }
}

fn list_at_index(items: List(a), idx: Int) -> Result(a, Nil) {
  case items, idx {
    [item, ..], 0 -> Ok(item)
    [_, ..rest], n if n > 0 -> list_at_index(rest, n - 1)
    _, _ -> Error(Nil)
  }
}

// ============================================================================
// Ability effect application
// ============================================================================

// Compute ability heal scaled by caster attack and light affinity.
pub fn calculate_ability_heal(base_power: Int, caster_def: HeroDef) -> Int {
  let base = int.to_float(base_power)
  let attack_mult = int.to_float(caster_def.attack) /. 100.0
  let affinity_mult =
    1.0 +. { int.to_float(caster_def.light_affinity) /. 100.0 }
  let raw = base *. attack_mult *. affinity_mult
  let v = float.truncate(raw)
  case v {
    n if n < 1 -> 1
    n -> n
  }
}

// Compute ability damage (untyped, no element affinity).
pub fn calculate_ability_damage(
  base_power: Int,
  caster_def: HeroDef,
  target_def: HeroDef,
) -> Int {
  let base = int.to_float(base_power)
  let attack_mult = int.to_float(caster_def.attack) /. 100.0
  let defense_mit =
    100.0 /. { 100.0 +. int.to_float(target_def.defense) }
  let raw = base *. attack_mult *. defense_mit
  let v = float.truncate(raw)
  case v {
    n if n < 1 -> 1
    n -> n
  }
}

// Apply a single effect from an ability to one target.
// Returns updated hero and either a new status (or Nil).
pub fn apply_ability_effect(
  effect: AbilityEffect,
  caster_def: HeroDef,
  target: MatchHero,
  target_def: HeroDef,
  match_id: String,
  now: Int,
) -> #(MatchHero, Option(MatchStatus)) {
  case effect {
    EffHeal(base_power) -> {
      let amount = calculate_ability_heal(base_power, caster_def)
      #(apply_heal(target, amount), None)
    }
    EffDamage(base_power) -> {
      let amount = calculate_ability_damage(base_power, caster_def, target_def)
      #(apply_damage(target, amount), None)
    }
    EffApplyStatus(status, duration_ms, value) -> {
      let s =
        MatchStatus(
          status_id: generate_id("ability_status", now),
          match_id: match_id,
          hero_instance_id: target.hero_instance_id,
          kind: status,
          value: value,
          expires_at: now + duration_ms,
        )
      #(target, Some(s))
    }
  }
}

pub fn init_team_state(match_id: String, team: Int, now: Int) -> MatchTeamState {
  MatchTeamState(
    match_id: match_id,
    team: team,
    energy: start_energy,
    energy_max: max_energy,
    last_energy_at: now,
    selected_caster_slot: 1,
    hero_targets: dict.new(),
  )
}
