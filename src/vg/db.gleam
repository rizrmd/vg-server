// Database module for PostgreSQL persistence
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import pog

// Match result record
pub type MatchResult {
  MatchResult(
    match_id: String,
    player1_id: String,
    player2_id: String,
    winner: Int,
    started_at: Int,
    ended_at: Int,
    duration_ms: Int,
  )
}

// Player stats record
pub type PlayerStats {
  PlayerStats(
    player_id: String,
    display_name: String,
    matches_played: Int,
    matches_won: Int,
    matches_lost: Int,
    rating: Int,
    ftue_completed: Bool,
    created_at: Int,
    updated_at: Int,
  )
}

// Player account (Google or anonymous)
pub type Player {
  Player(
    player_id: String,
    google_sub: String,
    email: String,
    display_name: String,
    avatar_url: String,
    created_at: Int,
    updated_at: Int,
  )
}

// Leaderboard entry
pub type LeaderboardEntry {
  LeaderboardEntry(
    rank: Int,
    player_id: String,
    display_name: String,
    matches_won: Int,
    rating: Int,
  )
}

/// Initialize the database with required tables
pub fn init(db_url: String) -> Result(pog.Connection, String) {
  let pool_name = process.new_name(prefix: "vg_db")
  let config_result = pog.url_config(pool_name, db_url)
  case config_result {
    Ok(config) -> {
      case pog.start(config) {
        Ok(actor.Started(pid: _, data: conn)) -> {
          // Create match_results table
          let match_results_sql =
            "
            CREATE TABLE IF NOT EXISTS match_results (
              match_id TEXT PRIMARY KEY,
              player1_id TEXT NOT NULL,
              player2_id TEXT NOT NULL,
              winner INTEGER NOT NULL,
              started_at BIGINT NOT NULL,
              ended_at BIGINT NOT NULL,
              duration_ms BIGINT NOT NULL
            )
          "
          case pog.query(match_results_sql) |> pog.execute(conn) {
            Ok(_) -> Nil
            Error(_) -> Nil
          }

          // Create player_stats table
          let player_stats_sql =
            "
            CREATE TABLE IF NOT EXISTS player_stats (
              player_id TEXT PRIMARY KEY,
              display_name TEXT NOT NULL,
              matches_played INTEGER DEFAULT 0,
              matches_won INTEGER DEFAULT 0,
              matches_lost INTEGER DEFAULT 0,
              rating INTEGER DEFAULT 1000,
              ftue_completed BOOLEAN DEFAULT FALSE,
              created_at BIGINT NOT NULL,
              updated_at BIGINT NOT NULL
            )
          "
          case pog.query(player_stats_sql) |> pog.execute(conn) {
            Ok(_) -> Nil
            Error(_) -> Nil
          }

          // Create players table
          let players_sql =
            "
            CREATE TABLE IF NOT EXISTS players (
              player_id TEXT PRIMARY KEY,
              google_sub TEXT UNIQUE NOT NULL,
              email TEXT,
              display_name TEXT NOT NULL,
              avatar_url TEXT,
              created_at BIGINT NOT NULL,
              updated_at BIGINT NOT NULL
            )
          "
          case pog.query(players_sql) |> pog.execute(conn) {
            Ok(_) -> Nil
            Error(_) -> Nil
          }

          // Create sessions table
          let sessions_sql =
            "
            CREATE TABLE IF NOT EXISTS sessions (
              token TEXT PRIMARY KEY,
              player_id TEXT NOT NULL REFERENCES players(player_id),
              created_at BIGINT NOT NULL
            )
          "
          case pog.query(sessions_sql) |> pog.execute(conn) {
            Ok(_) -> Nil
            Error(_) -> Nil
          }

          // Create indexes
          let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_match_results_player1 ON match_results(player1_id)",
            "CREATE INDEX IF NOT EXISTS idx_match_results_player2 ON match_results(player2_id)",
            "CREATE INDEX IF NOT EXISTS idx_match_results_ended_at ON match_results(ended_at)",
            "CREATE INDEX IF NOT EXISTS idx_player_stats_rating ON player_stats(rating DESC)",
            "CREATE INDEX IF NOT EXISTS idx_player_stats_wins ON player_stats(matches_won DESC)",
            "CREATE INDEX IF NOT EXISTS idx_players_google_sub ON players(google_sub)",
            "CREATE INDEX IF NOT EXISTS idx_sessions_player_id ON sessions(player_id)",
          ]
          list.each(indexes, fn(sql) {
            case pog.query(sql) |> pog.execute(conn) {
              Ok(_) -> Nil
              Error(_) -> Nil
            }
          })

          Ok(conn)
        }
        Error(_) -> Error("Failed to start database connection pool")
      }
    }
    Error(Nil) -> Error("Invalid database URL")
  }
}

