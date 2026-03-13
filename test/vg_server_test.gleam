import gleam/dict
import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit
import gleeunit/should
import vg/content
import vg/game_json as gj
import vg/json_parse as jp
import vg/match_logic
import vg/types.{Earth, Fire, Ice}

pub fn main() {
  gleeunit.main()
}

// Content tests
pub fn hero_definitions_exist_test() {
  let heroes = content.hero_definitions()
  should.be_true(dict.size(heroes) > 0)
}

pub fn action_definitions_exist_test() {
  let actions = content.action_definitions()
  should.be_true(dict.size(actions) > 0)
}

pub fn iron_knight_exists_test() {
  case content.get_hero_def("iron-knight") {
    Ok(hero) -> {
      should.equal(hero.display_name, "Iron Knight")
      should.equal(hero.max_hp, 3500)
    }
    Error(_) -> should.fail()
  }
}

pub fn fireball_exists_test() {
  case content.get_action_def("fireball") {
    Ok(action) -> {
      should.equal(action.display_name, "Fireball")
      should.equal(action.element, Fire)
      should.equal(action.energy_cost, 3)
    }
    Error(_) -> should.fail()
  }
}

// Game logic tests
pub fn damage_calculation_test() {
  // Test that damage is at least 1
  let hero_def =
    types.HeroDef(
      slug: "test",
      display_name: "Test",
      max_hp: 1000,
      attack: 100,
      defense: 50,
      fire_affinity: 0,
      ice_affinity: 0,
      earth_affinity: 0,
      wind_affinity: 0,
      light_affinity: 0,
      shadow_affinity: 0,
    )

  let action_def =
    types.ActionDef(
      slug: "test_action",
      display_name: "Test Action",
      element: Fire,
      target_rule: types.EnemySingle,
      energy_cost: 2,
      casting_time_ms: 1000,
      effect_kind: types.Damage,
      base_power: 25,
      status_kind: None,
      status_duration_ms: 0,
      status_value: 0,
    )

  let caster =
    types.MatchHero(
      hero_instance_id: "caster1",
      match_id: "match1",
      team: 1,
      slot_index: 1,
      hero_slug: "test",
      hp_current: 1000,
      hp_max: 1000,
      alive: True,
      busy_until: 0,
    )

  let target =
    types.MatchHero(
      hero_instance_id: "target1",
      match_id: "match1",
      team: 2,
      slot_index: 1,
      hero_slug: "test",
      hp_current: 1000,
      hp_max: 1000,
      alive: True,
      busy_until: 0,
    )

  let damage =
    match_logic.calculate_damage(action_def, caster, target, hero_def, hero_def)
  should.be_true(damage >= 1)
}

pub fn energy_regen_test() {
  let regen = match_logic.calculate_energy_regen(5000)
  should.equal(regen, 5)
  // 5 seconds = 5 energy
}

pub fn max_energy_constant_test() {
  should.equal(match_logic.max_energy, 10)
}

pub fn reroll_cost_test() {
  should.equal(match_logic.reroll_cost, 2)
}

// Element tests
pub fn element_to_string_test() {
  should.equal(types.element_to_string(Fire), "fire")
  should.equal(types.element_to_string(Ice), "ice")
  should.equal(types.element_to_string(Earth), "earth")
}

pub fn element_from_string_test() {
  should.equal(types.element_from_string("fire"), Ok(Fire))
  should.equal(types.element_from_string("ice"), Ok(Ice))
  should.equal(types.element_from_string("unknown"), Error(Nil))
}

