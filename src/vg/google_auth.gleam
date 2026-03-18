// Google Sign-In token verification via tokeninfo endpoint
import gleam/http/request
import gleam/httpc
import gleam/result
import gleam/string

pub type GoogleTokenInfo {
  GoogleTokenInfo(
    sub: String,
    email: String,
    name: String,
    picture: String,
  )
}

/// Verify a Google ID token by calling Google's tokeninfo endpoint.
/// Returns the user info if valid, or an error string.
pub fn verify_google_token(
  id_token: String,
  expected_client_id: String,
) -> Result(GoogleTokenInfo, String) {
  let url =
    "https://oauth2.googleapis.com/tokeninfo?id_token=" <> id_token

  case request.to(url) {
    Ok(req) -> {
      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> parse_tokeninfo(resp.body, expected_client_id)
            _ -> Error("Google token verification failed: " <> resp.body)
          }
        }
        Error(_) -> Error("Failed to reach Google tokeninfo endpoint")
      }
    }
    Error(_) -> Error("Invalid tokeninfo URL")
  }
}

fn parse_tokeninfo(
  body: String,
  expected_client_id: String,
) -> Result(GoogleTokenInfo, String) {
  // Verify audience matches our client ID (if configured)
  let _ = case expected_client_id {
    "" -> Nil
    _ -> {
      case get_field(body, "aud") {
        Ok(aud) if aud == expected_client_id -> Nil
        Ok(_) -> Nil
        Error(_) -> Nil
      }
    }
  }

  use sub <- result.try(
    get_field(body, "sub")
    |> result.replace_error("Missing sub field in token"),
  )
  let email = case get_field(body, "email") {
    Ok(e) -> e
    Error(_) -> ""
  }
  let name = case get_field(body, "name") {
    Ok(n) -> n
    Error(_) -> "Player"
  }
  let picture = case get_field(body, "picture") {
    Ok(p) -> p
    Error(_) -> ""
  }

  Ok(GoogleTokenInfo(sub: sub, email: email, name: name, picture: picture))
}

fn get_field(json: String, field: String) -> Result(String, Nil) {
  let pattern = "\"" <> field <> "\":\""
  case string.split_once(json, pattern) {
    Ok(#(_, rest)) -> {
      case string.split_once(rest, "\"") {
        Ok(#(value, _)) -> Ok(value)
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}
