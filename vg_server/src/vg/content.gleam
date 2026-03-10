// Static content definitions - heroes and actions
// Based on triarc-slice repository data

import gleam/dict.{type Dict}
import gleam/option.{Some, None}
import vg/types.{
  type ActionDef, type HeroDef, ActionDef, AllySingle, Damage, DamageAndStatus,
  EnemySingle, Fire, Heal, HeroDef, Ice, Light, Self, Shadow, Shield, Status, Wind,
  ShieldBuff, AttackBuff, Cleanse, Dot, Hot, Stun, Earth,
}

// ============================================================================
// Hero definitions from triarc-slice
// ============================================================================

pub fn hero_definitions() -> Dict(String, HeroDef) {
  dict.from_list([
    #("iron-knight", iron_knight()),
    #("arc-strider", arc_strider()),
    #("necromancer", necromancer()),
    #("spellblade-empress", spellblade_empress()),
    #("earth-warden", earth_warden()),
    #("dawn-priest", dawn_priest()),
    #("flame-warlock", flame_warlock()),
    #("blood-alchemist", blood_alchemist()),
    #("gunslinger", gunslinger()),
    #("night-venom", night_venom()),
    #("princess-emberheart", princess_emberheart()),
    #("demon-empress", demon_empress()),
    #("tyrant-overlord", tyrant_overlord()),
    #("arcane-paladin", arcane_paladin()),
    #("storm-ranger", storm_ranger()),
    #("wind-monk", wind_monk()),
    #("frost-queen", frost_queen()),
  ])
}

// Iron Knight - Tanky warrior with high defense
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

// Arc Strider - Fast lightning warrior
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

// Necromancer - Shadow magic user
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

// Spellblade Empress - Balanced elemental fighter
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

// Earth Warden - Defensive nature guardian
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

// Dawn Priest - Healer with light magic
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

// Flame Warlock - Fire damage dealer
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

// Blood Alchemist - Dark healer/damage hybrid
fn blood_alchemist() -> HeroDef {
  HeroDef(
    slug: "blood-alchemist",
    display_name: "Blood Alchemist",
    max_hp: 2600,
    attack: 140,
    defense: 110,
    fire_affinity: 0,
    ice_affinity: 5,
    earth_affinity: 0,
    wind_affinity: -10,
    light_affinity: -20,
    shadow_affinity: 25,
  )
}

// Gunslinger - Ranged physical damage
fn gunslinger() -> HeroDef {
  HeroDef(
    slug: "gunslinger",
    display_name: "Gunslinger",
    max_hp: 2500,
    attack: 165,
    defense: 95,
    fire_affinity: 20,
    ice_affinity: 0,
    earth_affinity: -15,
    wind_affinity: 15,
    light_affinity: 0,
    shadow_affinity: 5,
  )
}

// Night Venom - Poison/assassin type
fn night_venom() -> HeroDef {
  HeroDef(
    slug: "night-venom",
    display_name: "Night Venom",
    max_hp: 2400,
    attack: 170,
    defense: 85,
    fire_affinity: -10,
    ice_affinity: 10,
    earth_affinity: 5,
    wind_affinity: 10,
    light_affinity: -25,
    shadow_affinity: 30,
  )
}

// Princess Emberheart - Fire/Light hybrid
fn princess_emberheart() -> HeroDef {
  HeroDef(
    slug: "princess-emberheart",
    display_name: "Princess Emberheart",
    max_hp: 2900,
    attack: 135,
    defense: 120,
    fire_affinity: 30,
    ice_affinity: -15,
    earth_affinity: 0,
    wind_affinity: 5,
    light_affinity: 15,
    shadow_affinity: -10,
  )
}

// Demon Empress - Shadow/Fire powerhouse
fn demon_empress() -> HeroDef {
  HeroDef(
    slug: "demon-empress",
    display_name: "Demon Empress",
    max_hp: 3200,
    attack: 150,
    defense: 140,
    fire_affinity: 25,
    ice_affinity: -10,
    earth_affinity: 10,
    wind_affinity: -5,
    light_affinity: -30,
    shadow_affinity: 30,
  )
}

// Tyrant Overlord - Physical tank with shadow
fn tyrant_overlord() -> HeroDef {
  HeroDef(
    slug: "tyrant-overlord",
    display_name: "Tyrant Overlord",
    max_hp: 3800,
    attack: 125,
    defense: 185,
    fire_affinity: 10,
    ice_affinity: 0,
    earth_affinity: 20,
    wind_affinity: -20,
    light_affinity: -15,
    shadow_affinity: 20,
  )
}

