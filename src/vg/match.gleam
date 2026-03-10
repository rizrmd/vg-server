// Simplified Match module using correct Gleam OTP actor API

import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import vg/types.{type GameMatch, GameMatch, Waiting, Active, Finished, NoWinner}

pub type MatchState {
  MatchState(
    match: GameMatch,
    players: List(String),
  )
}

pub type Message {
  JoinMatch(player_id: String, reply_to: Subject(Result(Nil, String)))
  GetState(reply_to: Subject(MatchState))
}

pub fn start(match_id: String) {
  let initial_state = MatchState(
    match: GameMatch(
      match_id: match_id,
      phase: Waiting,
      created_at: 0,
      started_at: 0,
      winner: NoWinner,
    ),
    players: [],
  )
  
  actor.new(initial_state)
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  state: MatchState,
  message: Message,
) -> actor.Next(MatchState, Message) {
  case message {
    JoinMatch(player_id, reply_to) -> {
      let new_players = [player_id, ..state.players]
      let new_state = MatchState(..state, players: new_players)
      process.send(reply_to, Ok(Nil))
      actor.continue(new_state)
    }
    GetState(reply_to) -> {
      process.send(reply_to, state)
      actor.continue(state)
    }
  }
}
