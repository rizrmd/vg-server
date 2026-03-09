# vg-server

SpaceTimeDB authoritative server for the Vanguard's Gambit PvP card battler.

## Scope

This repo owns player registration, matchmaking, match state, and combat rules.

- `triarc-slice/` is a git submodule and is not modified by this server.
- `spacetimedb/` contains the Rust module.
- The server is authoritative for energy, casting, rerolls, damage, status effects, and victory.

## Tooling

Rust is configured through `mise`.

```bash
mise x -- cargo check
spacetime build --module-path spacetimedb
```

## Docker

Build the server image:

```bash
docker build -t vg-server .
```

Run the local standalone SpaceTimeDB server and publish the module into it:

```bash
docker run --rm -p 3000:3000 vg-server
```

Useful environment variables:

- `SPACETIME_HOST=127.0.0.1`
- `SPACETIME_PORT=3000`
- `SPACETIME_LISTEN_ADDR=0.0.0.0:3000`
- `SPACETIME_DATA_DIR=/var/lib/spacetimedb`
- `SPACETIME_DB_NAME=vg-server`
- `SPACETIME_PUBLISH_SERVER=http://127.0.0.1:3000`
- `SPACETIME_DELETE_DATA_ON_START=0`

Example with persistent data:

```bash
docker run --rm \
  -p 3000:3000 \
  -v vg-server-data:/var/lib/spacetimedb \
  -e SPACETIME_DB_NAME=vg-server \
  vg-server
```

## Current Rules

- 2 teams per match
- 3 heroes per team
- shared visible hand of 5 action cards
- any alive hero can cast any visible card
- no cooldowns
- each card has a cast time
- shared team energy
- `max energy = 10`
- `start energy = 10`
- `regen = 1 energy / second`
- `reroll cost = 2 energy`
- reroll replaces the whole hand with 5 random actions from the global server action pool

## Player Flow

There are now two supported ways to enter a game:

1. Manual rooms
   - `create_match()`
   - `join_match(match_id, hero_slug_1, hero_slug_2, hero_slug_3)`
2. Matchmaking
   - `upsert_profile(display_name)`
   - `queue_for_matchmaking(hero_slug_1, hero_slug_2, hero_slug_3)`
   - automatic pairing into a live match
   - `leave_matchmaking()` if the player wants to cancel before a match is made

## Module Layout

- [`spacetimedb/src/lib.rs`](/home/riz/vg-server/spacetimedb/src/lib.rs): schema, seeded content, reducers, tick loop
- [`spacetimedb/Cargo.toml`](/home/riz/vg-server/spacetimedb/Cargo.toml): SpaceTimeDB Rust module crate
- [`spacetime.json`](/home/riz/vg-server/spacetime.json): project config

## Tables

Content tables:

- `hero_def`
- `action_def`

Runtime tables:

- `player_profile`
- `matchmaking_queue`
- `game_match`
- `match_player`
- `match_team_state`
- `match_hero`
- `match_hand_slot`
- `match_status`
- `match_cast`
- `game_schedule`

### `hero_def`

Server-side hero rules keyed by slug.

Fields:

- `slug`
- `display_name`
- `max_hp`
- `attack`
- `defense`
- `fire_affinity`
- `ice_affinity`
- `earth_affinity`
- `wind_affinity`
- `light_affinity`
- `shadow_affinity`

### `action_def`

Server-side action rules keyed by slug.

Fields:

- `slug`
- `display_name`
- `element`
- `target_rule`
- `energy_cost`
- `casting_time_ms`
- `effect_kind`
- `base_power`
- `status_kind`
- `status_duration_ms`
- `status_value`

Supported `target_rule` values right now:

- `ally_single`
- `enemy_single`
- `self`

Supported `effect_kind` values right now:

- `damage`
- `heal`
- `shield`
- `status`
- `damage_and_status`
- `cleanse`

### `player_profile`

Player registration/profile keyed by SpaceTimeDB identity.

Fields:

- `identity`
- `display_name`
- `created_at`
- `updated_at`

### `matchmaking_queue`

Queued matchmaking entries. Hero selection is captured at queue time.

Fields:

- `queue_entry_id`
- `identity`
- `hero_slug_1`
- `hero_slug_2`
- `hero_slug_3`
- `queued_at`

### `game_match`

One row per match.

Fields:

- `match_id`
- `phase`
  - `1 = waiting`
  - `2 = active`
  - `3 = finished`
- `created_at`
- `started_at`
- `winner_team`
  - `0 = none`
  - `1 = player team`
  - `2 = enemy team`
- `next_random`

### `match_player`

Maps a connected SpaceTimeDB identity into a match team.

Fields:

- `player_id`
- `match_id`
- `identity`
- `team`

### `match_team_state`

Shared team runtime state.

Fields:

- `team_state_id`
- `match_id`
- `team`
- `energy`
- `energy_max`
- `last_energy_at`
- `selected_caster_slot`

### `match_hero`

Spawned match-local hero instance.

Fields:

- `hero_instance_id`
- `match_id`
- `team`
- `slot_index`
- `hero_slug`
- `hp_current`
- `hp_max`
- `alive`
- `busy_until`

### `match_hand_slot`

