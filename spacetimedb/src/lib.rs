use std::time::Duration;

use spacetimedb::{Identity, ReducerContext, ScheduleAt, Table, Timestamp};

const TEAM_PLAYER: u8 = 1;
const TEAM_ENEMY: u8 = 2;

const MATCH_PHASE_WAITING: u8 = 1;
const MATCH_PHASE_ACTIVE: u8 = 2;
const MATCH_PHASE_FINISHED: u8 = 3;

const HEROES_PER_TEAM: u8 = 3;
const HAND_SIZE: u8 = 5;
const ENERGY_MAX: u32 = 10;
const ENERGY_START: u32 = 10;
const ENERGY_REGEN_SECONDS: i64 = 1;
const REROLL_COST: u32 = 2;

const STATUS_FREEZE: &str = "freeze";
const STATUS_SLOW: &str = "slow";
const STATUS_SHIELD: &str = "shield";
const STATUS_HASTE: &str = "haste";
const STATUS_VULNERABLE: &str = "vulnerable";

#[derive(Clone)]
#[spacetimedb::table(accessor = player_profile, public)]
pub struct PlayerProfile {
    #[primary_key]
    identity: Identity,
    display_name: String,
    created_at: Timestamp,
    updated_at: Timestamp,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = matchmaking_queue, public)]
pub struct MatchmakingQueue {
    #[primary_key]
    queue_entry_id: u64,
    identity: Identity,
    hero_slug_1: String,
    hero_slug_2: String,
    hero_slug_3: String,
    queued_at: Timestamp,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = hero_def, public)]
pub struct HeroDef {
    #[primary_key]
    slug: String,
    display_name: String,
    max_hp: u32,
    attack: u32,
    defense: u32,
    fire_affinity: i32,
    ice_affinity: i32,
    earth_affinity: i32,
    wind_affinity: i32,
    light_affinity: i32,
    shadow_affinity: i32,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = action_def, public)]
pub struct ActionDef {
    #[primary_key]
    slug: String,
    display_name: String,
    element: String,
    target_rule: String,
    energy_cost: u32,
    casting_time_ms: u32,
    effect_kind: String,
    base_power: u32,
    status_kind: String,
    status_duration_ms: u32,
    status_value: i32,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = game_schedule, public, scheduled(tick_game))]
pub struct GameSchedule {
    #[primary_key]
    schedule_id: u64,
    scheduled_at: ScheduleAt,
    interval_ms: u64,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = game_match, public)]
pub struct GameMatch {
    #[primary_key]
    match_id: u64,
    phase: u8,
    created_at: Timestamp,
    started_at: Timestamp,
    winner_team: u8,
    next_random: u64,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = match_player, public)]
pub struct MatchPlayer {
    #[primary_key]
    player_id: u64,
    match_id: u64,
    identity: Identity,
    team: u8,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = match_team_state, public)]
pub struct MatchTeamState {
    #[primary_key]
    team_state_id: u64,
    match_id: u64,
    team: u8,
    energy: u32,
    energy_max: u32,
    last_energy_at: Timestamp,
    selected_caster_slot: u8,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = match_hero, public)]
pub struct MatchHero {
    #[primary_key]
    hero_instance_id: u64,
    match_id: u64,
    team: u8,
    slot_index: u8,
    hero_slug: String,
    hp_current: u32,
    hp_max: u32,
    alive: bool,
    busy_until: Timestamp,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = match_hand_slot, public)]
pub struct MatchHandSlot {
    #[primary_key]
    hand_slot_id: u64,
    match_id: u64,
    team: u8,
    slot_index: u8,
    action_slug: String,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = match_status, public)]
pub struct MatchStatus {
    #[primary_key]
    status_id: u64,
    match_id: u64,
    hero_instance_id: u64,
    kind: String,
    value: i32,
    expires_at: Timestamp,
}

#[derive(Clone)]
#[spacetimedb::table(accessor = match_cast, public)]
pub struct MatchCast {
    #[primary_key]
    cast_id: u64,
    match_id: u64,
    team: u8,
    caster_hero_instance_id: u64,
    target_hero_instance_id: u64,
    action_slug: String,
    started_at: Timestamp,
    resolves_at: Timestamp,
    resolved: bool,
}

#[spacetimedb::reducer(init)]
pub fn init(ctx: &ReducerContext) {
    seed_hero_defs(ctx);
    seed_action_defs(ctx);
    ensure_game_tick(ctx);
}

#[spacetimedb::reducer(client_connected)]
pub fn identity_connected(_ctx: &ReducerContext) {}

#[spacetimedb::reducer(client_disconnected)]
pub fn identity_disconnected(_ctx: &ReducerContext) {}