/// Decoder for MatchResult
fn match_result_decoder() -> Decoder(MatchResult) {
  use match_id <- decode.field(0, decode.string)
  use player1_id <- decode.field(1, decode.string)
  use player2_id <- decode.field(2, decode.string)
  use winner <- decode.field(3, decode.int)
  use started_at <- decode.field(4, decode.int)
  use ended_at <- decode.field(5, decode.int)
  use duration_ms <- decode.field(6, decode.int)
  decode.success(MatchResult(
    match_id: match_id,
    player1_id: player1_id,
    player2_id: player2_id,
    winner: winner,
    started_at: started_at,
    ended_at: ended_at,
    duration_ms: duration_ms,
  ))
}

/// Save a match result
pub fn save_match_result(
  conn: pog.Connection,
  r: MatchResult,
) -> Result(Nil, pog.QueryError) {
  let sql =
    "
    INSERT INTO match_results (match_id, player1_id, player2_id, winner, started_at, ended_at, duration_ms)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
  "
  pog.query(sql)
  |> pog.parameter(pog.text(r.match_id))
  |> pog.parameter(pog.text(r.player1_id))
  |> pog.parameter(pog.text(r.player2_id))
  |> pog.parameter(pog.int(r.winner))
  |> pog.parameter(pog.int(r.started_at))
  |> pog.parameter(pog.int(r.ended_at))
  |> pog.parameter(pog.int(r.duration_ms))
  |> pog.execute(conn)
  |> result.map(fn(_) { Nil })
}

/// Get match history for a player
pub fn get_player_match_history(
  conn: pog.Connection,
  player_id: String,
  limit: Int,
  offset: Int,
) -> Result(List(MatchResult), pog.QueryError) {
  let sql =
    "
    SELECT match_id, player1_id, player2_id, winner, started_at, ended_at, duration_ms
    FROM match_results
    WHERE player1_id = $1 OR player2_id = $2
    ORDER BY ended_at DESC
    LIMIT $3 OFFSET $4
  "

  pog.query(sql)
  |> pog.parameter(pog.text(player_id))
  |> pog.parameter(pog.text(player_id))
  |> pog.parameter(pog.int(limit))
  |> pog.parameter(pog.int(offset))
  |> pog.returning(match_result_decoder())
  |> pog.execute(conn)
  |> result.map(fn(resp) { resp.rows })
}

/// Get a single match result
pub fn get_match_result(
  conn: pog.Connection,
  match_id: String,
) -> Result(Option(MatchResult), pog.QueryError) {
  let sql =
    "
    SELECT match_id, player1_id, player2_id, winner, started_at, ended_at, duration_ms
    FROM match_results
    WHERE match_id = $1
  "

  use resp <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(match_id))
    |> pog.returning(match_result_decoder())
    |> pog.execute(conn),
  )

  case resp.rows {
    [r, ..] -> Ok(Some(r))
    [] -> Ok(None)
  }
}