// Arcane Paladin - Light/Ice defender
fn arcane_paladin() -> HeroDef {
  HeroDef(
    slug: "arcane-paladin",
    display_name: "Arcane Paladin",
    max_hp: 3300,
    attack: 115,
    defense: 165,
    fire_affinity: 0,
    ice_affinity: 15,
    earth_affinity: 5,
    wind_affinity: -10,
    light_affinity: 30,
    shadow_affinity: -20,
  )
}

// Storm Ranger - Wind/Lightning archer
fn storm_ranger() -> HeroDef {
  HeroDef(
    slug: "storm-ranger",
    display_name: "Storm Ranger",
    max_hp: 2600,
    attack: 160,
    defense: 100,
    fire_affinity: 5,
    ice_affinity: 10,
    earth_affinity: -20,
    wind_affinity: 30,
    light_affinity: 10,
    shadow_affinity: 0,
  )
}

// Wind Monk - Fast martial artist
fn wind_monk() -> HeroDef {
  HeroDef(
    slug: "wind-monk",
    display_name: "Wind Monk",
    max_hp: 2800,
    attack: 155,
    defense: 105,
    fire_affinity: 0,
    ice_affinity: -5,
    earth_affinity: -15,
    wind_affinity: 35,
    light_affinity: 5,
    shadow_affinity: -5,
  )
}

// Frost Queen - Ice control mage
fn frost_queen() -> HeroDef {
  HeroDef(
    slug: "frost-queen",
    display_name: "Frost Queen",
    max_hp: 2700,
    attack: 150,
    defense: 115,
    fire_affinity: -30,
    ice_affinity: 40,
    earth_affinity: 5,
    wind_affinity: 10,
    light_affinity: 0,
    shadow_affinity: 5,
  )
}

// ============================================================================
// Action definitions
// ============================================================================

pub fn action_definitions() -> Dict(String, ActionDef) {
  dict.from_list([
    // Fire actions
    #("fireball", fireball()),
    #("inferno", inferno()),
    #("flame_shield", flame_shield()),
    #("meteor", meteor()),
    #("burn", burn()),
    
    // Ice actions
    #("ice_shard", ice_shard()),
    #("frost_armor", frost_armor()),
    #("blizzard", blizzard()),
    #("frost_nova", frost_nova()),
    #("deep_freeze", deep_freeze()),
    
    // Earth actions
    #("rock_throw", rock_throw()),
    #("earth_shield", earth_shield()),
    #("quake", quake()),
    #("stone_skin", stone_skin()),
    
    // Wind actions
    #("wind_slash", wind_slash()),
    #("gust", gust()),
    #("lightning_strike", lightning_strike()),
    #("tailwind", tailwind()),
    
    // Light actions
    #("heal", heal()),
    #("smite", smite()),
    #("divine_shield", divine_shield()),
    #("mass_heal", mass_heal()),
    #("bless", bless()),
    #("judgment", judgment()),
    
    // Shadow actions
    #("shadow_strike", shadow_strike()),
    #("dark_bolt", dark_bolt()),
    #("curse", curse()),
    #("life_drain", life_drain()),
    #("dark_ritual", dark_ritual()),
    
    // Basic actions
    #("attack", basic_attack()),
    #("defend", defend()),
    #("cleanse", cleanse_action()),
    #("focus", focus()),
  ])
}

