import gleam/dict
import gleam/option.{None}
import gleeunit
import gleeunit/should
import vg/content
import vg/match_logic
import vg/types.{Fire, Ice, Earth, Wind, Light, Shadow}

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
  let hero_def = types.HeroDef(
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
  
  let action_def = types.ActionDef(
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
  
  let caster = types.MatchHero(
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
  
  let target = types.MatchHero(
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
  
  let damage = match_logic.calculate_damage(action_def, caster, target, hero_def, hero_def)
  should.be_true(damage >= 1)
}

pub fn energy_regen_test() {
  let regen = match_logic.calculate_energy_regen(5000)
  should.equal(regen, 5) // 5 seconds = 5 energy
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