#[spacetimedb::reducer]
pub fn upsert_profile(ctx: &ReducerContext, display_name: String) -> Result<(), String> {
    let normalized = display_name.trim();
    if normalized.is_empty() {
        return Err("display name cannot be empty".into());
    }
    if normalized.len() > 32 {
        return Err("display name must be 32 characters or fewer".into());
    }

    if let Some(mut profile) = ctx.db.player_profile().identity().find(ctx.sender()) {
        profile.display_name = normalized.to_string();
        profile.updated_at = ctx.timestamp;
        ctx.db.player_profile().identity().update(profile);
    } else {
        ctx.db.player_profile().insert(PlayerProfile {
            identity: ctx.sender(),
            display_name: normalized.to_string(),
            created_at: ctx.timestamp,
            updated_at: ctx.timestamp,
        });
    }

    Ok(())
}

#[spacetimedb::reducer]
pub fn create_match(ctx: &ReducerContext) -> Result<(), String> {
    ensure_can_enter_new_match(ctx, ctx.sender())?;

    let match_id = next_match_id(ctx);
    let seed = mix_entropy(match_id, ctx.timestamp);

    ctx.db.game_match().insert(GameMatch {
        match_id,
        phase: MATCH_PHASE_WAITING,
        created_at: ctx.timestamp,
        started_at: ctx.timestamp,
        winner_team: 0,
        next_random: seed,
    });

    let player_id = next_player_id(ctx);
    ctx.db.match_player().insert(MatchPlayer {
        player_id,
        match_id,
        identity: ctx.sender(),
        team: TEAM_PLAYER,
    });

    insert_team_state(ctx, match_id, TEAM_PLAYER);
    insert_team_state(ctx, match_id, TEAM_ENEMY);

    Ok(())
}

#[spacetimedb::reducer]
pub fn join_match(
    ctx: &ReducerContext,
    match_id: u64,
    hero_slug_1: String,
    hero_slug_2: String,
    hero_slug_3: String,
) -> Result<(), String> {
    ensure_can_enter_new_match(ctx, ctx.sender())?;

    let game_match = get_match(ctx, match_id)?;
    if game_match.phase != MATCH_PHASE_WAITING {
        return Err("match is not accepting players".into());
    }

    if find_player_for_identity(ctx, match_id, ctx.sender()).is_some() {
        return Err("player already joined this match".into());
    }

    let team = if has_team_player(ctx, match_id, TEAM_PLAYER) {
        if has_team_player(ctx, match_id, TEAM_ENEMY) {
            return Err("match is full".into());
        }
        TEAM_ENEMY
    } else {
        TEAM_PLAYER
    };

    let heroes = [hero_slug_1, hero_slug_2, hero_slug_3];
    validate_hero_selection(ctx, &heroes)?;

    let player_id = next_player_id(ctx);
    ctx.db.match_player().insert(MatchPlayer {
        player_id,
        match_id,
        identity: ctx.sender(),
        team,
    });

    spawn_team_heroes(ctx, match_id, team, &heroes)?;
    reroll_hand_internal(ctx, match_id, team, false)?;

    if has_team_player(ctx, match_id, TEAM_PLAYER) && has_team_player(ctx, match_id, TEAM_ENEMY) {
        activate_match(ctx, match_id)?;
    }

    Ok(())
}

#[spacetimedb::reducer]
pub fn queue_for_matchmaking(
    ctx: &ReducerContext,
    hero_slug_1: String,
    hero_slug_2: String,
    hero_slug_3: String,
) -> Result<(), String> {
    require_profile(ctx, ctx.sender())?;
    ensure_can_enter_new_match(ctx, ctx.sender())?;
    if find_queue_entry_by_identity(ctx, ctx.sender()).is_some() {
        return Err("player is already in matchmaking".into());
    }

    let heroes = [hero_slug_1, hero_slug_2, hero_slug_3];
    validate_hero_selection(ctx, &heroes)?;

    if let Some(existing) = ctx
        .db
        .matchmaking_queue()
        .iter()
        .find(|entry| entry.identity != ctx.sender())
    {
        pair_matchmade_players(ctx, existing, heroes)?;
        return Ok(());
    }

    let queue_entry_id = next_queue_entry_id(ctx);
    ctx.db.matchmaking_queue().insert(MatchmakingQueue {
        queue_entry_id,
        identity: ctx.sender(),
        hero_slug_1: heroes[0].clone(),
        hero_slug_2: heroes[1].clone(),
        hero_slug_3: heroes[2].clone(),
        queued_at: ctx.timestamp,
    });

    Ok(())
}

#[spacetimedb::reducer]
pub fn leave_matchmaking(ctx: &ReducerContext) -> Result<(), String> {
    let entry = find_queue_entry_by_identity(ctx, ctx.sender())
        .ok_or_else(|| "player is not in matchmaking".to_string())?;
    ctx.db
        .matchmaking_queue()
        .queue_entry_id()
        .delete(entry.queue_entry_id);
    Ok(())
}

