# Vanguard's Gambit - Game Server Architecture

## Overview

Vanguard's Gambit is a PvP card battler game with the following architecture:
- **Backend**: Gleam + OTP game server (migrated from SpaceTimeDB)
- **Client**: WebSocket-based (Godot client connects via WebSocket)

## Repository Structure

```
vg-server/
├── gleam.toml              # Gleam project configuration
├── manifest.toml           # Dependency lock file
├── README.md               # Game rules documentation
├── AGENTS.md               # This file - architecture documentation
├── rebar3                  # Erlang build tool (for OTP)
├── src/
│   ├── vg_server.gleam     # Main entry point - starts supervisor and HTTP/WebSocket server
│   └── vg/
│       ├── websocket.gleam     # WebSocket handler (minimal echo implementation)
│       ├── types.gleam         # Core data types (HeroDef, ActionDef, MatchHero, etc.)
│       ├── content.gleam       # Static hero and action definitions (17 heroes, 30+ actions)
│       ├── match_logic.gleam   # Game rules (damage calc, energy, cast resolution)
│       ├── match.gleam         # OTP actor for individual match state
│       ├── matchmaking.gleam   # OTP actor for matchmaking queue
│       ├── match_registry.gleam # OTP actor for managing match processes
│       └── player_registry.gleam # OTP actor for player profiles
└── test/
    └── vg_server_test.gleam    # Unit tests for content and game logic
```

## Server Architecture

### Core Modules

#### 1. vg_server.gleam
- **Purpose**: Main entry point
- **Key responsibilities**:
  - Starts OTP supervisor
  - Starts HTTP/WebSocket server on port 8080
  - Routes `/ws` to WebSocket handler

#### 2. websocket.gleam
- **Purpose**: WebSocket connection handler
- **Current state**: Handles the game WebSocket protocol and pushes state updates
- **Key responsibilities**:
  - Assigns random player_id on connection
  - Parses client JSON messages
  - Routes gameplay messages to OTP actors
  - Pushes match state and events back to clients

#### 3. types.gleam
- **Purpose**: Core type definitions
- **Key types**:
  - `Element`: Fire, Ice, Earth, Wind, Light, Shadow
  - `TargetRule`: AllySingle, EnemySingle, Self
  - `EffectKind`: Damage, Heal, Shield, Status, DamageAndStatus, Cleanse
  - `HeroDef`: Static hero stats (17 heroes defined)
  - `ActionDef`: Action/card definitions (30+ actions)
  - `MatchHero`, `MatchTeamState`, `MatchCast`, `GameMatch`: Runtime match entities

#### 4. content.gleam
- **Purpose**: Static game content
- **Heroes** (17): iron-knight, arc-strider, necromancer, spellblade-empress, earth-warden, dawn-priest, flame-warlock, blood-alchemist, gunslinger, night-venom, princess-emberheart, demon-empress, tyrant-overlord, arcane-paladin, storm-ranger, wind-monk, frost-queen
- **Actions** (30+): fireball, inferno, flame_shield, meteor, burn, ice_shard, frost_armor, blizzard, frost_nova, deep_freeze, rock_throw, earth_shield, quake, stone_skin, wind_slash, gust, lightning_strike, tailwind, heal, smite, divine_shield, mass_heal, bless, judgment, shadow_strike, dark_bolt, curse, life_drain, dark_ritual, attack, defend, cleanse, focus

#### 5. match_logic.gleam
- **Purpose**: Game rules and calculations
- **Constants**:
  - `max_energy = 10`
  - `start_energy = 10`
  - `energy_regen_per_second = 1`
  - `reroll_cost = 2`
  - `hand_size = 5`
  - `heroes_per_team = 3`
- **Functions**: damage calculation, healing, shield, energy management, cast resolution, hand rolling, win condition checking

#### 6. match.gleam
- **Purpose**: OTP actor for individual match state
- **Messages**: JoinMatch, GetState
- **State**: Match metadata and player list

#### 7. matchmaking.gleam
- **Purpose**: OTP actor for matchmaking queue
- **Messages**: QueuePlayer, LeaveQueue, GetMatch, TryMatch, ListQueue

#### 8. match_registry.gleam
- **Purpose**: OTP actor for managing match processes
- **Messages**: CreateMatch, GetMatch, RemoveMatch, ListMatches

#### 9. player_registry.gleam
- **Purpose**: OTP actor for player profiles
- **Messages**: UpsertProfile, GetProfile, RemoveProfile

## Server API

### Game Actions (WebSocket Protocol)