/// Decoder for PlayerStats
fn player_stats_decoder() -> Decoder(PlayerStats) {
  use player_id <- decode.field(0, decode.string)
  use display_name <- decode.field(1, decode.string)
  use matches_played <- decode.field(2, decode.int)
  use matches_won <- decode.field(3, decode.int)
  use matches_lost <- decode.field(4, decode.int)
  use rating <- decode.field(5, decode.int)
  use ftue_completed <- decode.field(6, decode.bool)
  use created_at <- decode.field(7, decode.int)
  use updated_at <- decode.field(8, decode.int)
  decode.success(PlayerStats(
    player_id: player_id,
    display_name: display_name,
    matches_played: matches_played,
    matches_won: matches_won,
    matches_lost: matches_lost,
    rating: rating,
    ftue_completed: ftue_completed,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

/// Upsert player stats (insert or update)
pub fn upsert_player_stats(
  conn: pog.Connection,
  stats: PlayerStats,
) -> Result(Nil, pog.QueryError) {
  let sql =
    "
    INSERT INTO player_stats (player_id, display_name, matches_played, matches_won, matches_lost, rating, ftue_completed, created_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    ON CONFLICT(player_id) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      matches_played = EXCLUDED.matches_played,
      matches_won = EXCLUDED.matches_won,
      matches_lost = EXCLUDED.matches_lost,
      rating = EXCLUDED.rating,
      ftue_completed = EXCLUDED.ftue_completed,
      updated_at = EXCLUDED.updated_at
  "

  pog.query(sql)
  |> pog.parameter(pog.text(stats.player_id))
  |> pog.parameter(pog.text(stats.display_name))
  |> pog.parameter(pog.int(stats.matches_played))
  |> pog.parameter(pog.int(stats.matches_won))
  |> pog.parameter(pog.int(stats.matches_lost))
  |> pog.parameter(pog.int(stats.rating))
  |> pog.parameter(pog.bool(stats.ftue_completed))
  |> pog.parameter(pog.int(stats.created_at))
  |> pog.parameter(pog.int(stats.updated_at))
  |> pog.execute(conn)
  |> result.map(fn(_) { Nil })
}

/// Get player stats
pub fn get_player_stats(
  conn: pog.Connection,
  player_id: String,
) -> Result(Option(PlayerStats), pog.QueryError) {
  let sql =
    "
    SELECT player_id, display_name, matches_played, matches_won, matches_lost, rating, ftue_completed, created_at, updated_at
    FROM player_stats
    WHERE player_id = $1
  "

  use resp <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(player_id))
    |> pog.returning(player_stats_decoder())
    |> pog.execute(conn),
  )

  case resp.rows {
    [stats, ..] -> Ok(Some(stats))
    [] -> Ok(None)
  }
}

/// Get or create player stats (creates default if not exists)
pub fn get_or_create_player_stats(
  conn: pog.Connection,
  player_id: String,
  display_name: String,
  now: Int,
) -> Result(PlayerStats, pog.QueryError) {
  case get_player_stats(conn, player_id) {
    Ok(Some(stats)) -> Ok(stats)
    Ok(None) -> {
      let stats =
        PlayerStats(
          player_id: player_id,
          display_name: display_name,
          matches_played: 0,
          matches_won: 0,
          matches_lost: 0,
          rating: 1000,
          ftue_completed: False,
          created_at: now,
          updated_at: now,
        )
      use _ <- result.try(upsert_player_stats(conn, stats))
      Ok(stats)
    }
    Error(e) -> Error(e)
  }
}

/// Mark FTUE as completed for a player
pub fn mark_ftue_completed(
  conn: pog.Connection,
  player_id: String,
  now: Int,
) -> Result(Nil, pog.QueryError) {
  let sql =
    "
    UPDATE player_stats
    SET ftue_completed = TRUE,
        updated_at = $1
    WHERE player_id = $2
  "

  pog.query(sql)
  |> pog.parameter(pog.int(now))
  |> pog.parameter(pog.text(player_id))
  |> pog.execute(conn)
  |> result.map(fn(_) { Nil })
}

/// Update stats after a match
pub fn update_stats_after_match(
  conn: pog.Connection,
  player_id: String,
  won: Bool,
  now: Int,
) -> Result(Nil, pog.QueryError) {
  let sql =
    "
    UPDATE player_stats
    SET matches_played = matches_played + 1,
        matches_won = matches_won + $1,
        matches_lost = matches_lost + $2,
        rating = rating + $3,
        updated_at = $4
    WHERE player_id = $5
  "

  let win_increment = case won {
    True -> 1
    False -> 0
  }
  let loss_increment = case won {
    True -> 0
    False -> 1
  }
  let rating_change = case won {
    True -> 25
    False -> -25
  }

  pog.query(sql)
  |> pog.parameter(pog.int(win_increment))
  |> pog.parameter(pog.int(loss_increment))
  |> pog.parameter(pog.int(rating_change))
  |> pog.parameter(pog.int(now))
  |> pog.parameter(pog.text(player_id))
  |> pog.execute(conn)
  |> result.map(fn(_) { Nil })
}

/// Decoder for LeaderboardEntry
fn leaderboard_decoder() -> Decoder(LeaderboardEntry) {
  use player_id <- decode.field(0, decode.string)
  use display_name <- decode.field(1, decode.string)
  use matches_won <- decode.field(2, decode.int)
  use rating <- decode.field(3, decode.int)
  decode.success(LeaderboardEntry(
    rank: 0,
    player_id: player_id,
    display_name: display_name,
    matches_won: matches_won,
    rating: rating,
  ))
}

/// Get leaderboard (top players by rating)
pub fn get_leaderboard(
  conn: pog.Connection,
  limit: Int,
) -> Result(List(LeaderboardEntry), pog.QueryError) {
  let sql =
    "
    SELECT player_id, display_name, matches_won, rating
    FROM player_stats
    ORDER BY rating DESC, matches_won DESC
    LIMIT $1
  "

  use resp <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(limit))
    |> pog.returning(leaderboard_decoder())
    |> pog.execute(conn),
  )

  list.index_map(resp.rows, fn(row, index) {
    LeaderboardEntry(
      rank: index + 1,
      player_id: row.player_id,
      display_name: row.display_name,
      matches_won: row.matches_won,
      rating: row.rating,
    )
  })
  |> Ok
}