#[spacetimedb::reducer]
pub fn select_caster(ctx: &ReducerContext, match_id: u64, slot_index: u8) -> Result<(), String> {
    let team = require_player_team(ctx, match_id, ctx.sender())?;
    if slot_index == 0 || slot_index > HEROES_PER_TEAM {
        return Err("invalid caster slot".into());
    }

    let hero = get_match_hero_by_slot(ctx, match_id, team, slot_index)?;
    if !hero.alive {
        return Err("selected hero is dead".into());
    }

    let mut team_state = get_team_state(ctx, match_id, team)?;
    team_state.selected_caster_slot = slot_index;
    ctx.db.match_team_state().team_state_id().update(team_state);
    Ok(())
}

#[spacetimedb::reducer]
pub fn cast_action(
    ctx: &ReducerContext,
    match_id: u64,
    hand_slot_index: u8,
    target_slot: u8,
) -> Result<(), String> {
    let team = require_player_team(ctx, match_id, ctx.sender())?;
    let game_match = get_match(ctx, match_id)?;
    if game_match.phase != MATCH_PHASE_ACTIVE {
        return Err("match is not active".into());
    }

    let mut team_state = get_team_state(ctx, match_id, team)?;
    let selected_slot = team_state.selected_caster_slot;
    if selected_slot == 0 {
        return Err("no caster selected".into());
    }

    let mut caster = get_match_hero_by_slot(ctx, match_id, team, selected_slot)?;
    if !caster.alive {
        return Err("caster is dead".into());
    }
    if caster.busy_until > ctx.timestamp {
        return Err("caster is already casting".into());
    }

    let hand_slot = get_hand_slot(ctx, match_id, team, hand_slot_index)?;
    let action = get_action_def(ctx, &hand_slot.action_slug)?;
    if team_state.energy < action.energy_cost {
        return Err("not enough energy".into());
    }

    let target_team = target_rule_team(team, &action.target_rule)?;
    let target = get_match_hero_by_slot(ctx, match_id, target_team, target_slot)?;
    if !target.alive {
        return Err("target is dead".into());
    }

    team_state.energy -= action.energy_cost;
    ctx.db.match_team_state().team_state_id().update(team_state);

    let resolves_at = ctx.timestamp + Duration::from_millis(action.casting_time_ms as u64);
    caster.busy_until = resolves_at;
    ctx.db
        .match_hero()
        .hero_instance_id()
        .update(caster.clone());

    let cast_id = next_cast_id(ctx);
    ctx.db.match_cast().insert(MatchCast {
        cast_id,
        match_id,
        team,
        caster_hero_instance_id: caster.hero_instance_id,
        target_hero_instance_id: target.hero_instance_id,
        action_slug: action.slug,
        started_at: ctx.timestamp,
        resolves_at,
        resolved: false,
    });

    Ok(())
}

#[spacetimedb::reducer]
pub fn reroll_hand(ctx: &ReducerContext, match_id: u64) -> Result<(), String> {
    let team = require_player_team(ctx, match_id, ctx.sender())?;
    reroll_hand_internal(ctx, match_id, team, true)
}

#[spacetimedb::reducer]
pub fn tick_game(ctx: &ReducerContext, arg: GameSchedule) -> Result<(), String> {
    if ctx.sender() != ctx.identity() {
        return Err("tick_game is reserved for the scheduler".into());
    }

    for game_match in ctx.db.game_match().iter() {
        if game_match.phase != MATCH_PHASE_ACTIVE {
            continue;
        }

        regen_team_energy(ctx, game_match.match_id, TEAM_PLAYER)?;
        regen_team_energy(ctx, game_match.match_id, TEAM_ENEMY)?;
        expire_statuses(ctx, game_match.match_id);
        resolve_finished_casts(ctx, game_match.match_id)?;
        check_winner(ctx, game_match.match_id)?;
    }

    let mut next_row = arg;
    next_row.scheduled_at =
        ScheduleAt::Time(ctx.timestamp + Duration::from_millis(next_row.interval_ms));
    ctx.db.game_schedule().schedule_id().update(next_row);
    Ok(())
}

fn seed_hero_defs(ctx: &ReducerContext) {
    if ctx.db.hero_def().iter().next().is_some() {
        return;
    }

    for hero in [
        HeroDef {
            slug: "arcane-paladin".into(),
            display_name: "Arcane Paladin".into(),
            max_hp: 3200,
            attack: 145,
            defense: 145,
            fire_affinity: -20,
            ice_affinity: 0,
            earth_affinity: 10,
            wind_affinity: -10,
            light_affinity: 20,
            shadow_affinity: 15,
        },
        HeroDef {
            slug: "earth-warden".into(),
            display_name: "Earth Warden".into(),
            max_hp: 3600,
            attack: 120,
            defense: 170,
            fire_affinity: 0,
            ice_affinity: 0,
            earth_affinity: 30,
            wind_affinity: -15,
            light_affinity: 5,
            shadow_affinity: -5,
        },
        HeroDef {
            slug: "dawn-priest".into(),
            display_name: "Dawn Priest".into(),
            max_hp: 2900,
            attack: 130,
            defense: 120,
            fire_affinity: 0,
            ice_affinity: 5,
            earth_affinity: 0,
            wind_affinity: 10,
            light_affinity: 30,
            shadow_affinity: -20,
        },
        HeroDef {
            slug: "frost-queen".into(),
            display_name: "Frost Queen".into(),
            max_hp: 3000,
            attack: 150,
            defense: 125,
            fire_affinity: -25,
            ice_affinity: 30,
            earth_affinity: 0,
            wind_affinity: 5,
            light_affinity: 0,
            shadow_affinity: 5,
        },
        HeroDef {
            slug: "flame-warlock".into(),
            display_name: "Flame Warlock".into(),
            max_hp: 2850,
            attack: 160,
            defense: 110,
            fire_affinity: 30,
            ice_affinity: -20,
            earth_affinity: -5,
            wind_affinity: 10,
            light_affinity: 0,
            shadow_affinity: 5,
        },
        HeroDef {
            slug: "night-venom".into(),
            display_name: "Night Venom".into(),
            max_hp: 2750,
            attack: 155,
            defense: 115,
            fire_affinity: 0,
            ice_affinity: 0,
            earth_affinity: -10,
            wind_affinity: 10,
            light_affinity: -25,
            shadow_affinity: 30,
        },
    ] {
        ctx.db.hero_def().insert(hero);
    }
}

