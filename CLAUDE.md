# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vanguard's Gambit game server — a PvP card battler backend written in Gleam (Erlang/BEAM target). Clients (Godot) connect via WebSocket. Migrated from SpaceTimeDB to Gleam + OTP actors.

## Build & Run Commands

```bash
gleam deps download    # Install dependencies
gleam build            # Compile
gleam test             # Run all tests (gleeunit)
gleam run              # Start server on port 7567
```

Docker:
```bash
docker build -t vg-server .
docker run -p 3000:3000 vg-server
```

## Architecture

**Entry point**: `src/vg_server.gleam` — starts DB, all OTP actor registries, the match orchestrator, and the HTTP/WebSocket server (mist) on port 7567.

**OTP Actor System** (all communicate via message passing):
- **PlayerRegistry** — player profile CRUD (in-memory Dict)
- **MatchmakingQueue** — queues players, pairs them into matches
- **MatchRegistry** — creates/tracks match actor processes
- **Match actor** — one per active match; holds full match state, processes casts/ticks
- **ConnectionRegistry** — maps player_id to WebSocket connection for push notifications
- **MatchOrchestrator** — background loops: matchmaking (1000ms) and match ticks (200ms)

**Request flow**: WebSocket connection → `websocket.gleam` parses JSON → routes to appropriate OTP actor → actor sends state updates back through ConnectionRegistry.

**Key modules in `src/vg/`**:
- `types.gleam` — all type definitions (Element, HeroDef, ActionDef, match state types)
- `content.gleam` — hardcoded hero (17) and action (30+) definitions; changes require recompile
- `match_logic.gleam` — game rules: damage formula, energy, cast resolution, win conditions
- `game_json.gleam` / `json_parse.gleam` — JSON encoding/decoding for the WebSocket protocol
- `db.gleam` — PostgreSQL persistence via `pog` (match results and player stats only; runtime state is in-memory)

**Damage formula**: `base_power * (attack/100) * outgoing_affinity * (100/(100+defense)) * incoming_affinity`, minimum 1.

## Key Design Decisions

- **All runtime match state lives in OTP actors** (not persisted). Matches are lost on restart. Only results/stats go to PostgreSQL.
- **No authentication** — random player_id assigned on WebSocket connect.
- **Static content** is hardcoded in `content.gleam`, not loaded from DB or files.
- **JSON protocol** over WebSocket (MessagePack via glepack is available but not primary).
- **Game constants** are in `match_logic.gleam`: max_energy=10, energy_regen=1/sec, reroll_cost=2, hand_size=5, heroes_per_team=3.

## WebSocket Protocol

Client messages use `{"type": "..."}` format. Key types: `upsert_profile`, `queue_matchmaking`, `cast_action`, `reroll_hand`, `leave_match`, `get_match_history`, `get_leaderboard`, `get_player_stats`.

Server pushes: `connected`, `state_update`, `event`, `error`, `match_found`, `matchmaking_queued`.

## Deployment

**Server**: `ssh riz@cf.avolut.com`
**Coolify app ID**: `nw8g4co0skk488ss000k44ok`
**Live URL**: `https://sg.vangambit.com` (WebSocket at `wss://sg.vangambit.com/ws`)

**Environment variables** (read in `vg_server.gleam` via `vg_server_ffi.erl`):
- `DATABASE_URL` — PostgreSQL connection string with db name (e.g. `postgres://user:pass@host:port/dbname`). Falls back to hardcoded default.
- `PORT` — HTTP/WebSocket listen port (falls back to 7567, Docker default is 3000)

**How to deploy** (via Coolify API from the server):
```bash
# SSH into the server
ssh riz@cf.avolut.com

# Trigger a deploy (pulls latest from master, builds Dockerfile, deploys)
docker exec coolify curl -s \
  "http://localhost:8080/api/v1/deploy?uuid=nw8g4co0skk488ss000k44ok&force=true" \
  -H "Authorization: Bearer 11|mydeploytoken123456"
```

Coolify auto-builds from `rizrmd/vg-server` master branch using the Dockerfile. Push to master then trigger deploy.

**Check deployment status**:
```bash
# Replace DEPLOY_UUID with the uuid from the deploy response
docker exec coolify curl -s \
  "http://localhost:8080/api/v1/deployments/DEPLOY_UUID" \
  -H "Authorization: Bearer 11|mydeploytoken123456" | python3 -m json.tool
```

**Check running container logs**:
```bash
docker logs nw8g4co0skk488ss000k44ok
```

**Dockerfile notes**:
- Builder: `ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine` (OTP 28)
- Runtime: `erlang:28-alpine` — must match builder OTP version
- Uses `gleam export erlang-shipment` for proper OTP boot with all dependencies
- Exposes port 3000, Traefik routes `sg.vangambit.com` to it

## Gleam Language Notes

- Gleam compiles to Erlang (BEAM VM). No mutable state — all updates return new values.
- OTP actors use `gleam_otp` with `process.start`/`process.send`/`process.call`.
- Pattern matching is exhaustive; all cases must be handled.
- Use `gleam_json` for encoding, manual string extraction in `json_parse.gleam` for decoding.
