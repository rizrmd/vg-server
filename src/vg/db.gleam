// Database module for SQLite persistence
import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/result
import sqlight

// Match result record
pub type MatchResult {
  MatchResult(
    match_id: String,
    player1_id: String,
    player2_id: String,
    winner: Int, // 0 = draw/no winner, 1 = team 1, 2 = team 2
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
pub fn init(db_path: String) -> Result(sqlight.Connection, sqlight.Error) {
  use conn <- result.try(sqlight.open(db_path))
  
  // Create match_results table
  let match_results_sql = "
    CREATE TABLE IF NOT EXISTS match_results (
      match_id TEXT PRIMARY KEY,
      player1_id TEXT NOT NULL,
      player2_id TEXT NOT NULL,
      winner INTEGER NOT NULL,
      started_at INTEGER NOT NULL,
      ended_at INTEGER NOT NULL,
      duration_ms INTEGER NOT NULL
    )
  "
  use _ <- result.try(sqlight.exec(match_results_sql, conn))
  
  // Create player_stats table
  let player_stats_sql = "
    CREATE TABLE IF NOT EXISTS player_stats (
      player_id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      matches_played INTEGER DEFAULT 0,
      matches_won INTEGER DEFAULT 0,
      matches_lost INTEGER DEFAULT 0,
      rating INTEGER DEFAULT 1000,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  "
  use _ <- result.try(sqlight.exec(player_stats_sql, conn))
  
  // Create indexes for faster queries
  use _ <- result.try(sqlight.exec(
    "CREATE INDEX IF NOT EXISTS idx_match_results_player1 ON match_results(player1_id)",
    conn,
  ))
  use _ <- result.try(sqlight.exec(
    "CREATE INDEX IF NOT EXISTS idx_match_results_player2 ON match_results(player2_id)",
    conn,
  ))
  use _ <- result.try(sqlight.exec(
    "CREATE INDEX IF NOT EXISTS idx_match_results_ended_at ON match_results(ended_at)",
    conn,
  ))
  use _ <- result.try(sqlight.exec(
    "CREATE INDEX IF NOT EXISTS idx_player_stats_rating ON player_stats(rating DESC)",
    conn,
  ))
  use _ <- result.try(sqlight.exec(
    "CREATE INDEX IF NOT EXISTS idx_player_stats_wins ON player_stats(matches_won DESC)",
    conn,
  ))
  
  Ok(conn)
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
pub fn save_match_result(conn: sqlight.Connection, result: MatchResult) -> Result(Nil, sqlight.Error) {
  let sql = "
    INSERT INTO match_results (match_id, player1_id, player2_id, winner, started_at, ended_at, duration_ms)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  "
  sqlight.query(
    sql,
    on: conn,
    with: [
      sqlight.text(result.match_id),
      sqlight.text(result.player1_id),
      sqlight.text(result.player2_id),
      sqlight.int(result.winner),
      sqlight.int(result.started_at),
      sqlight.int(result.ended_at),
      sqlight.int(result.duration_ms),
    ],
    expecting: decode.dynamic,
  )
  |> result.map(fn(_) { Nil })
}

/// Get match history for a player
pub fn get_player_match_history(
  conn: sqlight.Connection,
  player_id: String,
  limit: Int,
  offset: Int,
) -> Result(List(MatchResult), sqlight.Error) {
  let sql = "
    SELECT match_id, player1_id, player2_id, winner, started_at, ended_at, duration_ms
    FROM match_results
    WHERE player1_id = ? OR player2_id = ?
    ORDER BY ended_at DESC
    LIMIT ? OFFSET ?
  "
  
  sqlight.query(
    sql,
    on: conn,
    with: [
      sqlight.text(player_id),
      sqlight.text(player_id),
      sqlight.int(limit),
      sqlight.int(offset),
    ],
    expecting: match_result_decoder(),
  )
}

/// Get a single match result
pub fn get_match_result(
  conn: sqlight.Connection,
  match_id: String,
) -> Result(Option(MatchResult), sqlight.Error) {
  let sql = "
    SELECT match_id, player1_id, player2_id, winner, started_at, ended_at, duration_ms
    FROM match_results
    WHERE match_id = ?
  "
  
  use rows <- result.try(sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(match_id)],
    expecting: match_result_decoder(),
  ))
  
  case rows {
    [result, ..] -> Ok(Some(result))
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
  use created_at <- decode.field(6, decode.int)
  use updated_at <- decode.field(7, decode.int)
  decode.success(PlayerStats(
    player_id: player_id,
    display_name: display_name,
    matches_played: matches_played,
    matches_won: matches_won,
    matches_lost: matches_lost,
    rating: rating,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

/// Upsert player stats (insert or update)
pub fn upsert_player_stats(conn: sqlight.Connection, stats: PlayerStats) -> Result(Nil, sqlight.Error) {
  let sql = "
    INSERT INTO player_stats (player_id, display_name, matches_played, matches_won, matches_lost, rating, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(player_id) DO UPDATE SET
      display_name = excluded.display_name,
      matches_played = excluded.matches_played,
      matches_won = excluded.matches_won,
      matches_lost = excluded.matches_lost,
      rating = excluded.rating,
      updated_at = excluded.updated_at
  "
  
  sqlight.query(
    sql,
    on: conn,
    with: [
      sqlight.text(stats.player_id),
      sqlight.text(stats.display_name),
      sqlight.int(stats.matches_played),
      sqlight.int(stats.matches_won),
      sqlight.int(stats.matches_lost),
      sqlight.int(stats.rating),
      sqlight.int(stats.created_at),
      sqlight.int(stats.updated_at),
    ],
    expecting: decode.dynamic,
  )
  |> result.map(fn(_) { Nil })
}

/// Get player stats
pub fn get_player_stats(
  conn: sqlight.Connection,
  player_id: String,
) -> Result(Option(PlayerStats), sqlight.Error) {
  let sql = "
    SELECT player_id, display_name, matches_played, matches_won, matches_lost, rating, created_at, updated_at
    FROM player_stats
    WHERE player_id = ?
  "
  
  use rows <- result.try(sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(player_id)],
    expecting: player_stats_decoder(),
  ))
  
  case rows {
    [stats, ..] -> Ok(Some(stats))
    [] -> Ok(None)
  }
}

/// Get or create player stats (creates default if not exists)
pub fn get_or_create_player_stats(
  conn: sqlight.Connection,
  player_id: String,
  display_name: String,
  now: Int,
) -> Result(PlayerStats, sqlight.Error) {
  case get_player_stats(conn, player_id) {
    Ok(Some(stats)) -> Ok(stats)
    Ok(None) -> {
      let stats = PlayerStats(
        player_id: player_id,
        display_name: display_name,
        matches_played: 0,
        matches_won: 0,
        matches_lost: 0,
        rating: 1000,
        created_at: now,
        updated_at: now,
      )
      use _ <- result.try(upsert_player_stats(conn, stats))
      Ok(stats)
    }
    Error(e) -> Error(e)
  }
}

/// Update stats after a match
pub fn update_stats_after_match(
  conn: sqlight.Connection,
  player_id: String,
  won: Bool,
  now: Int,
) -> Result(Nil, sqlight.Error) {
  let sql = "
    UPDATE player_stats
    SET matches_played = matches_played + 1,
        matches_won = matches_won + ?,
        matches_lost = matches_lost + ?,
        rating = rating + ?,
        updated_at = ?
    WHERE player_id = ?
  "
  
  let win_increment = case won { True -> 1 False -> 0 }
  let loss_increment = case won { True -> 0 False -> 1 }
  let rating_change = case won { True -> 25 False -> -25 }
  
  sqlight.query(
    sql,
    on: conn,
    with: [
      sqlight.int(win_increment),
      sqlight.int(loss_increment),
      sqlight.int(rating_change),
      sqlight.int(now),
      sqlight.text(player_id),
    ],
    expecting: decode.dynamic,
  )
  |> result.map(fn(_) { Nil })
}

/// Decoder for LeaderboardEntry
fn leaderboard_decoder() -> Decoder(LeaderboardEntry) {
  use player_id <- decode.field(0, decode.string)
  use display_name <- decode.field(1, decode.string)
  use matches_won <- decode.field(2, decode.int)
  use rating <- decode.field(3, decode.int)
  decode.success(LeaderboardEntry(
    rank: 0, // Will be set after query
    player_id: player_id,
    display_name: display_name,
    matches_won: matches_won,
    rating: rating,
  ))
}

/// Get leaderboard (top players by rating)
pub fn get_leaderboard(
  conn: sqlight.Connection,
  limit: Int,
) -> Result(List(LeaderboardEntry), sqlight.Error) {
  let sql = "
    SELECT player_id, display_name, matches_won, rating
    FROM player_stats
    ORDER BY rating DESC, matches_won DESC
    LIMIT ?
  "
  
  use rows <- result.try(sqlight.query(
    sql,
    on: conn,
    with: [sqlight.int(limit)],
    expecting: leaderboard_decoder(),
  ))
  
  list.index_map(rows, fn(row, index) {
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
  conn: sqlight.Connection,
  player_id: String,
) -> Result(Option(Int), sqlight.Error) {
  let sql = "
    SELECT rank FROM (
      SELECT player_id, ROW_NUMBER() OVER (ORDER BY rating DESC, matches_won DESC) as rank
      FROM player_stats
    )
    WHERE player_id = ?
  "
  
  let rank_decoder = decode.at([0], decode.int)
  
  use rows <- result.try(sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(player_id)],
    expecting: rank_decoder,
  ))
  
  case rows {
    [rank, ..] -> Ok(Some(rank))
    [] -> Ok(None)
  }
}

/// Close database connection
pub fn close(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.close(conn)
}
