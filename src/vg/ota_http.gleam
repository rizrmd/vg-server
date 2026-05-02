import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData}
import vg/ota

// Route: GET /ota/manifest.json
pub fn handle_manifest(
  sub: Subject(ota.Message),
) -> Response(ResponseData) {
  case ota.get_manifest(sub) {
    Some(json) ->
      response.new(200)
      |> response.set_body(mist.Bytes(bytes_tree.from_string(json)))
      |> response.set_header("content-type", "application/json")
      |> response.set_header("cache-control", "no-cache")
    None ->
      response.new(404)
      |> response.set_body(
        mist.Bytes(bytes_tree.from_string("{\"error\":\"no manifest published yet\"}")),
      )
      |> response.set_header("content-type", "application/json")
  }
}

// Route: GET /ota/pck/{filename}
pub fn handle_pck_get(filename: String) -> Response(ResponseData) {
  let safe = sanitize_filename(filename)
  case string.ends_with(safe, ".pck") {
    False ->
      response.new(400)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Bad filename")))
    True -> {
      let path = ota.pck_dir <> "/" <> safe
      case ota.file_exists(path) {
        False ->
          response.new(404)
          |> response.set_body(mist.Bytes(bytes_tree.from_string("Not found")))
        True ->
          case ota.read_binary_file(path) {
            Ok(data) ->
              response.new(200)
              |> response.set_body(
                mist.Bytes(bytes_tree.from_bit_array(data)),
              )
              |> response.set_header("content-type", "application/octet-stream")
              |> response.set_header(
                "content-disposition",
                "attachment; filename=\"" <> safe <> "\"",
              )
            Error(_) ->
              response.new(500)
              |> response.set_body(
                mist.Bytes(bytes_tree.from_string("Read error")),
              )
          }
      }
    }
  }
}

// Route: POST /ota/publish   body=manifest JSON   header: X-OTA-Secret
pub fn handle_publish(
  req: request.Request(Connection),
  sub: Subject(ota.Message),
  secret: String,
) -> Response(ResponseData) {
  case req.method {
    http.Post ->
      case check_secret(req, secret) {
        False -> unauthorized()
        True ->
          case mist.read_body(req, 1_000_000) {
            Ok(r) ->
              case bit_array.to_string(r.body) {
                Ok(json) ->
                  case ota.set_manifest(sub, json) {
                    Ok(_) ->
                      response.new(200)
                      |> response.set_body(
                        mist.Bytes(bytes_tree.from_string("{\"ok\":true}")),
                      )
                      |> response.set_header("content-type", "application/json")
                    Error(err) ->
                      response.new(500)
                      |> response.set_body(
                        mist.Bytes(
                          bytes_tree.from_string(
                            "{\"error\":\"" <> err <> "\"}",
                          ),
                        ),
                      )
                      |> response.set_header("content-type", "application/json")
                  }
                Error(_) ->
                  response.new(400)
                  |> response.set_body(
                    mist.Bytes(
                      bytes_tree.from_string("{\"error\":\"invalid utf-8\"}"),
                    ),
                  )
                  |> response.set_header("content-type", "application/json")
              }
            Error(_) ->
              response.new(400)
              |> response.set_body(
                mist.Bytes(
                  bytes_tree.from_string("{\"error\":\"body read failed\"}"),
                ),
              )
              |> response.set_header("content-type", "application/json")
          }
      }
    _ ->
      response.new(405)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Method Not Allowed")))
  }
}

// Route: POST /ota/pck/upload/{filename}   body=raw PCK bytes   header: X-OTA-Secret
pub fn handle_pck_upload(
  req: request.Request(Connection),
  filename: String,
  secret: String,
) -> Response(ResponseData) {
  case req.method {
    http.Post ->
      case check_secret(req, secret) {
        False -> unauthorized()
        True -> {
          let safe = sanitize_filename(filename)
          case string.ends_with(safe, ".pck") {
            False ->
              response.new(400)
              |> response.set_body(
                mist.Bytes(
                  bytes_tree.from_string("{\"error\":\"filename must end with .pck\"}"),
                ),
              )
              |> response.set_header("content-type", "application/json")
            True ->
              case mist.read_body(req, 200_000_000) {
                // 200 MB
                Ok(r) -> {
                  let path = ota.pck_dir <> "/" <> safe
                  case ota.ensure_dir(ota.pck_dir) {
                    Ok(_) ->
                      case ota.write_binary_file(path, r.body) {
                        Ok(_) ->
                          response.new(200)
                          |> response.set_body(
                            mist.Bytes(bytes_tree.from_string("{\"ok\":true}")),
                          )
                          |> response.set_header(
                            "content-type",
                            "application/json",
                          )
                        Error(err) ->
                          response.new(500)
                          |> response.set_body(
                            mist.Bytes(
                              bytes_tree.from_string(
                                "{\"error\":\"" <> err <> "\"}",
                              ),
                            ),
                          )
                          |> response.set_header(
                            "content-type",
                            "application/json",
                          )
                      }
                    Error(err) ->
                      response.new(500)
                      |> response.set_body(
                        mist.Bytes(
                          bytes_tree.from_string(
                            "{\"error\":\"mkdir " <> err <> "\"}",
                          ),
                        ),
                      )
                      |> response.set_header("content-type", "application/json")
                  }
                }
                Error(_) ->
                  response.new(400)
                  |> response.set_body(
                    mist.Bytes(
                      bytes_tree.from_string("{\"error\":\"body read failed\"}"),
                    ),
                  )
                  |> response.set_header("content-type", "application/json")
              }
          }
        }
      }
    _ ->
      response.new(405)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Method Not Allowed")))
  }
}

fn check_secret(req: request.Request(Connection), secret: String) -> Bool {
  case secret {
    "" -> False
    _ ->
      case request.get_header(req, "x-ota-secret") {
        Ok(provided) -> provided == secret
        Error(_) -> False
      }
  }
}

fn unauthorized() -> Response(ResponseData) {
  response.new(401)
  |> response.set_body(
    mist.Bytes(bytes_tree.from_string("{\"error\":\"unauthorized\"}")),
  )
  |> response.set_header("content-type", "application/json")
}

fn sanitize_filename(name: String) -> String {
  name
  |> string.split("/")
  |> list.last
  |> result.unwrap(name)
  |> string.split("\\")
  |> list.last
  |> result.unwrap(name)
}
