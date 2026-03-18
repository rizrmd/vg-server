# Vanguard's Gambit - Game Server

WebSocket game server for the Vanguard's Gambit PvP card battler.

**Server URL:** `wss://sg.vangambit.com/ws`
**Test page:** `https://sg.vangambit.com/sign-in/test`

## Connection & Authentication

All communication is via **WebSocket JSON messages**. Authentication via Google Sign-In is required before any gameplay messages.

### Step 1: Connect

Connect to `wss://sg.vangambit.com/ws`. Server responds:

```json
{"type": "connected", "player_id": "anon_123456"}
```

The `anon_*` ID is temporary. You must authenticate to get a persistent player ID.

### Step 2: Authenticate with Google

The client must obtain a **Google ID token** using Google Sign-In, then send:

```json
{"type": "authenticate", "id_token": "<google_id_token_string>"}
```

**Godot implementation:**
1. Use a Google Sign-In plugin (e.g., [Godot Google Play Games Services](https://github.com/nickenough/godot-gpc) for Android, or a web-based OAuth flow)
2. Get the ID token from the Google Sign-In result
3. Send it to the server as shown above
4. Cache the token locally for reconnection

**On success**, server responds:

```json
{
  "type": "authenticated",
  "player_id": "g_123456789",
  "display_name": "Player Name",
  "email": "player@gmail.com"
}
```

The `player_id` (format `g_<google_sub>`) is persistent — same Google account always gets the same ID. Store this locally.

**On failure:**

```json
{"type": "auth_error", "code": "INVALID_TOKEN", "message": "..."}
```

Error codes: `INVALID_TOKEN`, `NO_DB`, `DB_ERROR`, `NOT_AUTHENTICATED`

**All messages sent before authenticating will be rejected with:**

```json
{"type": "auth_error", "code": "NOT_AUTHENTICATED", "message": "Send authenticate message first"}
```

### Step 3: Reconnection

On reconnect, send the cached Google ID token again. If the token is expired (Google ID tokens last ~1 hour), refresh it via Google Sign-In before reconnecting.

## Game Rules

- 2 teams per match, 3 heroes per team
- Shared visible hand of 5 action cards
- Drag a card onto one of your heroes to cast it (hero becomes the caster)
- Targeting is resolved automatically by the server
- Shared team energy: max 10, start 10, regen 1/second
- Reroll cost: 2 energy (replaces entire hand)
- Each card has its own cast time (hero is busy while casting)

## Client → Server Messages

All messages require authentication except `authenticate`.

### `authenticate`

```json
{"type": "authenticate", "id_token": "<google_id_token>"}
```

### `upsert_profile`

```json
{"type": "upsert_profile", "display_name": "MyName"}
```

### `queue_matchmaking`

```json
{
  "type": "queue_matchmaking",
  "hero_slug_1": "iron-knight",
  "hero_slug_2": "arc-strider",
  "hero_slug_3": "flame-warlock"
}
```

### `cast_action`

```json
{
  "type": "cast_action",
  "match_id": "match_123",
  "caster_slot": 1,
  "hand_slot_index": 2
}
```

- `caster_slot`: hero slot (1-3) the card is dropped on
- `hand_slot_index`: which card from the hand (1-5)

### `reroll_hand`

```json
{"type": "reroll_hand", "match_id": "match_123"}
```

Costs 2 energy. Replaces the entire hand with 5 random actions.

### `leave_match`

```json
{"type": "leave_match", "match_id": "match_123"}
```

### `get_match_history`

```json
{"type": "get_match_history", "limit": 10, "offset": 0}
```

### `get_leaderboard`

```json
{"type": "get_leaderboard", "limit": 10}
```

### `get_player_stats`

```json
{"type": "get_player_stats", "target_player_id": "g_123456789"}
```

## Server → Client Messages

### `connected`

Sent immediately on WebSocket connect.

```json
{"type": "connected", "player_id": "anon_123456"}
```

### `authenticated`

Sent after successful Google token verification.

```json
{
  "type": "authenticated",
  "player_id": "g_123456789",
  "display_name": "Player Name",
  "email": "player@gmail.com"
}
```

### `auth_error`

```json
{"type": "auth_error", "code": "INVALID_TOKEN", "message": "..."}
```

### `matchmaking_queued`

```json
{"type": "matchmaking_queued"}
```

### `match_found`

```json
{"type": "match_found", "match_id": "match_123", "team": 1}
```

### `state_update`

Full match state push. Sent after actions, periodically during match.

```json
{
  "type": "state_update",
  "match": {
    "match_id": "match_123",
    "phase": 2,
    "created_at": 1234567890,
    "started_at": 1234567890,
    "winner": 0
  },
  "players": [
    {"player_id": "g_123", "match_id": "match_123", "team": 1}
  ],
  "team_states": [
    {"match_id": "match_123", "team": 1, "energy": 8, "energy_max": 10, "last_energy_at": 1234567890, "selected_caster_slot": 0}
  ],
  "heroes": [
    {"hero_instance_id": "hero_1", "match_id": "match_123", "team": 1, "slot_index": 1, "hero_slug": "iron-knight", "hp_current": 3500, "hp_max": 3500, "alive": true, "busy_until": 0}
  ],
  "hand": [
    {"match_id": "match_123", "team": 1, "slot_index": 1, "action_slug": "fireball", "action_name": "Fireball", "energy_cost": 3, "target_rule": "enemy_single", "targeting": {"side": "enemy", "scope": "single", "selection": "manual", "allow_self": false, "allow_dead": false}}
  ],
  "statuses": [],
  "casts": []
}
```

**Match phase:** `1 = waiting`, `2 = active`, `3 = finished`
**Winner:** `0 = none`, `1 = team 1`, `2 = team 2`

### `event`

```json
{"type": "event", "event_type": "cast_started", "data": {...}}
```

### `error`

```json
{"type": "error", "code": "CAST_ERROR", "message": "Not enough energy"}
```

### `match_history`

```json
{
  "type": "match_history",
  "matches": [
    {"match_id": "...", "player1_id": "...", "player2_id": "...", "winner": 1, "started_at": 0, "ended_at": 0, "duration_ms": 0}
  ]
}
```

### `leaderboard`

```json
{
  "type": "leaderboard",
  "entries": [
    {"rank": 1, "player_id": "g_123", "display_name": "Pro Player", "matches_won": 50, "rating": 1250}
  ]
}
```

### `player_stats`

```json
{
  "type": "player_stats",
  "stats": {
    "player_id": "g_123",
    "display_name": "Player",
    "matches_played": 100,
    "matches_won": 50,
    "matches_lost": 50,
    "rating": 1000,
    "created_at": 0,
    "updated_at": 0
  }
}
```

## Typical Godot Client Flow

```
1. Google Sign-In → get id_token
2. Connect WebSocket to wss://sg.vangambit.com/ws
3. Receive: {"type": "connected", "player_id": "anon_xxx"}
4. Send: {"type": "authenticate", "id_token": "..."}
5. Receive: {"type": "authenticated", "player_id": "g_xxx", ...}
6. Send: {"type": "queue_matchmaking", "hero_slug_1": "...", ...}
7. Receive: {"type": "matchmaking_queued"}
8. Wait...
9. Receive: {"type": "match_found", "match_id": "...", "team": 1}
10. Receive: {"type": "state_update", ...}  (continuous during match)
11. Send: {"type": "cast_action", ...}  or  {"type": "reroll_hand", ...}
12. Match ends when state_update shows phase=3 and winner!=0
```

## Available Heroes

iron-knight, arc-strider, necromancer, spellblade-empress, earth-warden, dawn-priest, flame-warlock, blood-alchemist, gunslinger, night-venom, princess-emberheart, demon-empress, tyrant-overlord, arcane-paladin, storm-ranger, wind-monk, frost-queen

## Current Simplifications

- Reroll uses a single global action pool, not per-player deckbuilding
- Matchmaking is first-in-first-matched, no rating/MMR
- Action targeting is auto-resolved (no manual target selection by client)
- No interruption system
- Shield is implemented as a timed status
