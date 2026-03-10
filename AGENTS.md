# Triarc Slice - Game Architecture Documentation

## Overview

Triarc Slice is a PvP card battler game with the following architecture:
- **Frontend**: Godot 4.x game client
- **Backend**: Gleam + OTP game server (previously SpaceTimeDB, now migrated)
- **Data**: Hero definitions stored as JSON files

## Repository Structure

```
triarc-slice/
├── game/                    # Godot game client
│   ├── scenes/             # Godot scene files (.tscn)
│   ├── scripts/            # GDScript files (.gd)
│   ├── data/               # Game data (heroes, layouts)
│   ├── shaders/            # GLSL shaders
│   └── project.godot       # Godot project configuration
├── data/                   # Hero definitions (shared)
│   └── hero/              # Each hero has its own folder
│       ├── {hero-name}/
│       │   ├── hero.json       # Hero stats, lore, positioning
│       │   └── img/            # Hero images (background, foreground, mask)
│       └── ...
└── editor/                 # Editor tools (if any)
```

## Godot Client Architecture

### Main Scripts

#### 1. Main.gd
- **Purpose**: Main game controller, handles UI and game state
- **Key responsibilities**:
  - Player registration and authentication
  - Matchmaking queue management
  - Match state display and interaction
  - Card casting and targeting
  - Hero selection and display

#### 2. SpacetimeClient.gd
- **Purpose**: HTTP client for server communication
- **Key responsibilities**:
  - Identity management (token-based auth)
  - Reducer calls (game actions)
  - SQL queries (state fetching)
  - Session persistence

#### 3. Card.gd
- **Purpose**: Individual hero card display
- **Key responsibilities**:
  - Load hero data from JSON
  - Display hero portrait, name, HP
  - Handle card interactions (click, double-click)

#### 4. LayoutManager.gd
- **Purpose**: Dynamic UI layout system
- **Key responsibilities**:
  - Position cards based on viewport size
  - Responsive layout for different screen sizes
  - Extra box rendering for game elements

### Game Flow

1. **Startup**:
   - Load hero definitions from `data/hero/`
   - Initialize UI components
   - Attempt to restore previous session

2. **Registration**:
   - Player enters display name
   - Client calls `upsert_profile` reducer
   - Profile stored on server

3. **Matchmaking**:
   - Player selects 3 heroes
   - Client calls `queue_for_matchmaking` reducer
   - Server pairs players automatically

4. **Match Gameplay**:
   - Server assigns teams and spawns heroes
   - Players see their hand of 5 action cards
   - Energy regenerates at 1/sec
   - Players can:
     - Select a caster hero
     - Cast action cards on valid targets
     - Reroll hand (costs 2 energy)

### UI Components

- **Lobby Panel**: Registration, matchmaking controls
- **Hero Selectors**: Dropdowns for selecting 3 heroes
- **Caster Buttons**: Select which hero will cast
- **Action Buttons**: 5 hand slots with action info
- **Target Buttons**: Ally/Enemy selection for targeting
- **Status Labels**: Energy, match status, queue status

## Server API (SpaceTimeDB Style)

### Reducers

| Reducer | Arguments | Description |
|---------|-----------|-------------|
| `upsert_profile` | `[display_name]` | Create/update player profile |
| `queue_for_matchmaking` | `[hero1, hero2, hero3]` | Join matchmaking queue |
| `leave_matchmaking` | `[]` | Leave queue |
| `select_caster` | `[match_id, slot_index]` | Set active caster |
| `cast_action` | `[match_id, hand_slot, target_slot]` | Cast a card |
| `reroll_hand` | `[match_id]` | Replace hand (costs 2 energy) |

### Tables (Server State)

- `player_profile`: Player registration data
- `matchmaking_queue`: Players waiting for match
- `game_match`: Active matches
- `match_player`: Players in matches
- `match_hero`: Hero instances in matches
- `match_team_state`: Energy, selected caster per team
- `match_hand_slot`: Current hand cards
- `action_def`: Available actions/cards
- `hero_def`: Hero definitions

## Hero Data Format

Each hero has a `hero.json` file:

```json
{
  "full_name": "Display Name",
  "lore": "Hero description...",
  "stats": {
    "max_hp": 1000,
    "attack": 100,
    "defense": 50,
    "element_affinity": {
      "fire": 10,
      "ice": 0,
      "earth": 5,
      "wind": -5,
      "light": 0,
      "shadow": 0
    }
  },
  "char_bg_pos": {"x": 0, "y": 0},
  "char_fg_pos": {"x": 0, "y": 0},
  "char_bg_scale": 100,
  "char_fg_scale": 100,
  "name_pos": {"x": 0, "y": 0},
  "name_scale": 50,
  "tint": "#ffffff"
}
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
- Actions have:
  - Energy cost
  - Casting time (ms)
  - Target type (ally/enemy/self)
  - Element
  - Effect (damage, heal, shield, status)

## Migration Notes (SpaceTimeDB → Gleam)

### Client Changes Needed

1. **Connection**: Replace HTTP/REST with WebSocket
2. **Authentication**: Token-based → Connection-based
3. **State Updates**: Polling → Push notifications
4. **Message Format**: JSON → MessagePack (optional)

### Server API Changes

| Old (SpaceTimeDB) | New (Gleam WebSocket) |
|-------------------|----------------------|
| HTTP POST /v1/identity | WebSocket connect with player_id |
| HTTP POST /call/{reducer} | WebSocket message: `{type: "cast_action", ...}` |
| HTTP POST /sql | WebSocket message: `{type: "get_state"}` |
| Polling for updates | Server pushes state updates |

### Message Protocol (WebSocket)

**Client → Server:**
```json
{"type": "upsert_profile", "display_name": "Player1"}
{"type": "queue_matchmaking", "hero_slug_1": "knight", ...}
{"type": "select_caster", "match_id": "123", "slot_index": 1}
{"type": "cast_action", "match_id": "123", "hand_slot_index": 1, "target_slot": 2}
{"type": "reroll_hand", "match_id": "123"}
```

**Server → Client:**
```json
{"type": "connected", "player_id": "uuid"}
{"type": "state_update", "match": {...}, "heroes": [...], "hand": [...]}
{"type": "event", "event_type": "cast_started", "data": {...}}
{"type": "error", "code": "INVALID_TARGET", "message": "..."}
```

## Development Workflow

1. **Modify Hero Data**: Edit JSON files in `data/hero/`
2. **Game Logic**: Modify GDScript in `game/scripts/`
3. **Server Logic**: Modify Gleam files in `vg_server/src/`
4. **Test**: Run both client and server locally

## Debugging Tips

- Use Godot's remote debugger for client issues
- Check browser Network tab for HTTP requests
- Enable verbose logging in SpacetimeClient
- Verify hero JSON files are valid
- Check server logs for reducer errors
