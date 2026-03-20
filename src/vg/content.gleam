// Static content definitions - heroes and actions
// Auto-generated from triarc-slice data/ — do not edit by hand.
// Regenerate with: node scripts/sync-content.mjs

import gleam/dict.{type Dict}
import gleam/option.{Some, None}
import vg/types.{
  type ActionDef, type HeroDef, ActionDef, HeroDef, AllySingle, EnemySingle, Self, Earth, Fire, Ice, Light, Shadow, Wind, Damage, DamageAndStatus, Heal, Shield, Status, AttackBuff, Dot, Hot, ShieldBuff, Stun,
}

// ============================================================================
// Hero definitions
// ============================================================================

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
    ice_affinity: 0,
    earth_affinity: -25,
    wind_affinity: 25,
    light_affinity: 5,
    shadow_affinity: 0,
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
  )
}

// ============================================================================
// Action definitions
// ============================================================================

pub fn action_definitions() -> Dict(String, ActionDef) {
  // Slugs must match editor data/action/ directory names (hyphens, not underscores)
  dict.from_list([
    #("arcane-blast", arcane_blast()),
    #("blizzard", blizzard()),
    #("chain", chain()),
    #("chain-spark", chain_spark()),
    #("charge", charge()),
    #("cleave", cleave()),
    #("cursed-dart", cursed_dart()),
    #("execute", execute()),
    #("fireball", fireball()),
    #("flame-lance", flame_lance()),
    #("fortify", fortify()),
    #("frostbolt", frostbolt()),
    #("garrote", garrote()),
    #("holy", holy()),
    #("ice-nova", ice_nova()),
    #("intercept", intercept()),
    #("leech-blade", leech_blade()),
    #("mana-weave", mana_weave()),
    #("mark-target", mark_target()),
    #("mirror-shield", mirror_shield()),
    #("poison-strike", poison_strike()),
    #("rally-cry", rally_cry()),
    #("riposte", riposte()),
    #("shadowstep", shadowstep()),
    #("shield-wall", shield_wall()),
    #("shiv", shiv()),
    #("smoke-bomb", smoke_bomb()),
    #("stand-firm", stand_firm()),
    #("taunt", taunt()),
    #("time-slip", time_slip()),
    #("toxic-coating", toxic_coating()),
  ])
}

// ---------------------------------------------------------------------------
// Action definitions — slugs match editor data/action/ directory names
// ---------------------------------------------------------------------------