/// Get player's rank on leaderboard
pub fn get_player_rank(
  conn: pog.Connection,
  player_id: String,
) -> Result(Option(Int), pog.QueryError) {
  let sql =
    "
    SELECT rank FROM (
      SELECT player_id, ROW_NUMBER() OVER (ORDER BY rating DESC, matches_won DESC) as rank
      FROM player_stats
    ) sub
    WHERE player_id = $1
  "

  let rank_decoder = decode.at([0], decode.int)

  use resp <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(player_id))
    |> pog.returning(rank_decoder)
    |> pog.execute(conn),
  )

  case resp.rows {
    [rank, ..] -> Ok(Some(rank))
    [] -> Ok(None)
  }
}

// ============================================================================
// Player account functions (Google auth)
// ============================================================================

fn player_decoder() -> Decoder(Player) {
  use player_id <- decode.field(0, decode.string)
  use google_sub <- decode.field(1, decode.string)
  use email <- decode.field(2, decode.string)
  use display_name <- decode.field(3, decode.string)
  use avatar_url <- decode.field(4, decode.string)
  use created_at <- decode.field(5, decode.int)
  use updated_at <- decode.field(6, decode.int)
  decode.success(Player(
    player_id: player_id,
    google_sub: google_sub,
    email: email,
    display_name: display_name,
    avatar_url: avatar_url,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

// ============================================================================
// Session token functions
// ============================================================================

/// Create a session token for a player. Returns the token string.
pub fn create_session(
  conn: pog.Connection,
  player_id: String,
  now: Int,
) -> Result(String, pog.QueryError) {
  let token = generate_token()
  let sql =
    "
    INSERT INTO sessions (token, player_id, created_at)
    VALUES ($1, $2, $3)
  "
  use _ <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(token))
    |> pog.parameter(pog.text(player_id))
    |> pog.parameter(pog.int(now))
    |> pog.execute(conn),
  )
  Ok(token)
}

/// Look up a session token. Returns the associated Player if valid.
pub fn lookup_session(
  conn: pog.Connection,
  token: String,
) -> Result(Option(Player), pog.QueryError) {
  let sql =
    "
    SELECT p.player_id, p.google_sub, p.email, p.display_name, p.avatar_url, p.created_at, p.updated_at
    FROM sessions s
    JOIN players p ON s.player_id = p.player_id
    WHERE s.token = $1
  "
  use resp <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(token))
    |> pog.returning(player_decoder())
    |> pog.execute(conn),
  )
  case resp.rows {
    [player, ..] -> Ok(Some(player))
    [] -> Ok(None)
  }
}

