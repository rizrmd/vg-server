// Static hero content definitions - auto-generated from triarc-slice data/
// Regenerate with: node scripts/sync-content.mjs
// NOTE: Action definitions live in vg/actions.gleam (server-owned, not auto-generated)

import gleam/dict.{type Dict}
import gleam/list
import vg/types.{
  type AbilityDef, type HeroDef, AbilityDef, EffApplyStatus, EffHeal, EvtActionUsed,
  EvtNone, FirstAlive, HeroDef, HighestHp, Hot, LowestHp, ModeActionLinked,
  ModeManual, RolePassive, RoleSkill, ScopeSelf, TgtAllAllies, TgtLowestHpAlly,
}

pub fn hero_definitions() -> Dict(String, HeroDef) {
  dict.from_list([
    #("arc-strider", arc_strider()),
    #("arcane-paladin", arcane_paladin()),
    #("blood-alchemist", blood_alchemist()),
    #("dawn-priest", dawn_priest()),
    #("demon-empress", demon_empress()),
    #("earth-warden", earth_warden()),
    #("flame-warlock", flame_warlock()),
    #("frost-queen", frost_queen()),
    #("gunslinger", gunslinger()),
    #("iron-knight", iron_knight()),
    #("necromancer", necromancer()),
    #("night-venom", night_venom()),
    #("princess-emberheart", princess_emberheart()),
    #("spellblade-empress", spellblade_empress()),
    #("storm-ranger", storm_ranger()),
    #("tyrant-overlord", tyrant_overlord()),
    #("wind-monk", wind_monk()),
  ])
}

fn arc_strider() -> HeroDef {
  HeroDef(
    slug: "arc-strider",
    display_name: "Arc Strider",
    max_hp: 2700,
    attack: 155,
    defense: 115,
    fire_affinity: 10,
    ice_affinity: 3,
    earth_affinity: -25,
    wind_affinity: 25,
    light_affinity: 5,
    shadow_affinity: 0,
    target_policy: FirstAlive,
  )
}

fn arcane_paladin() -> HeroDef {
  HeroDef(
    slug: "arcane-paladin",
    display_name: "Arcane Paladin",
    max_hp: 3200,
    attack: 145,
    defense: 145,
    fire_affinity: -20,
    ice_affinity: 0,
    earth_affinity: 10,
    wind_affinity: -10,
    light_affinity: 20,
    shadow_affinity: 15,
    target_policy: FirstAlive,
  )
}

fn blood_alchemist() -> HeroDef {
  HeroDef(
    slug: "blood-alchemist",
    display_name: "Blood Alchemist",
    max_hp: 2900,
    attack: 145,
    defense: 110,
    fire_affinity: -10,
    ice_affinity: 0,
    earth_affinity: 10,
    wind_affinity: 0,
    light_affinity: -20,
    shadow_affinity: 30,
    target_policy: LowestHp,
  )
}

fn dawn_priest() -> HeroDef {
  HeroDef(
    slug: "dawn-priest",
    display_name: "Dawn Priest",
    max_hp: 2800,
    attack: 100,
    defense: 130,
    fire_affinity: 15,
    ice_affinity: -10,
    earth_affinity: 0,
    wind_affinity: 0,
    light_affinity: 40,
    shadow_affinity: -35,
    target_policy: FirstAlive,
  )
}

fn demon_empress() -> HeroDef {
  HeroDef(
    slug: "demon-empress",
    display_name: "Demon Empress",
    max_hp: 3100,
    attack: 160,
    defense: 125,
    fire_affinity: 20,
    ice_affinity: 0,
    earth_affinity: 10,
    wind_affinity: -10,
    light_affinity: -35,
    shadow_affinity: 30,
    target_policy: FirstAlive,
  )
}

fn earth_warden() -> HeroDef {
  HeroDef(
    slug: "earth-warden",
    display_name: "Earth Warden",
    max_hp: 3600,
    attack: 120,
    defense: 170,
    fire_affinity: 10,
    ice_affinity: 10,
    earth_affinity: 35,
    wind_affinity: -35,
    light_affinity: 0,
    shadow_affinity: -5,
    target_policy: FirstAlive,
  )
}

fn flame_warlock() -> HeroDef {
  HeroDef(
    slug: "flame-warlock",
    display_name: "Flame Warlock",
    max_hp: 2400,
    attack: 175,
    defense: 90,
    fire_affinity: 35,
    ice_affinity: -35,
    earth_affinity: -5,
    wind_affinity: 15,
    light_affinity: 0,
    shadow_affinity: 0,
    target_policy: HighestHp,
  )
}

fn frost_queen() -> HeroDef {
  HeroDef(
    slug: "frost-queen",
    display_name: "Frost Queen",
    max_hp: 2800,
    attack: 155,
    defense: 125,
    fire_affinity: -35,
    ice_affinity: 40,
    earth_affinity: -10,
    wind_affinity: 15,
    light_affinity: 0,
    shadow_affinity: 0,
    target_policy: HighestHp,
  )
}

fn gunslinger() -> HeroDef {
  HeroDef(
    slug: "gunslinger",
    display_name: "Gunslinger",
    max_hp: 2500,
    attack: 165,
    defense: 105,
    fire_affinity: 20,
    ice_affinity: -10,
    earth_affinity: -15,
    wind_affinity: 15,
    light_affinity: 10,
    shadow_affinity: -5,
    target_policy: FirstAlive,
  )
}

