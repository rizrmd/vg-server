// Action definitions — server-owned balance source of truth.
// NOT auto-generated. Edit this file directly to tune balance.
// Client-side data/action/*.json holds only presentation (cost display, vfx,
// card art). Balance lives here.

import gleam/dict.{type Dict}
import gleam/option.{None, Some}
import vg/types.{
  type ActionDef, ActionDef, AllySingle, AttackBuff, Damage, DamageAndStatus,
  Dot, Earth, EnemySingle, Fire, Heal, Hot, Ice, Light, Self, Shadow, Shield,
  ShieldBuff, Status, Stun, Wind,
}

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

pub fn get_action_def(slug: String) -> Result(ActionDef, Nil) {
  dict.get(action_definitions(), slug)
}

pub fn get_all_action_slugs() -> List(String) {
  dict.keys(action_definitions())
}

// ---------------------------------------------------------------------------
// Action definitions — slugs match editor data/action/ directory names
// ---------------------------------------------------------------------------

// -- Fire --
fn charge() -> ActionDef {
  ActionDef(slug: "charge", display_name: "Charge", element: Fire,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1000,
    effect_kind: DamageAndStatus, base_power: 22,
    status_kind: Some(Stun), status_duration_ms: 1500, status_value: 0)
}
fn cleave() -> ActionDef {
  ActionDef(slug: "cleave", display_name: "Cleave", element: Fire,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1200,
    effect_kind: Damage, base_power: 24,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
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
fn taunt() -> ActionDef {
  ActionDef(slug: "taunt", display_name: "Taunt", element: Fire,
    target_rule: Self, energy_cost: 2, casting_time_ms: 600,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 4000, status_value: 18)
}

// -- Ice --
fn blizzard() -> ActionDef {
  ActionDef(slug: "blizzard", display_name: "Blizzard", element: Ice,
    target_rule: EnemySingle, energy_cost: 4, casting_time_ms: 2500,
    effect_kind: DamageAndStatus, base_power: 28,
    status_kind: Some(AttackBuff), status_duration_ms: 4000, status_value: -10)
}
fn chain() -> ActionDef {
  ActionDef(slug: "chain", display_name: "Chain", element: Ice,
    target_rule: EnemySingle, energy_cost: 2, casting_time_ms: 1000,
    effect_kind: DamageAndStatus, base_power: 14,
    status_kind: Some(AttackBuff), status_duration_ms: 3000, status_value: -8)
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
fn intercept() -> ActionDef {
  ActionDef(slug: "intercept", display_name: "Intercept", element: Ice,
    target_rule: AllySingle, energy_cost: 3, casting_time_ms: 800,
    effect_kind: Shield, base_power: 25,
    status_kind: None, status_duration_ms: 0, status_value: 0)
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
fn mark_target() -> ActionDef {
  ActionDef(slug: "mark-target", display_name: "Mark Target", element: Wind,
    target_rule: EnemySingle, energy_cost: 2, casting_time_ms: 800,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 5000, status_value: -12)
}
fn riposte() -> ActionDef {
  ActionDef(slug: "riposte", display_name: "Riposte", element: Wind,
    target_rule: Self, energy_cost: 2, casting_time_ms: 600,
    effect_kind: Status, base_power: 0,
    status_kind: Some(ShieldBuff), status_duration_ms: 3000, status_value: 12)
}
fn shiv() -> ActionDef {
  ActionDef(slug: "shiv", display_name: "Shiv", element: Wind,
    target_rule: EnemySingle, energy_cost: 1, casting_time_ms: 600,
    effect_kind: Damage, base_power: 10,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}

// -- Light --
fn arcane_blast() -> ActionDef {
  ActionDef(slug: "arcane-blast", display_name: "Arcane Blast", element: Light,
    target_rule: EnemySingle, energy_cost: 4, casting_time_ms: 1000,
    effect_kind: Damage, base_power: 45,
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
fn execute() -> ActionDef {
  ActionDef(slug: "execute", display_name: "Execute", element: Shadow,
    target_rule: EnemySingle, energy_cost: 4, casting_time_ms: 2000,
    effect_kind: Damage, base_power: 40,
    status_kind: None, status_duration_ms: 0, status_value: 0)
}
fn garrote() -> ActionDef {
  ActionDef(slug: "garrote", display_name: "Garrote", element: Shadow,
    target_rule: EnemySingle, energy_cost: 3, casting_time_ms: 1200,
    effect_kind: DamageAndStatus, base_power: 14,
    status_kind: Some(Dot), status_duration_ms: 6000, status_value: 8)
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