// Fire actions
fn fireball() -> ActionDef {
  ActionDef(
    slug: "fireball",
    display_name: "Fireball",
    element: Fire,
    target_rule: EnemySingle,
    energy_cost: 3,
    casting_time_ms: 1500,
    effect_kind: Damage,
    base_power: 25,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn inferno() -> ActionDef {
  ActionDef(
    slug: "inferno",
    display_name: "Inferno",
    element: Fire,
    target_rule: EnemySingle,
    energy_cost: 5,
    casting_time_ms: 2500,
    effect_kind: DamageAndStatus,
    base_power: 35,
    status_kind: Some(Dot),
    status_duration_ms: 5000,
    status_value: 8,
  )
}

fn flame_shield() -> ActionDef {
  ActionDef(
    slug: "flame_shield",
    display_name: "Flame Shield",
    element: Fire,
    target_rule: AllySingle,
    energy_cost: 3,
    casting_time_ms: 1000,
    effect_kind: Shield,
    base_power: 20,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn meteor() -> ActionDef {
  ActionDef(
    slug: "meteor",
    display_name: "Meteor",
    element: Fire,
    target_rule: EnemySingle,
    energy_cost: 7,
    casting_time_ms: 3500,
    effect_kind: DamageAndStatus,
    base_power: 50,
    status_kind: Some(Dot),
    status_duration_ms: 4000,
    status_value: 12,
  )
}

fn burn() -> ActionDef {
  ActionDef(
    slug: "burn",
    display_name: "Burn",
    element: Fire,
    target_rule: EnemySingle,
    energy_cost: 2,
    casting_time_ms: 800,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(Dot),
    status_duration_ms: 6000,
    status_value: 6,
  )
}

// Ice actions
fn ice_shard() -> ActionDef {
  ActionDef(
    slug: "ice_shard",
    display_name: "Ice Shard",
    element: Ice,
    target_rule: EnemySingle,
    energy_cost: 2,
    casting_time_ms: 1000,
    effect_kind: Damage,
    base_power: 15,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn frost_armor() -> ActionDef {
  ActionDef(
    slug: "frost_armor",
    display_name: "Frost Armor",
    element: Ice,
    target_rule: AllySingle,
    energy_cost: 3,
    casting_time_ms: 1200,
    effect_kind: Shield,
    base_power: 25,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn blizzard() -> ActionDef {
  ActionDef(
    slug: "blizzard",
    display_name: "Blizzard",
    element: Ice,
    target_rule: EnemySingle,
    energy_cost: 6,
    casting_time_ms: 3000,
    effect_kind: DamageAndStatus,
    base_power: 30,
    status_kind: Some(AttackBuff),
    status_duration_ms: 4000,
    status_value: -10,
  )
}

fn frost_nova() -> ActionDef {
  ActionDef(
    slug: "frost_nova",
    display_name: "Frost Nova",
    element: Ice,
    target_rule: EnemySingle,
    energy_cost: 4,
    casting_time_ms: 1800,
    effect_kind: DamageAndStatus,
    base_power: 20,
    status_kind: Some(AttackBuff),
    status_duration_ms: 3000,
    status_value: -15,
  )
}

fn deep_freeze() -> ActionDef {
  ActionDef(
    slug: "deep_freeze",
    display_name: "Deep Freeze",
    element: Ice,
    target_rule: EnemySingle,
    energy_cost: 5,
    casting_time_ms: 2200,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(Stun),
    status_duration_ms: 2000,
    status_value: 0,
  )
}

// Earth actions
fn rock_throw() -> ActionDef {
  ActionDef(
    slug: "rock_throw",
    display_name: "Rock Throw",
    element: Earth,
    target_rule: EnemySingle,
    energy_cost: 2,
    casting_time_ms: 1200,
    effect_kind: Damage,
    base_power: 18,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn earth_shield() -> ActionDef {
  ActionDef(
    slug: "earth_shield",
    display_name: "Earth Shield",
    element: Earth,
    target_rule: AllySingle,
    energy_cost: 4,
    casting_time_ms: 1500,
    effect_kind: Shield,
    base_power: 40,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn quake() -> ActionDef {
  ActionDef(
    slug: "quake",
    display_name: "Quake",
    element: Earth,
    target_rule: EnemySingle,
    energy_cost: 5,
    casting_time_ms: 2500,
    effect_kind: DamageAndStatus,
    base_power: 28,
    status_kind: Some(ShieldBuff),
    status_duration_ms: 4000,
    status_value: -12,
  )
}

fn stone_skin() -> ActionDef {
  ActionDef(
    slug: "stone_skin",
    display_name: "Stone Skin",
    element: Earth,
    target_rule: AllySingle,
    energy_cost: 3,
    casting_time_ms: 1200,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(ShieldBuff),
    status_duration_ms: 8000,
    status_value: 20,
  )
}

// Wind actions
fn wind_slash() -> ActionDef {
  ActionDef(
    slug: "wind_slash",
    display_name: "Wind Slash",
    element: Wind,
    target_rule: EnemySingle,
    energy_cost: 2,
    casting_time_ms: 800,
    effect_kind: Damage,
    base_power: 14,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn gust() -> ActionDef {
  ActionDef(
    slug: "gust",
    display_name: "Gust",
    element: Wind,
    target_rule: AllySingle,
    energy_cost: 3,
    casting_time_ms: 1000,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(AttackBuff),
    status_duration_ms: 5000,
    status_value: 12,
  )
}

fn lightning_strike() -> ActionDef {
  ActionDef(
    slug: "lightning_strike",
    display_name: "Lightning Strike",
    element: Wind,
    target_rule: EnemySingle,
    energy_cost: 4,
    casting_time_ms: 1400,
    effect_kind: Damage,
    base_power: 30,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn tailwind() -> ActionDef {
  ActionDef(
    slug: "tailwind",
    display_name: "Tailwind",
    element: Wind,
    target_rule: AllySingle,
    energy_cost: 3,
    casting_time_ms: 1000,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(AttackBuff),
    status_duration_ms: 6000,
    status_value: 15,
  )
}

// Light actions
fn heal() -> ActionDef {
  ActionDef(
    slug: "heal",
    display_name: "Heal",
    element: Light,
    target_rule: AllySingle,
    energy_cost: 3,
    casting_time_ms: 1500,
    effect_kind: Heal,
    base_power: 35,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn smite() -> ActionDef {
  ActionDef(
    slug: "smite",
    display_name: "Smite",
    element: Light,
    target_rule: EnemySingle,
    energy_cost: 3,
    casting_time_ms: 1500,
    effect_kind: Damage,
    base_power: 22,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn divine_shield() -> ActionDef {
  ActionDef(
    slug: "divine_shield",
    display_name: "Divine Shield",
    element: Light,
    target_rule: AllySingle,
    energy_cost: 4,
    casting_time_ms: 1200,
    effect_kind: Shield,
    base_power: 50,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn mass_heal() -> ActionDef {
  ActionDef(
    slug: "mass_heal",
    display_name: "Mass Heal",
    element: Light,
    target_rule: Self,
    energy_cost: 6,
    casting_time_ms: 3000,
    effect_kind: Heal,
    base_power: 55,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn bless() -> ActionDef {
  ActionDef(
    slug: "bless",
    display_name: "Bless",
    element: Light,
    target_rule: AllySingle,
    energy_cost: 4,
    casting_time_ms: 1400,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(AttackBuff),
    status_duration_ms: 6000,
    status_value: 15,
  )
}

fn judgment() -> ActionDef {
  ActionDef(
    slug: "judgment",
    display_name: "Judgment",
    element: Light,
    target_rule: EnemySingle,
    energy_cost: 6,
    casting_time_ms: 2800,
    effect_kind: Damage,
    base_power: 45,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

// Shadow actions
fn shadow_strike() -> ActionDef {
  ActionDef(
    slug: "shadow_strike",
    display_name: "Shadow Strike",
    element: Shadow,
    target_rule: EnemySingle,
    energy_cost: 3,
    casting_time_ms: 1200,
    effect_kind: Damage,
    base_power: 28,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn dark_bolt() -> ActionDef {
  ActionDef(
    slug: "dark_bolt",
    display_name: "Dark Bolt",
    element: Shadow,
    target_rule: EnemySingle,
    energy_cost: 4,
    casting_time_ms: 1800,
    effect_kind: DamageAndStatus,
    base_power: 24,
    status_kind: Some(AttackBuff),
    status_duration_ms: 5000,
    status_value: -8,
  )
}

fn curse() -> ActionDef {
  ActionDef(
    slug: "curse",
    display_name: "Curse",
    element: Shadow,
    target_rule: EnemySingle,
    energy_cost: 5,
    casting_time_ms: 2000,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(ShieldBuff),
    status_duration_ms: 6000,
    status_value: -15,
  )
}

fn life_drain() -> ActionDef {
  ActionDef(
    slug: "life_drain",
    display_name: "Life Drain",
    element: Shadow,
    target_rule: EnemySingle,
    energy_cost: 4,
    casting_time_ms: 1600,
    effect_kind: DamageAndStatus,
    base_power: 20,
    status_kind: Some(Hot),
    status_duration_ms: 4000,
    status_value: 8,
  )
}

fn dark_ritual() -> ActionDef {
  ActionDef(
    slug: "dark_ritual",
    display_name: "Dark Ritual",
    element: Shadow,
    target_rule: Self,
    energy_cost: 5,
    casting_time_ms: 2400,
    effect_kind: Heal,
    base_power: 40,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

// Basic actions
fn basic_attack() -> ActionDef {
  ActionDef(
    slug: "attack",
    display_name: "Attack",
    element: Earth,
    target_rule: EnemySingle,
    energy_cost: 0,
    casting_time_ms: 1000,
    effect_kind: Damage,
    base_power: 10,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn defend() -> ActionDef {
  ActionDef(
    slug: "defend",
    display_name: "Defend",
    element: Earth,
    target_rule: Self,
    energy_cost: 1,
    casting_time_ms: 500,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(ShieldBuff),
    status_duration_ms: 3000,
    status_value: 15,
  )
}

fn cleanse_action() -> ActionDef {
  ActionDef(
    slug: "cleanse",
    display_name: "Cleanse",
    element: Light,
    target_rule: AllySingle,
    energy_cost: 3,
    casting_time_ms: 1000,
    effect_kind: Cleanse,
    base_power: 0,
    status_kind: None,
    status_duration_ms: 0,
    status_value: 0,
  )
}

fn focus() -> ActionDef {
  ActionDef(
    slug: "focus",
    display_name: "Focus",
    element: Light,
    target_rule: Self,
    energy_cost: 2,
    casting_time_ms: 800,
    effect_kind: Status,
    base_power: 0,
    status_kind: Some(AttackBuff),
    status_duration_ms: 4000,
    status_value: 10,
  )
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
