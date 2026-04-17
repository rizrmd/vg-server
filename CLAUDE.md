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
- **Google Sign-In required** — clients must authenticate via Google ID token before gameplay. Player accounts stored in `players` table with persistent `g_<google_sub>` IDs.
- **Static content** is hardcoded in `content.gleam`, not loaded from DB or files.
- **JSON protocol** over WebSocket (MessagePack via glepack is available but not primary).
- **Game constants** are in `match_logic.gleam`: max_energy=10, energy_regen=1/sec, reroll_cost=2, hand_size=5, heroes_per_team=3.

## WebSocket Protocol

Client messages use `{"type": "..."}` format:
- **Auth (must be first)**: `authenticate` (with `id_token` from Google Sign-In)
- **Gameplay**: `upsert_profile`, `queue_matchmaking`, `cast_action`, `reroll_hand`, `leave_match`, `get_match_history`, `get_leaderboard`, `get_player_stats`

Server pushes: `connected`, `authenticated`, `auth_error`, `state_update`, `event`, `error`, `match_found`, `matchmaking_queued`.

All gameplay messages are blocked until the client sends a valid `authenticate` message.

## Deployment

**Server**: `ssh riz@cf.avolut.com`
**Coolify app ID**: `nw8g4co0skk488ss000k44ok`
**Live URL**: `https://sg.vangambit.com` (WebSocket at `wss://sg.vangambit.com/ws`)

**Environment variables** (read in `vg_server.gleam` via `vg_server_ffi.erl`):
- `DATABASE_URL` — PostgreSQL connection string (e.g. `postgres://user:pass@host:port/dbname`). Falls back to hardcoded default.
- `PORT` — HTTP/WebSocket listen port (falls back to 7567, Docker default is 3000)
- `GOOGLE_CLIENT_ID` — Google OAuth client ID for Sign-In token verification

**How to deploy** (push to master, then trigger via Coolify API):
```bash
# 1. Push your changes
git push origin master

# 2. SSH into the server and trigger deploy (one-liner from local machine)
ssh riz@cf.avolut.com 'docker exec coolify curl -s "http://localhost:8080/api/v1/deploy?uuid=nw8g4co0skk488ss000k44ok&force=true" -H "Authorization: Bearer 11|mydeploytoken123456"'
```

Coolify pulls latest from `rizrmd/vg-server` master, builds the Dockerfile, and deploys.

**Check deployment status**:
```bash
# Replace DEPLOY_UUID with the uuid from the deploy response
ssh riz@cf.avolut.com 'docker exec coolify curl -s "http://localhost:8080/api/v1/deployments/DEPLOY_UUID" -H "Authorization: Bearer 11|mydeploytoken123456"'
```

**Check running container logs**:
```bash
ssh riz@cf.avolut.com "docker logs nw8g4co0skk488ss000k44ok"
```

**Add/update env vars**:
```bash
ssh riz@cf.avolut.com 'docker exec coolify curl -s -X POST "http://localhost:8080/api/v1/applications/nw8g4co0skk488ss000k44ok/envs" -H "Authorization: Bearer 11|mydeploytoken123456" -H "Content-Type: application/json" -d "{\"key\":\"VAR_NAME\",\"value\":\"VAR_VALUE\",\"is_runtime\":true,\"is_buildtime\":false}"'
```

**Dockerfile notes**:
- Builder: `ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine` (OTP 28)
- Runtime: `erlang:28-alpine` — must match builder OTP version
- Uses `gleam export erlang-shipment` for proper OTP boot with all dependencies
- Exposes port 3000, Traefik routes `sg.vangambit.com` to it

**Test pages**:
- `https://sg.vangambit.com/sign-in/test` — Google Sign-In + WebSocket auth test

## Gleam Language Notes

- Gleam compiles to Erlang (BEAM VM). No mutable state — all updates return new values.
- OTP actors use `gleam_otp` with `process.start`/`process.send`/`process.call`.
- Pattern matching is exhaustive; all cases must be handled.
- Use `gleam_json` for encoding, manual string extraction in `json_parse.gleam` for decoding.