fn seed_action_defs(ctx: &ReducerContext) {
    if ctx.db.action_def().iter().next().is_some() {
        return;
    }

    for action in [
        ActionDef {
            slug: "firebolt".into(),
            display_name: "Firebolt".into(),
            element: "fire".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 3,
            casting_time_ms: 400,
            effect_kind: "damage".into(),
            base_power: 28,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "flame-burst".into(),
            display_name: "Flame Burst".into(),
            element: "fire".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 5,
            casting_time_ms: 800,
            effect_kind: "damage".into(),
            base_power: 44,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "frostbind".into(),
            display_name: "Frostbind".into(),
            element: "ice".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 3,
            casting_time_ms: 500,
            effect_kind: "damage_and_status".into(),
            base_power: 20,
            status_kind: STATUS_FREEZE.into(),
            status_duration_ms: 900,
            status_value: 1,
        },
        ActionDef {
            slug: "ice-lance".into(),
            display_name: "Ice Lance".into(),
            element: "ice".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 2,
            casting_time_ms: 300,
            effect_kind: "damage".into(),
            base_power: 18,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "stoneguard".into(),
            display_name: "Stoneguard".into(),
            element: "earth".into(),
            target_rule: "ally_single".into(),
            energy_cost: 3,
            casting_time_ms: 400,
            effect_kind: "shield".into(),
            base_power: 32,
            status_kind: STATUS_SHIELD.into(),
            status_duration_ms: 6000,
            status_value: 32,
        },
        ActionDef {
            slug: "quake".into(),
            display_name: "Quake".into(),
            element: "earth".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 5,
            casting_time_ms: 1000,
            effect_kind: "damage".into(),
            base_power: 34,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "guststep".into(),
            display_name: "Guststep".into(),
            element: "wind".into(),
            target_rule: "ally_single".into(),
            energy_cost: 2,
            casting_time_ms: 200,
            effect_kind: "status".into(),
            base_power: 0,
            status_kind: STATUS_HASTE.into(),
            status_duration_ms: 2000,
            status_value: 20,
        },
        ActionDef {
            slug: "cyclone-cut".into(),
            display_name: "Cyclone Cut".into(),
            element: "wind".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 4,
            casting_time_ms: 500,
            effect_kind: "damage".into(),
            base_power: 24,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "radiant-mend".into(),
            display_name: "Radiant Mend".into(),
            element: "light".into(),
            target_rule: "ally_single".into(),
            energy_cost: 3,
            casting_time_ms: 600,
            effect_kind: "heal".into(),
            base_power: 26,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "purify".into(),
            display_name: "Purify".into(),
            element: "light".into(),
            target_rule: "ally_single".into(),
            energy_cost: 2,
            casting_time_ms: 300,
            effect_kind: "cleanse".into(),
            base_power: 0,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "night-strike".into(),
            display_name: "Night Strike".into(),
            element: "shadow".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 3,
            casting_time_ms: 300,
            effect_kind: "damage".into(),
            base_power: 30,
            status_kind: "".into(),
            status_duration_ms: 0,
            status_value: 0,
        },
        ActionDef {
            slug: "hex-mark".into(),
            display_name: "Hex Mark".into(),
            element: "shadow".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 4,
            casting_time_ms: 500,
            effect_kind: "status".into(),
            base_power: 0,
            status_kind: STATUS_VULNERABLE.into(),
            status_duration_ms: 3000,
            status_value: 20,
        },
        ActionDef {
            slug: "rootsnare".into(),
            display_name: "Rootsnare".into(),
            element: "earth".into(),
            target_rule: "enemy_single".into(),
            energy_cost: 3,
            casting_time_ms: 600,
            effect_kind: "damage_and_status".into(),
            base_power: 12,
            status_kind: STATUS_SLOW.into(),
            status_duration_ms: 2000,
            status_value: 35,
        },
    ] {
        ctx.db.action_def().insert(action);
    }
}