// -- Fire --
fn fireball() -> ActionDef {
  ActionDef(slug: "fireball", display_name: "Fireball", element: Fire,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1500,
    effect_kind: Damage, base_power: 25,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn flame_lance() -> ActionDef {
  ActionDef(slug: "flame-lance", display_name: "Flame Lance", element: Fire,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1200,
    effect_kind: DamageAndStatus, base_power: 20,
    status_kind: Some(Dot), status_duration_ms: 4000, status_value: 6)
}

// -- Ice --
fn blizzard() -> ActionDef {
  ActionDef(slug: "blizzard", display_name: "Blizzard", element: Ice,
    target_rule: EnemySingle, energy_cost: 4, casting_time_ms: 2500,
    effect_kind: DamageAndStatus, base_power: 28,
    status_kind: Some(AttackBuff), status_duration_ms: 4000, status_value: -10)
}
fn frostbolt() -> ActionDef {
  ActionDef(slug: "frostbolt", display_name: "Frostbolt", element: Ice,
    target_rule: EnemySingle, energy_cost: 2, casting_time_ms: 1000,
    effect_kind: Damage, base_power: 15,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn ice_nova() -> ActionDef {
  ActionDef(slug: "ice-nova", display_name: "Ice Nova", element: Ice,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1800,
    effect_kind: DamageAndStatus, base_power: 18,
    status_kind: Some(AttackBuff), status_duration_ms: 3000, status_value: -12)
}

// -- Earth --
fn fortify() -> ActionDef {
  ActionDef(slug: "fortify", display_name: "Fortify", element: Earth,
    target_rule: AllySingle, energy_cost: 3, casting_time_ms: 1000,
    effect_kind: Shield, base_power: 30,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn poison_strike() -> ActionDef {
  ActionDef(slug: "poison-strike", display_name: "Poison Strike", element: Earth,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1400,
    effect_kind: DamageAndStatus, base_power: 16,
    status_kind: Some(Dot), status_duration_ms: 5000, status_value: 7)
}
fn shield_wall() -> ActionDef {
  ActionDef(slug: "shield-wall", display_name: "Shield Wall", element: Earth,
    target_rule: AllySingle, energy_cost: 3, casting_time_ms: 1200,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 6000, status_value: 20)
}
fn stand_firm() -> ActionDef {
  ActionDef(slug: "stand-firm", display_name: "Stand Firm", element: Earth,
    target_rule: Self, energy_cost: 2, casting_time_ms: 800,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 4000, status_value: 15)
}
fn toxic_coating() -> ActionDef {
  ActionDef(slug: "toxic-coating", display_name: "Toxic Coating", element: Earth,
    target_rule: AllySingle, energy_cost: 2, casting_time_ms: 800,
    effect_kind: Status, base_power: 0,
    status_kind: Some(AttackBuff), status_duration_ms: 5000, status_value: 10)
}

// -- Wind --
fn chain_spark() -> ActionDef {
  ActionDef(slug: "chain-spark", display_name: "Chain Spark", element: Wind,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1200,
    effect_kind: Damage, base_power: 22,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}

// -- Light --
fn arcane_blast() -> ActionDef {
  ActionDef(slug: "arcane-blast", display_name: "Arcane Blast", element: Light,
    target_rule: EnemySingle, energy_cost: 4, casting_time_ms: 1800,
    effect_kind: Damage, base_power: 32,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn holy() -> ActionDef {
  ActionDef(slug: "holy", display_name: "Holy", element: Light,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1500,
    effect_kind: Damage, base_power: 24,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn mana_weave() -> ActionDef {
  ActionDef(slug: "mana-weave", display_name: "Mana Weave", element: Light,
    target_rule: AllySingle, energy_cost: 2, casting_time_ms: 1000,
    effect_kind: Heal, base_power: 20,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn mirror_shield() -> ActionDef {
  ActionDef(slug: "mirror-shield", display_name: "Mirror Shield", element: Light,
    target_rule: AllySingle, energy_cost: 4, casting_time_ms: 1200,
    effect_kind: Shield, base_power: 45,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn rally_cry() -> ActionDef {
  ActionDef(slug: "rally-cry", display_name: "Rally Cry", element: Light,
    target_rule: AllySingle, energy_cost: 3, casting_time_ms: 1000,
    effect_kind: Status, base_power: 0,
    status_kind: Some(AttackBuff), status_duration_ms: 5000, status_value: 14)
}
fn time_slip() -> ActionDef {
  ActionDef(slug: "time-slip", display_name: "Time Slip", element: Light,
    target_rule: AllySingle, energy_cost: 4, casting_time_ms: 1400,
    effect_kind: Status, base_power: 0,
    status_kind: Some(AttackBuff), status_duration_ms: 5000, status_value: 18)
}

// -- Shadow --
fn cursed_dart() -> ActionDef {
  ActionDef(slug: "cursed-dart", display_name: "Cursed Dart", element: Shadow,
    target_rule: EnemySingle, energy_cost: 2, casting_time_ms: 900,
    effect_kind: DamageAndStatus, base_power: 12,
    status_kind: Some(ShieldBuff), status_duration_ms: 4000, status_value: -10)
}
fn leech_blade() -> ActionDef {
  ActionDef(slug: "leech-blade", display_name: "Leech Blade", element: Shadow,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1400,
    effect_kind: DamageAndStatus, base_power: 20,
    status_kind: Some(Hot), status_duration_ms: 4000, status_value: 8)
}
fn shadowstep() -> ActionDef {
  ActionDef(slug: "shadowstep", display_name: "Shadowstep", element: Shadow,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 800,
    effect_kind: Damage, base_power: 26,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn smoke_bomb() -> ActionDef {
  ActionDef(slug: "smoke-bomb", display_name: "Smoke Bomb", element: Shadow,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1000,
    effect_kind: Status, base_power: 0,
    status_kind: Some(AttackBuff), status_duration_ms: 4000, status_value: -15)
}

// -- Physical / Neutral --
fn chain() -> ActionDef {
  ActionDef(slug: "chain", display_name: "Chain", element: Earth,
    target_rule: EnemySingle, energy_cost: 2, casting_time_ms: 1000,
    effect_kind: DamageAndStatus, base_power: 14,
    status_kind: Some(AttackBuff), status_duration_ms: 3000, status_value: -8)
}
fn charge() -> ActionDef {
  ActionDef(slug: "charge", display_name: "Charge", element: Earth,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1000,
    effect_kind: DamageAndStatus, base_power: 22,
    status_kind: Some(Stun), status_duration_ms: 1500, status_value: 0)
}
fn cleave() -> ActionDef {
  ActionDef(slug: "cleave", display_name: "Cleave", element: Earth,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1200,
    effect_kind: Damage, base_power: 24,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn execute() -> ActionDef {
  ActionDef(slug: "execute", display_name: "Execute", element: Earth,
    target_rule: EnemySingle, energy_cost: 4, casting_time_ms: 2000,
    effect_kind: Damage, base_power: 40,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn garrote() -> ActionDef {
  ActionDef(slug: "garrote", display_name: "Garrote", element: Earth,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1200,
    effect_kind: DamageAndStatus, base_power: 14,
    status_kind: Some(Dot), status_duration_ms: 6000, status_value: 8)
}
fn intercept() -> ActionDef {
  ActionDef(slug: "intercept", display_name: "Intercept", element: Earth,
    target_rule: AllySingle, energy_cost: 3, casting_time_ms: 800,
    effect_kind: Shield, base_power: 25,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn mark_target() -> ActionDef {
  ActionDef(slug: "mark-target", display_name: "Mark Target", element: Earth,
    target_rule: EnemySingle, energy_cost: 2, casting_time_ms: 800,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 5000, status_value: -12)
}
fn riposte() -> ActionDef {
  ActionDef(slug: "riposte", display_name: "Riposte", element: Earth,
    target_rule: Self, energy_cost: 2, casting_time_ms: 600,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 3000, status_value: 12)
}
fn shiv() -> ActionDef {
  ActionDef(slug: "shiv", display_name: "Shiv", element: Earth,
    target_rule: EnemySingle, energy_cost: 1, casting_time_ms: 600,
    effect_kind: Damage, base_power: 10,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn taunt() -> ActionDef {
  ActionDef(slug: "taunt", display_name: "Taunt", element: Earth,
    target_rule: Self, energy_cost: 2, casting_time_ms: 600,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 4000, status_value: 18)
}

// ============================================================================
// Helper functions
// ============================================================================

pub fn get_hero_def(slug: String) -> Result(HeroDef, Nil) {
  dict.get(hero_definitions(), slug)
}

pub fn get_action_def(slug: String) -> Result(ActionDef, Nil) {
  dict.get(action_definitions(), slug)
}

pub fn get_all_action_slugs() -> List(String) {
  dict.keys(action_definitions())
}

pub fn get_all_hero_slugs() -> List(String) {
  dict.keys(hero_definitions())
}