fn iron_knight() -> HeroDef {
  HeroDef(
    slug: "iron-knight",
    display_name: "Iron Knight",
    max_hp: 3500,
    attack: 130,
    defense: 180,
    fire_affinity: -15,
    ice_affinity: 10,
    earth_affinity: 30,
    wind_affinity: -20,
    light_affinity: 10,
    shadow_affinity: 0,
    target_policy: FirstAlive,
  )
}

fn necromancer() -> HeroDef {
  HeroDef(
    slug: "necromancer",
    display_name: "Necromancer",
    max_hp: 2300,
    attack: 160,
    defense: 100,
    fire_affinity: -20,
    ice_affinity: 15,
    earth_affinity: 10,
    wind_affinity: 0,
    light_affinity: -30,
    shadow_affinity: 35,
    target_policy: LowestHp,
  )
}

fn night_venom() -> HeroDef {
  HeroDef(
    slug: "night-venom",
    display_name: "Night Venom",
    max_hp: 2500,
    attack: 170,
    defense: 95,
    fire_affinity: -10,
    ice_affinity: 0,
    earth_affinity: 20,
    wind_affinity: 0,
    light_affinity: -25,
    shadow_affinity: 25,
    target_policy: LowestHp,
  )
}

fn princess_emberheart() -> HeroDef {
  HeroDef(
    slug: "princess-emberheart",
    display_name: "Princess Emberheart",
    max_hp: 2900,
    attack: 150,
    defense: 120,
    fire_affinity: 30,
    ice_affinity: -25,
    earth_affinity: -5,
    wind_affinity: 5,
    light_affinity: 10,
    shadow_affinity: 0,
    target_policy: FirstAlive,
  )
}

fn spellblade_empress() -> HeroDef {
  HeroDef(
    slug: "spellblade-empress",
    display_name: "Spellblade Empress",
    max_hp: 3000,
    attack: 145,
    defense: 135,
    fire_affinity: 5,
    ice_affinity: 5,
    earth_affinity: -10,
    wind_affinity: 5,
    light_affinity: 20,
    shadow_affinity: -15,
    target_policy: FirstAlive,
  )
}

fn storm_ranger() -> HeroDef {
  HeroDef(
    slug: "storm-ranger",
    display_name: "Storm Ranger",
    max_hp: 2600,
    attack: 160,
    defense: 110,
    fire_affinity: -5,
    ice_affinity: 5,
    earth_affinity: -25,
    wind_affinity: 25,
    light_affinity: 15,
    shadow_affinity: 0,
    target_policy: FirstAlive,
  )
}

fn tyrant_overlord() -> HeroDef {
  HeroDef(
    slug: "tyrant-overlord",
    display_name: "Tyrant Overlord",
    max_hp: 3800,
    attack: 165,
    defense: 150,
    fire_affinity: 20,
    ice_affinity: 0,
    earth_affinity: 15,
    wind_affinity: -10,
    light_affinity: -35,
    shadow_affinity: 25,
    target_policy: FirstAlive,
  )
}

fn wind_monk() -> HeroDef {
  HeroDef(
    slug: "wind-monk",
    display_name: "Wind Monk",
    max_hp: 2700,
    attack: 140,
    defense: 120,
    fire_affinity: 0,
    ice_affinity: 0,
    earth_affinity: -25,
    wind_affinity: 35,
    light_affinity: 10,
    shadow_affinity: -5,
    target_policy: FirstAlive,
  )
}

pub fn get_hero_def(slug: String) -> Result(HeroDef, Nil) {
  dict.get(hero_definitions(), slug)
}

pub fn get_all_hero_slugs() -> List(String) {
  dict.keys(hero_definitions())
}

// ============================================================================
// Hero abilities
// ============================================================================

pub fn ability_definitions() -> Dict(String, List(AbilityDef)) {
  dict.from_list([
    #("dawn-priest", dawn_priest_abilities()),
  ])
}

pub fn get_hero_abilities(slug: String) -> List(AbilityDef) {
  case dict.get(ability_definitions(), slug) {
    Ok(abilities) -> abilities
    Error(_) -> []
  }
}

pub fn get_hero_ability(slug: String, ability_id: String) -> Result(AbilityDef, Nil) {
  list.find(get_hero_abilities(slug), fn(a) { a.id == ability_id })
}

fn dawn_priest_abilities() -> List(AbilityDef) {
  [
    AbilityDef(
      id: "dawn_blessing",
      hero_slug: "dawn-priest",
      name: "Dawn Blessing",
      role: RolePassive,
      target: TgtLowestHpAlly,
      mana_cost: 0,
      activation_mode: ModeActionLinked,
      activation_event: EvtActionUsed,
      actor_scope: ScopeSelf,
      cooldown_ms: 0,
      effects: [EffHeal(base_power: 8)],
      thought: "May the light find you, {target}.",
    ),
    AbilityDef(
      id: "continuous_regen",
      hero_slug: "dawn-priest",
      name: "Continuous Regen",
      role: RoleSkill,
      target: TgtAllAllies,
      mana_cost: 8,
      activation_mode: ModeManual,
      activation_event: EvtNone,
      actor_scope: ScopeSelf,
      cooldown_ms: 0,
      effects: [
        EffApplyStatus(status: Hot, duration_ms: 5000, value: 24),
      ],
      thought: "Rest beneath the dawn.",
    ),
  ]
}