fn ensure_game_tick(ctx: &ReducerContext) {
    if ctx.db.game_schedule().iter().next().is_some() {
        return;
    }

    ctx.db.game_schedule().insert(GameSchedule {
        schedule_id: 1,
        scheduled_at: ScheduleAt::Time(ctx.timestamp + Duration::from_millis(200)),
        interval_ms: 200,
    });
}

fn activate_match(ctx: &ReducerContext, match_id: u64) -> Result<(), String> {
    let mut game_match = get_match(ctx, match_id)?;
    game_match.phase = MATCH_PHASE_ACTIVE;
    game_match.started_at = ctx.timestamp;
    ctx.db.game_match().match_id().update(game_match);
    Ok(())
}

fn pair_matchmade_players(
    ctx: &ReducerContext,
    existing: MatchmakingQueue,
    joining_heroes: [String; 3],
) -> Result<(), String> {
    let existing_heroes = [
        existing.hero_slug_1.clone(),
        existing.hero_slug_2.clone(),
        existing.hero_slug_3.clone(),
    ];

    let match_id = next_match_id(ctx);
    let seed = mix_entropy(match_id, ctx.timestamp);
    ctx.db.game_match().insert(GameMatch {
        match_id,
        phase: MATCH_PHASE_WAITING,
        created_at: ctx.timestamp,
        started_at: ctx.timestamp,
        winner_team: 0,
        next_random: seed,
    });

    insert_team_state(ctx, match_id, TEAM_PLAYER);
    insert_team_state(ctx, match_id, TEAM_ENEMY);

    add_player_to_match(ctx, match_id, existing.identity, TEAM_PLAYER);
    add_player_to_match(ctx, match_id, ctx.sender(), TEAM_ENEMY);

    spawn_team_heroes(ctx, match_id, TEAM_PLAYER, &existing_heroes)?;
    spawn_team_heroes(ctx, match_id, TEAM_ENEMY, &joining_heroes)?;
    reroll_hand_internal(ctx, match_id, TEAM_PLAYER, false)?;
    reroll_hand_internal(ctx, match_id, TEAM_ENEMY, false)?;
    activate_match(ctx, match_id)?;

    ctx.db
        .matchmaking_queue()
        .queue_entry_id()
        .delete(existing.queue_entry_id);

    Ok(())
}

fn insert_team_state(ctx: &ReducerContext, match_id: u64, team: u8) {
    let team_state_id = next_team_state_id(ctx);
    ctx.db.match_team_state().insert(MatchTeamState {
        team_state_id,
        match_id,
        team,
        energy: ENERGY_START,
        energy_max: ENERGY_MAX,
        last_energy_at: ctx.timestamp,
        selected_caster_slot: 0,
    });
}

fn add_player_to_match(ctx: &ReducerContext, match_id: u64, identity: Identity, team: u8) {
    let player_id = next_player_id(ctx);
    ctx.db.match_player().insert(MatchPlayer {
        player_id,
        match_id,
        identity,
        team,
    });
}

fn validate_hero_selection(ctx: &ReducerContext, heroes: &[String; 3]) -> Result<(), String> {
    for hero_slug in heroes {
        get_hero_def(ctx, hero_slug)?;
    }
    Ok(())
}

fn spawn_team_heroes(
    ctx: &ReducerContext,
    match_id: u64,
    team: u8,
    heroes: &[String; 3],
) -> Result<(), String> {
    for (index, hero_slug) in heroes.iter().enumerate() {
        let hero_def = get_hero_def(ctx, hero_slug)?;
        let hero_instance_id = next_hero_instance_id(ctx);
        ctx.db.match_hero().insert(MatchHero {
            hero_instance_id,
            match_id,
            team,
            slot_index: (index as u8) + 1,
            hero_slug: hero_def.slug,
            hp_current: hero_def.max_hp,
            hp_max: hero_def.max_hp,
            alive: true,
            busy_until: ctx.timestamp,
        });
    }
    Ok(())
}

fn reroll_hand_internal(
    ctx: &ReducerContext,
    match_id: u64,
    team: u8,
    charge_energy: bool,
) -> Result<(), String> {
    let mut team_state = get_team_state(ctx, match_id, team)?;
    if charge_energy {
        if team_state.energy < REROLL_COST {
            return Err("not enough energy to reroll".into());
        }
        team_state.energy -= REROLL_COST;
        ctx.db
            .match_team_state()
            .team_state_id()
            .update(team_state.clone());
    }

    let action_count = ctx.db.action_def().iter().count() as u64;
    if action_count == 0 {
        return Err("no action definitions available".into());
    }

    let existing_slots: Vec<_> = ctx
        .db
        .match_hand_slot()
        .iter()
        .filter(|slot| slot.match_id == match_id && slot.team == team)
        .collect();
    for slot in existing_slots {
        ctx.db
            .match_hand_slot()
            .hand_slot_id()
            .delete(slot.hand_slot_id);
    }

    let mut game_match = get_match(ctx, match_id)?;
    let actions: Vec<_> = ctx.db.action_def().iter().collect();
    for slot_index in 1..=HAND_SIZE {
        let random_index = random_index(&mut game_match.next_random, action_count) as usize;
        let hand_slot_id = next_hand_slot_id(ctx);
        ctx.db.match_hand_slot().insert(MatchHandSlot {
            hand_slot_id,
            match_id,
            team,
            slot_index,
            action_slug: actions[random_index].slug.clone(),
        });
    }

    ctx.db.game_match().match_id().update(game_match);
    Ok(())
}