One visible action slot in the team hand.

Fields:

- `hand_slot_id`
- `match_id`
- `team`
- `slot_index`
- `action_slug`

### `match_status`

Active timed status on a specific hero instance.

Fields:

- `status_id`
- `match_id`
- `hero_instance_id`
- `kind`
- `value`
- `expires_at`

### `match_cast`

In-flight cast created when a hero starts channeling a card.

Fields:

- `cast_id`
- `match_id`
- `team`
- `caster_hero_instance_id`
- `target_hero_instance_id`
- `action_slug`
- `started_at`
- `resolves_at`
- `resolved`

## Reducers

### `upsert_profile(display_name)`

Creates or updates the caller's player profile.

Rules:

- display name must be non-empty
- display name max length is 32

### `create_match()`

Creates a waiting match and inserts the calling identity as team `1`.

Important:

- SpaceTimeDB reducers do not return values.
- The client should discover the created match by subscribing to `game_match` and `match_player`, then finding the row tied to its own identity.
- the player cannot already be queued or inside an unfinished match

### `join_match(match_id, hero_slug_1, hero_slug_2, hero_slug_3)`

Joins the waiting match as the next open team, validates the 3 hero slugs, spawns heroes, rolls a starting hand, and starts the match once both teams are present.

Rules:

- the player cannot already be queued or inside an unfinished match
- hero selection happens here for manual rooms

### `queue_for_matchmaking(hero_slug_1, hero_slug_2, hero_slug_3)`

Queues the player for automatic 1v1 matchmaking.

Rules:

- player must have a `player_profile`
- player cannot already be queued
- player cannot already be inside an unfinished match
- the 3 submitted heroes are validated immediately

Behavior:

- if no opponent is queued, a `matchmaking_queue` row is inserted
- if an opponent is already queued, the server creates a match immediately, assigns teams, spawns both hero squads, rolls both hands, starts the match, and removes the older queue entry

### `leave_matchmaking()`

Removes the caller from the matchmaking queue.

### `select_caster(match_id, slot_index)`

Sets the active casting hero for the caller's team.

Rules:

- slot must be `1..=3`
- hero must be alive

### `cast_action(match_id, hand_slot_index, target_slot)`

Starts a cast using the currently selected caster.

Validation:

- caller must belong to the match
- match must be active
- caster must be selected
- caster must be alive
- caster must not already be busy
- enough team energy must exist
- target must match the action target rule
- target must be alive

Resolution:

- energy is spent immediately
- a `match_cast` row is inserted
- caster is marked busy until the cast resolves
- the tick reducer applies the effect when `resolves_at` is reached

### `reroll_hand(match_id)`

Costs 2 energy and replaces the whole visible hand with 5 random actions from the global action pool.

### `tick_game(...)`

Scheduled internal reducer.

Responsibilities:

- regen energy
- expire statuses
- resolve finished casts
- check win conditions

## Match Lifecycle

1. Client calls `create_match()`.
2. Client subscribes to `game_match` and `match_player`.
3. Client finds the waiting match row it owns through its identity.
4. Both players call `join_match(...)` with 3 hero slugs.
5. Server spawns heroes, creates visible hands, and flips the match to active.
6. During play:
   - select a caster
   - cast a visible hand slot onto a valid target slot
   - or reroll the hand
7. Tick processing resolves casts and statuses until one team has no living heroes.

### Matchmaking Flow

1. Client calls `upsert_profile(display_name)`.
2. Client calls `queue_for_matchmaking(hero_slug_1, hero_slug_2, hero_slug_3)`.
3. If no opponent exists, the player appears in `matchmaking_queue`.
4. When a second queued player arrives, the server:
   - creates a match
   - inserts both `match_player` rows
   - spawns both teams
   - creates starting hands
   - marks the match active
   - removes the matched queue entry
5. Each client discovers the new match by subscribing to `match_player` and `game_match` for its own identity.

## Client Integration Notes

Suggested client subscriptions:

- `game_match`
- `player_profile`
- `matchmaking_queue`
- `match_player`
- `match_team_state`
- `match_hero`
- `match_hand_slot`
- `match_status`
- `match_cast`
- `hero_def`
- `action_def`

Recommended client mapping:

- player's own team comes from `match_player.identity == local identity`
- hero board slots come from `match_hero.slot_index`
- visible hand comes from `match_hand_slot.slot_index`
- selected caster comes from `match_team_state.selected_caster_slot`
- a hero is currently channeling if `busy_until > now`

## Current Simplifications

- reroll uses a single global action pool, not per-player deckbuilding
- matchmaking is first-in-first-matched and has no rating/MMR yet
- action targeting is single-target only
- there is no interruption system yet
- hard status handling is minimal
- shield is implemented as a timed status bucket
- `create_match()` does not return `match_id`; the client must discover it by subscription

## Good Next Steps

- add reducer tests for create/join/cast/reroll/win flow
- add reducer tests for profile and matchmaking pairing flow
- add per-player action loadouts instead of one global pool
- add MMR, queue buckets, and regional matchmaking rules
- add explicit published docs for hero/action slugs shared with the client
- add bot/opponent helpers if you want solo testing before full multiplayer