**Client → Server:**
```json
{"type": "upsert_profile", "display_name": "Player1"}
{"type": "queue_matchmaking", "hero_slug_1": "knight", "hero_slug_2": "mage", "hero_slug_3": "archer"}
{"type": "cast_action", "match_id": "123", "caster_slot": 1, "hand_slot_index": 2}
{"type": "reroll_hand", "match_id": "123"}
```

**Gameplay flow:**
- Player drags a card from the hand onto a hero (caster)
- Targeting is resolved automatically by the server from the action definition
- Caster becomes busy while casting, then effect applies

**Server → Client:**
```json
{"type": "connected", "player_id": "uuid"}
{"type": "state_update", "match": {...}, "players": [...], "team_states": [...], "heroes": [...], "hand": [...], "statuses": [...], "casts": [...]}
{"type": "event", "event_type": "cast_started", "data": {...}}
{"type": "error", "code": "INVALID_TARGET", "message": "..."}
```

### Data Types (Runtime)

- `PlayerProfile`: Player registration data
- `MatchmakingEntry`: Players waiting for match
- `GameMatch`: Active matches
- `MatchPlayer`: Players in matches
- `MatchHero`: Hero instances in matches
- `MatchTeamState`: Energy and per-team combat state
- `MatchHandSlot`: Current hand cards
- `MatchStatus`: Active status effects
- `MatchCast`: In-flight casts
- `HeroDef`: Static hero definitions
- `ActionDef`: Static action/card definitions

## Hero Data Format

Hero definitions are hardcoded in `src/vg/content.gleam` as Gleam records:

```gleam
pub type HeroDef {
  HeroDef(
    slug: String,
    display_name: String,
    max_hp: Int,
    attack: Int,
    defense: Int,
    fire_affinity: Int,
    ice_affinity: Int,
    earth_affinity: Int,
    wind_affinity: Int,
    light_affinity: Int,
    shadow_affinity: Int,
  )
}

// Example: Iron Knight
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
```

## Key Game Mechanics

### Elements
- **Fire**: Strong vs Ice, weak vs Water/Earth
- **Ice**: Strong vs Wind, weak vs Fire
- **Earth**: Strong vs Wind, weak vs Fire
- **Wind**: Strong vs Earth, weak vs Ice
- **Light**: Strong vs Shadow
- **Shadow**: Strong vs Light

### Energy System
- Max energy: 10
- Start energy: 10
- Regen: 1 energy per second
- Reroll cost: 2 energy

### Combat
- 2 teams per match
- 3 heroes per team
- 5 visible hand cards
- playing a card means dragging it onto one of your own heroes
- the dropped-on hero becomes the acting hero for that card
- targeting is resolved automatically by the server
- Actions have:
  - Energy cost
  - Casting time (ms)
  - Targeting rules used for auto-resolution
  - Element
  - Effect (damage, heal, shield, status)

## Migration Status (SpaceTimeDB → Gleam)

### Completed
- ✅ Core type definitions (`types.gleam`)
- ✅ Static content (heroes and actions in `content.gleam`)
- ✅ Game logic (damage calc, energy, cast resolution in `match_logic.gleam`)
- ✅ OTP actor infrastructure (match, matchmaking, registries)
- ✅ Basic WebSocket server setup

### In Progress / TODO
- 🔄 Match lifecycle orchestration (start, tick, end)
- 🔄 Hand management and action casting flow polish

### Client Changes Needed

1. **Connection**: Replace HTTP/REST with WebSocket
2. **Authentication**: Token-based → Connection-based (random player_id assigned on connect)
3. **State Updates**: Polling → Push notifications (not yet implemented)
4. **Message Format**: JSON → MessagePack (optional - currently JSON)

## Development Workflow

1. **Modify Hero/Action Data**: Edit `src/vg/content.gleam`
2. **Game Logic**: Modify `src/vg/match_logic.gleam`
3. **Server Logic**: Modify Gleam files in `src/vg/`
4. **Main Entry**: Modify `src/vg_server.gleam`
5. **Test**: Run `gleam test`
6. **Run Server**: `gleam run`

## Build & Run

```bash
# Install dependencies
gleam deps download

# Run tests
gleam test

# Run the server
gleam run
# Server starts on port 8080
```

## Debugging Tips

- Check server logs in terminal
- Use WebSocket client (e.g., `websocat`, browser console) to test connections:
  ```bash
  websocat ws://localhost:8080/ws
  ```
- Review `match_logic.gleam` for game rule calculations
- Check actor states by adding debug logging