fn regen_team_energy(ctx: &ReducerContext, match_id: u64, team: u8) -> Result<(), String> {
    let mut team_state = get_team_state(ctx, match_id, team)?;
    let elapsed = ctx
        .timestamp
        .duration_since(team_state.last_energy_at)
        .unwrap_or_default()
        .as_secs() as i64;
    if elapsed < ENERGY_REGEN_SECONDS {
        return Ok(());
    }

    let gain = (elapsed / ENERGY_REGEN_SECONDS) as u32;
    team_state.energy = (team_state.energy + gain).min(team_state.energy_max);
    team_state.last_energy_at = team_state.last_energy_at
        + Duration::from_secs((gain as i64 * ENERGY_REGEN_SECONDS) as u64);
    ctx.db.match_team_state().team_state_id().update(team_state);
    Ok(())
}

fn expire_statuses(ctx: &ReducerContext, match_id: u64) {
    let statuses: Vec<_> = ctx
        .db
        .match_status()
        .iter()
        .filter(|status| status.match_id == match_id && status.expires_at <= ctx.timestamp)
        .collect();
    for status in statuses {
        ctx.db.match_status().status_id().delete(status.status_id);
    }
}

fn resolve_finished_casts(ctx: &ReducerContext, match_id: u64) -> Result<(), String> {
    let casts: Vec<_> = ctx
        .db
        .match_cast()
        .iter()
        .filter(|cast| {
            cast.match_id == match_id && !cast.resolved && cast.resolves_at <= ctx.timestamp
        })
        .collect();

    for mut cast in casts {
        resolve_cast(ctx, &cast)?;
        cast.resolved = true;
        ctx.db.match_cast().cast_id().update(cast);
    }

    Ok(())
}

fn resolve_cast(ctx: &ReducerContext, cast: &MatchCast) -> Result<(), String> {
    let caster = get_match_hero_by_id(ctx, cast.caster_hero_instance_id)?;
    if !caster.alive {
        return Ok(());
    }

    let target = get_match_hero_by_id(ctx, cast.target_hero_instance_id)?;
    if !target.alive {
        return Ok(());
    }

    let action = get_action_def(ctx, &cast.action_slug)?;
    match action.effect_kind.as_str() {
        "damage" => apply_damage(ctx, &caster, &target, &action)?,
        "heal" => apply_heal(ctx, &caster, &target, &action)?,
        "shield" => apply_status_only(ctx, &target, &action)?,
        "status" => apply_status_only(ctx, &target, &action)?,
        "damage_and_status" => {
            apply_damage(ctx, &caster, &target, &action)?;
            let refreshed_target = get_match_hero_by_id(ctx, target.hero_instance_id)?;
            if refreshed_target.alive {
                apply_status_only(ctx, &refreshed_target, &action)?;
            }
        }
        "cleanse" => apply_cleanse(ctx, &target),
        _ => return Err("unknown effect kind".into()),
    }

    Ok(())
}

fn apply_damage(
    ctx: &ReducerContext,
    caster: &MatchHero,
    target: &MatchHero,
    action: &ActionDef,
) -> Result<(), String> {
    let caster_def = get_hero_def(ctx, &caster.hero_slug)?;
    let target_def = get_hero_def(ctx, &target.hero_slug)?;

    let outgoing = 100 + affinity_for(&caster_def, &action.element);
    let incoming = 100 - affinity_for(&target_def, &action.element)
        + vulnerable_bonus(ctx, target.hero_instance_id);
    let damage = ((action.base_power as i64) * (caster_def.attack as i64) * outgoing as i64 * 100)
        / 100
        / 100
        / (100 + target_def.defense as i64)
        * incoming as i64
        / 100;

    let final_damage = damage.max(1) as u32;
    let shield_value = active_shield_value(ctx, target.hero_instance_id);
    let unblocked = final_damage.saturating_sub(shield_value);

    if shield_value > 0 {
        consume_shield(ctx, target.hero_instance_id, final_damage as i32);
    }

    if unblocked == 0 {
        return Ok(());
    }

    let mut updated = get_match_hero_by_id(ctx, target.hero_instance_id)?;
    if updated.hp_current <= unblocked {
        updated.hp_current = 0;
        updated.alive = false;
    } else {
        updated.hp_current -= unblocked;
    }
    ctx.db.match_hero().hero_instance_id().update(updated);
    Ok(())
}