// JSON parsing tests
pub fn parse_upsert_profile_test() {
  let json = "{\"type\":\"upsert_profile\",\"display_name\":\"TestPlayer\"}"
  case jp.parse_client_message(json) {
    Ok(msg) -> {
      case msg {
        gj.UpsertProfile(n) -> should.equal(n, "TestPlayer")
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

pub fn parse_queue_matchmaking_test() {
  let json =
    "{\"type\":\"queue_matchmaking\",\"hero_slug_1\":\"iron-knight\",\"hero_slug_2\":\"arc-strider\",\"hero_slug_3\":\"necromancer\"}"
  case jp.parse_client_message(json) {
    Ok(msg) -> {
      case msg {
        gj.QueueMatchmaking(h1, h2, h3) -> {
          should.equal(h1, "iron-knight")
          should.equal(h2, "arc-strider")
          should.equal(h3, "necromancer")
        }
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

pub fn parse_cast_action_test() {
  let json =
    "{\"type\":\"cast_action\",\"match_id\":\"match123\",\"caster_slot\":1,\"hand_slot_index\":2}"
  case jp.parse_client_message(json) {
    Ok(msg) -> {
      case msg {
        gj.CastAction(match_id, caster_slot, hand_slot) -> {
          should.equal(match_id, "match123")
          should.equal(caster_slot, 1)
          should.equal(hand_slot, 2)
        }
        _ -> should.fail()
      }
    }
    _ -> should.fail()
  }
}

pub fn parse_invalid_json_test() {
  let json = "{\"invalid\":\"json\"}"
  case jp.parse_client_message(json) {
    Error(_) -> should.be_true(True)
    _ -> should.fail()
  }
}

// JSON encoding tests
pub fn encode_connected_message_test() {
  let msg = gj.Connected("player_123")
  let json = gj.encode_server_message(msg)
  should.be_true(string.contains(json, "connected"))
  should.be_true(string.contains(json, "player_123"))
}

pub fn encode_error_message_test() {
  let msg = gj.Error("TEST_ERROR", "Test message")
  let json = gj.encode_server_message(msg)
  should.be_true(string.contains(json, "error"))
  should.be_true(string.contains(json, "TEST_ERROR"))
}

// Game logic integration tests
pub fn spawn_hero_test() {
  let now = 1000
  case match_logic.spawn_hero("match1", 1, 1, "iron-knight", now) {
    Ok(hero) -> {
      should.equal(hero.match_id, "match1")
      should.equal(hero.team, 1)
      should.equal(hero.slot_index, 1)
      should.equal(hero.hero_slug, "iron-knight")
      should.be_true(hero.hp_current > 0)
      should.be_true(hero.alive)
    }
    Error(_) -> should.fail()
  }
}

pub fn spawn_invalid_hero_test() {
  let now = 1000
  case match_logic.spawn_hero("match1", 1, 1, "invalid-hero", now) {
    Error(_) -> should.be_true(True)
    Ok(_) -> should.fail()
  }
}

pub fn roll_hand_test() {
  let hand = match_logic.roll_hand()
  should.equal(list.length(hand), 5)
  // hand_size = 5
}

pub fn energy_management_test() {
  let team_state =
    types.MatchTeamState(
      match_id: "match1",
      team: 1,
      energy: 10,
      energy_max: 10,
      last_energy_at: 0,
      selected_caster_slot: 1,
    )

  // Can spend energy
  should.be_true(match_logic.can_spend_energy(team_state, 5))
  should.be_false(match_logic.can_spend_energy(team_state, 15))

  // Spend energy
  let new_state = match_logic.spend_energy(team_state, 3)
  should.equal(new_state.energy, 7)
}

pub fn target_validation_test() {
  // Self target always valid
  should.be_true(match_logic.is_valid_target(types.Self, 1, 1, True))

  // Ally target - same team, alive
  should.be_true(match_logic.is_valid_target(types.AllySingle, 1, 1, True))
  should.be_false(match_logic.is_valid_target(types.AllySingle, 1, 1, False))
  // dead
  should.be_false(match_logic.is_valid_target(types.AllySingle, 1, 2, True))
  // different team

  // Enemy target - different team, alive
  should.be_true(match_logic.is_valid_target(types.EnemySingle, 1, 2, True))
  should.be_false(match_logic.is_valid_target(types.EnemySingle, 1, 2, False))
  // dead
  should.be_false(match_logic.is_valid_target(types.EnemySingle, 1, 1, True))
  // same team
}

pub fn win_condition_test() {
  // Team 1: all dead
  // Team 2: all alive -> Team 2 should win
  let heroes =
    dict.from_list([
      #(
        "hero1",
        types.MatchHero(
          hero_instance_id: "hero1",
          match_id: "match1",
          team: 1,
          slot_index: 1,
          hero_slug: "test",
          hp_current: 0,
          hp_max: 100,
          alive: False,
          busy_until: 0,
        ),
      ),
      #(
        "hero2",
        types.MatchHero(
          hero_instance_id: "hero2",
          match_id: "match1",
          team: 1,
          slot_index: 2,
          hero_slug: "test",
          hp_current: 0,
          hp_max: 100,
          alive: False,
          busy_until: 0,
        ),
      ),
      #(
        "hero3",
        types.MatchHero(
          hero_instance_id: "hero3",
          match_id: "match1",
          team: 1,
          slot_index: 3,
          hero_slug: "test",
          hp_current: 0,
          hp_max: 100,
          alive: False,
          busy_until: 0,
        ),
      ),
      #(
        "hero4",
        types.MatchHero(
          hero_instance_id: "hero4",
          match_id: "match1",
          team: 2,
          slot_index: 1,
          hero_slug: "test",
          hp_current: 100,
          hp_max: 100,
          alive: True,
          busy_until: 0,
        ),
      ),
      #(
        "hero5",
        types.MatchHero(
          hero_instance_id: "hero5",
          match_id: "match1",
          team: 2,
          slot_index: 2,
          hero_slug: "test",
          hp_current: 100,
          hp_max: 100,
          alive: True,
          busy_until: 0,
        ),
      ),
      #(
        "hero6",
        types.MatchHero(
          hero_instance_id: "hero6",
          match_id: "match1",
          team: 2,
          slot_index: 3,
          hero_slug: "test",
          hp_current: 100,
          hp_max: 100,
          alive: True,
          busy_until: 0,
        ),
      ),
    ])

  let winner = match_logic.check_win_condition(heroes)
  should.equal(winner, types.Team2)
  // Team 1 all dead, Team 2 all alive
}
