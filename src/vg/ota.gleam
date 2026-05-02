import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

pub const pck_dir = "/app/ota/pck"

const manifest_path = "/app/ota/manifest.json"

pub type State {
  State(manifest: Option(String))
}

pub type Message {
  GetManifest(reply_with: Subject(Option(String)))
  SetManifest(json: String, reply_with: Subject(Result(Nil, String)))
}

pub fn start() {
  let initial = case read_file(manifest_path) {
    Ok(content) -> {
      io.println("[ota] Loaded manifest from disk")
      Some(content)
    }
    Error(_) ->
      case get_env("OTA_MANIFEST_JSON") {
        Ok(env_json) -> {
          io.println("[ota] Loaded manifest from OTA_MANIFEST_JSON env")
          Some(env_json)
        }
        Error(_) -> {
          io.println("[ota] No manifest found — waiting for first publish")
          None
        }
      }
  }

  actor.new(State(manifest: initial))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    GetManifest(reply_with) -> {
      process.send(reply_with, state.manifest)
      actor.continue(state)
    }
    SetManifest(json, reply_with) -> {
      let result = case ensure_dir(pck_dir) {
        Ok(_) -> write_file(manifest_path, json)
        Error(e) -> Error(e)
      }
      case result {
        Ok(_) -> process.send(reply_with, Ok(Nil))
        Error(e) -> process.send(reply_with, Error(e))
      }
      // Always update in-memory even if disk write fails
      actor.continue(State(manifest: Some(json)))
    }
  }
}

pub fn get_manifest(sub: Subject(Message)) -> Option(String) {
  let reply_with = process.new_subject()
  process.send(sub, GetManifest(reply_with))
  case process.receive(reply_with, 5000) {
    Ok(val) -> val
    Error(_) -> None
  }
}

pub fn set_manifest(sub: Subject(Message), json: String) -> Result(Nil, String) {
  let reply_with = process.new_subject()
  process.send(sub, SetManifest(json, reply_with))
  case process.receive(reply_with, 5000) {
    Ok(result) -> result
    Error(_) -> Error("timeout")
  }
}

@external(erlang, "vg_server_ffi", "read_file")
pub fn read_file(path: String) -> Result(String, String)

@external(erlang, "vg_server_ffi", "write_file")
pub fn write_file(path: String, content: String) -> Result(Nil, String)

@external(erlang, "vg_server_ffi", "ensure_dir")
pub fn ensure_dir(path: String) -> Result(Nil, String)

@external(erlang, "vg_server_ffi", "read_binary_file")
pub fn read_binary_file(path: String) -> Result(BitArray, String)

@external(erlang, "vg_server_ffi", "write_binary_file")
pub fn write_binary_file(path: String, data: BitArray) -> Result(Nil, String)

@external(erlang, "vg_server_ffi", "file_exists")
pub fn file_exists(path: String) -> Bool

@external(erlang, "vg_server_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)