fn apply_heal(
    ctx: &ReducerContext,
    caster: &MatchHero,
    target: &MatchHero,
    action: &ActionDef,
) -> Result<(), String> {
    let caster_def = get_hero_def(ctx, &caster.hero_slug)?;
    let mut updated = get_match_hero_by_id(ctx, target.hero_instance_id)?;
    let amount = ((action.base_power as u64) * (caster_def.attack as u64) / 100) as u32;
    updated.hp_current = (updated.hp_current + amount).min(updated.hp_max);
    ctx.db.match_hero().hero_instance_id().update(updated);
    Ok(())
}

fn apply_status_only(
    ctx: &ReducerContext,
    target: &MatchHero,
    action: &ActionDef,
) -> Result<(), String> {
    if action.status_kind.is_empty() {
        return Ok(());
    }

    let status_id = next_status_id(ctx);
    ctx.db.match_status().insert(MatchStatus {
        status_id,
        match_id: target.match_id,
        hero_instance_id: target.hero_instance_id,
        kind: action.status_kind.clone(),
        value: action.status_value,
        expires_at: ctx.timestamp + Duration::from_millis(action.status_duration_ms as u64),
    });
    Ok(())
}

fn apply_cleanse(ctx: &ReducerContext, target: &MatchHero) {
    let statuses: Vec<_> = ctx
        .db
        .match_status()
        .iter()
        .filter(|status| {
            status.hero_instance_id == target.hero_instance_id
                && (status.kind == STATUS_FREEZE
                    || status.kind == STATUS_SLOW
                    || status.kind == STATUS_VULNERABLE)
        })
        .collect();
    for status in statuses {
        ctx.db.match_status().status_id().delete(status.status_id);
    }
}

fn active_shield_value(ctx: &ReducerContext, hero_instance_id: u64) -> u32 {
    ctx.db
        .match_status()
        .iter()
        .filter(|status| {
            status.hero_instance_id == hero_instance_id && status.kind == STATUS_SHIELD
        })
        .map(|status| status.value.max(0) as u32)
        .sum()
}

fn consume_shield(ctx: &ReducerContext, hero_instance_id: u64, damage: i32) {
    let mut remaining = damage.max(0);
    let statuses: Vec<_> = ctx
        .db
        .match_status()
        .iter()
        .filter(|status| {
            status.hero_instance_id == hero_instance_id && status.kind == STATUS_SHIELD
        })
        .collect();

    for mut status in statuses {
        if remaining <= 0 {
            break;
        }

        if status.value <= remaining {
            remaining -= status.value.max(0);
            ctx.db.match_status().status_id().delete(status.status_id);
        } else {
            status.value -= remaining;
            remaining = 0;
            ctx.db.match_status().status_id().update(status);
        }
    }
}

fn vulnerable_bonus(ctx: &ReducerContext, hero_instance_id: u64) -> i32 {
    ctx.db
        .match_status()
        .iter()
        .filter(|status| {
            status.hero_instance_id == hero_instance_id && status.kind == STATUS_VULNERABLE
        })
        .map(|status| status.value.max(0))
        .sum()
}

fn check_winner(ctx: &ReducerContext, match_id: u64) -> Result<(), String> {
    let player_alive = team_has_living_heroes(ctx, match_id, TEAM_PLAYER);
    let enemy_alive = team_has_living_heroes(ctx, match_id, TEAM_ENEMY);

    if player_alive && enemy_alive {
        return Ok(());
    }

    let mut game_match = get_match(ctx, match_id)?;
    game_match.phase = MATCH_PHASE_FINISHED;
    game_match.winner_team = if player_alive {
        TEAM_PLAYER
    } else {
        TEAM_ENEMY
    };
    ctx.db.game_match().match_id().update(game_match);
    Ok(())
}

fn team_has_living_heroes(ctx: &ReducerContext, match_id: u64, team: u8) -> bool {
    ctx.db
        .match_hero()
        .iter()
        .any(|hero| hero.match_id == match_id && hero.team == team && hero.alive)
}

fn target_rule_team(caster_team: u8, target_rule: &str) -> Result<u8, String> {
    match target_rule {
        "ally_single" | "self" => Ok(caster_team),
        "enemy_single" => Ok(opposing_team(caster_team)),
        _ => Err("unsupported target rule".into()),
    }
}

fn opposing_team(team: u8) -> u8 {
    if team == TEAM_PLAYER {
        TEAM_ENEMY
    } else {
        TEAM_PLAYER
    }
}

fn affinity_for(hero: &HeroDef, element: &str) -> i32 {
    match element {
        "fire" => hero.fire_affinity,
        "ice" => hero.ice_affinity,
        "earth" => hero.earth_affinity,
        "wind" => hero.wind_affinity,
        "light" => hero.light_affinity,
        "shadow" => hero.shadow_affinity,
        _ => 0,
    }
}

fn require_player_team(
    ctx: &ReducerContext,
    match_id: u64,
    identity: Identity,
) -> Result<u8, String> {
    find_player_for_identity(ctx, match_id, identity)
        .map(|player| player.team)
        .ok_or_else(|| "player is not part of this match".into())
}