/// Delete all sessions for a player (e.g. on logout).
pub fn delete_player_sessions(
  conn: pog.Connection,
  player_id: String,
) -> Result(Nil, pog.QueryError) {
  let sql = "DELETE FROM sessions WHERE player_id = $1"
  pog.query(sql)
  |> pog.parameter(pog.text(player_id))
  |> pog.execute(conn)
  |> result.map(fn(_) { Nil })
}

@external(erlang, "vg_server_ffi", "generate_token")
fn generate_token() -> String

/// Find or create a player by Google sub. Updates display_name/email/avatar on each login.
pub fn get_or_create_google_player(
  conn: pog.Connection,
  google_sub: String,
  email: String,
  display_name: String,
  avatar_url: String,
  now: Int,
) -> Result(Player, pog.QueryError) {
  let player_id = "g_" <> google_sub
  let sql =
    "
    INSERT INTO players (player_id, google_sub, email, display_name, avatar_url, created_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (google_sub) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      email = EXCLUDED.email,
      avatar_url = EXCLUDED.avatar_url,
      updated_at = EXCLUDED.updated_at
    RETURNING player_id, google_sub, email, display_name, avatar_url, created_at, updated_at
  "

  use resp <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(player_id))
    |> pog.parameter(pog.text(google_sub))
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(display_name))
    |> pog.parameter(pog.text(avatar_url))
    |> pog.parameter(pog.int(now))
    |> pog.parameter(pog.int(now))
    |> pog.returning(player_decoder())
    |> pog.execute(conn),
  )

  case resp.rows {
    [player, ..] -> Ok(player)
    [] -> Error(pog.ConnectionUnavailable)
  }
}

@external(erlang, "vg_server_ffi", "generate_anonymous_player")
fn generate_anonymous_player() -> #(String, String)

/// Create an anonymous player with a generated username.
pub fn create_anonymous_player(
  conn: pog.Connection,
  now: Int,
) -> Result(Player, pog.QueryError) {
  let #(player_id, display_name) = generate_anonymous_player()
  let sql =
    "
    INSERT INTO players (player_id, google_sub, email, display_name, avatar_url, created_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING player_id, google_sub, email, display_name, avatar_url, created_at, updated_at
  "

  use resp <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(player_id))
    |> pog.parameter(pog.text(""))
    |> pog.parameter(pog.text(""))
    |> pog.parameter(pog.text(display_name))
    |> pog.parameter(pog.text(""))
    |> pog.parameter(pog.int(now))
    |> pog.parameter(pog.int(now))
    |> pog.returning(player_decoder())
    |> pog.execute(conn),
  )

  case resp.rows {
    [player, ..] -> {
      // Ensure player_stats exists for this anonymous player
      let _ = get_or_create_player_stats(conn, player_id, display_name, now)
      Ok(player)
    }
    [] -> Error(pog.ConnectionUnavailable)
  }
}