fn require_profile(ctx: &ReducerContext, identity: Identity) -> Result<PlayerProfile, String> {
    ctx.db
        .player_profile()
        .identity()
        .find(identity)
        .ok_or_else(|| "player profile not found; call upsert_profile first".into())
}

fn ensure_can_enter_new_match(ctx: &ReducerContext, identity: Identity) -> Result<(), String> {
    if find_queue_entry_by_identity(ctx, identity).is_some() {
        return Err("player is already queued for matchmaking".into());
    }

    let in_open_or_active_match = ctx.db.match_player().iter().any(|player| {
        player.identity == identity
            && ctx
                .db
                .game_match()
                .match_id()
                .find(player.match_id)
                .map(|game_match| game_match.phase != MATCH_PHASE_FINISHED)
                .unwrap_or(false)
    });

    if in_open_or_active_match {
        return Err("player is already in an unfinished match".into());
    }

    Ok(())
}

fn find_player_for_identity(
    ctx: &ReducerContext,
    match_id: u64,
    identity: Identity,
) -> Option<MatchPlayer> {
    ctx.db
        .match_player()
        .iter()
        .find(|player| player.match_id == match_id && player.identity == identity)
}

fn find_queue_entry_by_identity(
    ctx: &ReducerContext,
    identity: Identity,
) -> Option<MatchmakingQueue> {
    ctx.db
        .matchmaking_queue()
        .iter()
        .find(|entry| entry.identity == identity)
}

fn has_team_player(ctx: &ReducerContext, match_id: u64, team: u8) -> bool {
    ctx.db
        .match_player()
        .iter()
        .any(|player| player.match_id == match_id && player.team == team)
}

fn get_match(ctx: &ReducerContext, match_id: u64) -> Result<GameMatch, String> {
    ctx.db
        .game_match()
        .match_id()
        .find(match_id)
        .ok_or_else(|| "match not found".into())
}

fn get_team_state(ctx: &ReducerContext, match_id: u64, team: u8) -> Result<MatchTeamState, String> {
    ctx.db
        .match_team_state()
        .iter()
        .find(|state| state.match_id == match_id && state.team == team)
        .ok_or_else(|| "team state not found".into())
}

fn get_match_hero_by_slot(
    ctx: &ReducerContext,
    match_id: u64,
    team: u8,
    slot_index: u8,
) -> Result<MatchHero, String> {
    ctx.db
        .match_hero()
        .iter()
        .find(|hero| {
            hero.match_id == match_id && hero.team == team && hero.slot_index == slot_index
        })
        .ok_or_else(|| "hero slot not found".into())
}

fn get_match_hero_by_id(ctx: &ReducerContext, hero_instance_id: u64) -> Result<MatchHero, String> {
    ctx.db
        .match_hero()
        .hero_instance_id()
        .find(hero_instance_id)
        .ok_or_else(|| "hero not found".into())
}

fn get_hand_slot(
    ctx: &ReducerContext,
    match_id: u64,
    team: u8,
    slot_index: u8,
) -> Result<MatchHandSlot, String> {
    if slot_index == 0 || slot_index > HAND_SIZE {
        return Err("invalid hand slot".into());
    }

    ctx.db
        .match_hand_slot()
        .iter()
        .find(|slot| {
            slot.match_id == match_id && slot.team == team && slot.slot_index == slot_index
        })
        .ok_or_else(|| "hand slot not found".into())
}

fn get_hero_def(ctx: &ReducerContext, slug: &str) -> Result<HeroDef, String> {
    ctx.db
        .hero_def()
        .slug()
        .find(slug.to_string())
        .ok_or_else(|| format!("unknown hero slug: {slug}"))
}

fn get_action_def(ctx: &ReducerContext, slug: &str) -> Result<ActionDef, String> {
    ctx.db
        .action_def()
        .slug()
        .find(slug.to_string())
        .ok_or_else(|| format!("unknown action slug: {slug}"))
}

fn next_match_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.game_match().iter().count() as u64) + 1
}

fn next_player_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.match_player().iter().count() as u64) + 1
}

fn next_team_state_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.match_team_state().iter().count() as u64) + 1
}

fn next_hero_instance_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.match_hero().iter().count() as u64) + 1
}

fn next_hand_slot_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.match_hand_slot().iter().count() as u64) + 1
}

fn next_cast_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.match_cast().iter().count() as u64) + 1
}

fn next_status_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.match_status().iter().count() as u64) + 1
}

fn next_queue_entry_id(ctx: &ReducerContext) -> u64 {
    (ctx.db.matchmaking_queue().iter().count() as u64) + 1
}

fn mix_entropy(seed: u64, timestamp: Timestamp) -> u64 {
    seed ^ (timestamp.to_micros_since_unix_epoch() as u64).wrapping_mul(6364136223846793005)
}

fn random_index(seed: &mut u64, count: u64) -> u64 {
    *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
    *seed % count.max(1)
}
