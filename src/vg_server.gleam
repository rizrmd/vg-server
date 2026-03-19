import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import mist.{type Connection, type ResponseData}
import pog
import vg/connection_registry
import vg/db
import vg/match_orchestrator
import vg/match_registry
import vg/matchmaking
import vg/player_registry
import vg/websocket

const default_port = 7567

const default_db_url = "postgres://postgres:6LP0Ojegy7IUU6kaX9lLkmZRUiAdAUNOltWyL3LegfYGR6rPQtB4DUSVqjdA78ES@107.155.75.50:5986/postgres"

fn get_env(name: String, default: String) -> String {
  case do_get_env(name) {
    Ok(value) -> value
    Error(_) -> default
  }
}

@external(erlang, "vg_server_ffi", "get_env")
fn do_get_env(name: String) -> Result(String, Nil)

pub fn main() {
  io.println("Starting Vanguard's Gambit Server...")

  let db_url = get_env("DATABASE_URL", default_db_url)

  io.println("Connecting to PostgreSQL database...")
  let db_result = db.init(db_url)
  case db_result {
    Ok(conn) -> {
      io.println("Database initialized successfully")
      start_server_with_db(conn)
    }
    Error(err) -> {
      io.println("Failed to initialize database: " <> err)
      // Start without database
      start_server_without_db()
    }
  }
}

fn start_server_with_db(conn: pog.Connection) {
  // Start registries
  let assert Ok(actor.Started(pid: _, data: player_registry)) =
    player_registry.start()
  io.println("Player registry started")

  let assert Ok(actor.Started(pid: _, data: matchmaking_queue)) =
    matchmaking.start()
  io.println("Matchmaking queue started")

  let assert Ok(actor.Started(pid: _, data: match_registry)) =
    match_registry.start()
  io.println("Match registry started")

  // Start connection registry for WebSocket notifications
  let assert Ok(actor.Started(pid: _, data: conn_registry)) =
    connection_registry.start()
  io.println("Connection registry started")

  // Pass DB connection to match registry
  match_registry.set_db_conn(match_registry, conn)
  // Start the match orchestrator
  run_server(
    player_registry,
    matchmaking_queue,
    match_registry,
    conn_registry,
    Ok(conn),
  )
}

fn start_server_without_db() {
  io.println("WARNING: Running without database persistence")

  // Start registries
  let assert Ok(actor.Started(pid: _, data: player_registry)) =
    player_registry.start()
  io.println("Player registry started")

  let assert Ok(actor.Started(pid: _, data: matchmaking_queue)) =
    matchmaking.start()
  io.println("Matchmaking queue started")

  let assert Ok(actor.Started(pid: _, data: match_registry)) =
    match_registry.start()
  io.println("Match registry started")

  // Start connection registry for WebSocket notifications
  let assert Ok(actor.Started(pid: _, data: conn_registry)) =
    connection_registry.start()
  io.println("Connection registry started")

  run_server(
    player_registry,
    matchmaking_queue,
    match_registry,
    conn_registry,
    Error(Nil),
  )
}

fn run_server(
  player_registry: process.Subject(player_registry.Message),
  matchmaking_queue: process.Subject(matchmaking.Message),
  match_registry: process.Subject(match_registry.Message),
  conn_registry: process.Subject(connection_registry.Message),
  db_conn: Result(pog.Connection, Nil),
) {
  let assert Ok(actor.Started(pid: _, data: orchestrator)) =
    match_orchestrator.start(matchmaking_queue, match_registry, conn_registry)
  io.println("Match orchestrator started")

  // Start matchmaking loop
  match_orchestrator.run_matchmaking(orchestrator)
  io.println("Matchmaking loop started")

  // Start match tick loop
  match_orchestrator.tick_matches(orchestrator, 0)
  io.println("Match tick loop started")

  // Start the main supervisor
  let assert Ok(_) = start_supervisor()
  io.println("Supervisor started")

  // Start the HTTP/WebSocket server
  let opt_conn = case db_conn {
    Ok(conn) -> Some(conn)
    Error(_) -> None
  }
  let server_port = case int.parse(get_env("PORT", "")) {
    Ok(p) -> p
    Error(_) -> default_port
  }
  let google_client_id = get_env("GOOGLE_CLIENT_ID", "")
  let assert Ok(_) =
    start_http_server(
      player_registry,
      matchmaking_queue,
      match_registry,
      conn_registry,
      opt_conn,
      server_port,
      google_client_id,
    )
  io.println(
    "WebSocket server listening on port " <> int.to_string(server_port),
  )

  case db_conn {
    Ok(_) -> io.println("Database persistence: ENABLED")
    Error(_) -> io.println("Database persistence: DISABLED")
  }

  io.println("Server started successfully!")

  // Keep the main process alive
  process.sleep_forever()
}

fn start_supervisor() {
  supervisor.new(supervisor.OneForOne)
  // Future: Add supervised child processes here
  |> supervisor.start
}

fn start_http_server(
  player_registry: process.Subject(player_registry.Message),
  matchmaking_queue: process.Subject(matchmaking.Message),
  match_registry: process.Subject(match_registry.Message),
  conn_registry: process.Subject(connection_registry.Message),
  db_conn: Option(pog.Connection),
  port: Int,
  google_client_id: String,
) {
  let handler = fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      ["ws"] ->
        websocket.handle_websocket(
          req,
          player_registry,
          matchmaking_queue,
          match_registry,
          conn_registry,
          db_conn,
          google_client_id,
        )
      ["sign-in", "test"] -> {
        response.new(200)
        |> response.set_body(
          mist.Bytes(bytes_tree.from_string(sign_in_test_page(google_client_id))),
        )
        |> response.set_header("content-type", "text/html")
      }
      ["sign-in", "desktop"] -> {
        let port_str = case request.get_query(req) {
          Ok(params) ->
            case list.key_find(params, "port") {
              Ok(p) -> p
              Error(_) -> ""
            }
          Error(_) -> ""
        }
        response.new(200)
        |> response.set_body(
          mist.Bytes(
            bytes_tree.from_string(sign_in_desktop_page(
              google_client_id,
              port_str,
            )),
          ),
        )
        |> response.set_header("content-type", "text/html")
      }
      _ -> {
        response.new(200)
        |> response.set_body(mist.Bytes(bytes_tree.from_string("VG Server")))
      }
    }
  }

  mist.new(handler)
  |> mist.port(port)
  |> mist.bind("0.0.0.0")
  |> mist.start()
}

fn sign_in_test_page(client_id: String) -> String {
  "<!DOCTYPE html>
<html>
<head>
  <title>VG Server - Google Sign-In Test</title>
  <script src=\"https://accounts.google.com/gsi/client\" async defer></script>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 40px auto; padding: 0 20px; }
    .log { margin-top: 20px; }
    .log div { padding: 4px 0; border-bottom: 1px solid #eee; font-size: 14px; }
    .ok { color: green; } .err { color: red; } .info { color: #666; }
    button { padding: 8px 16px; margin: 4px; cursor: pointer; }
    h1 { font-size: 1.4em; }
    .profile { background: #f0f7f0; border: 1px solid #c3e6c3; border-radius: 8px; padding: 16px; margin: 16px 0; }
    .profile h3 { margin: 0 0 8px 0; }
    .hidden { display: none; }
  </style>
</head>
<body>
  <h1>VG Server - Google Sign-In Test</h1>

  <div id=\"signInSection\">
    <div id=\"g_id_onload\"
      data-client_id=\"" <> client_id <> "\"
      data-callback=\"onSignIn\"
      data-auto_prompt=\"false\">
    </div>
    <div class=\"g_id_signin\" data-type=\"standard\" data-size=\"large\"></div>
  </div>

  <div id=\"profileSection\" class=\"profile hidden\">
    <h3 id=\"profileName\"></h3>
    <div id=\"profileInfo\" style=\"font-size:14px;color:#555\"></div>
    <button onclick=\"logout()\" style=\"margin-top:8px;background:#f44;color:#fff;border:none;border-radius:4px\">Logout</button>
  </div>

  <div style=\"margin-top:16px\" id=\"controls\" class=\"hidden\">
    <button onclick=\"connectAndAuth()\">Connect &amp; Authenticate</button>
    <span id=\"wsStatus\" style=\"font-size:13px;color:#999\"></span>
  </div>

  <div class=\"log\" id=\"log\"></div>

  <script>
    let ws = null, idToken = null, authenticated = false;

    const log = (msg, cls) => {
      const d = document.createElement('div');
      d.className = cls || 'info';
      d.textContent = new Date().toLocaleTimeString() + ' ' + msg;
      document.getElementById('log').prepend(d);
    };

    function showProfile(data) {
      document.getElementById('signInSection').classList.add('hidden');
      document.getElementById('profileSection').classList.remove('hidden');
      document.getElementById('controls').classList.remove('hidden');
      document.getElementById('profileName').textContent = data.display_name;
      document.getElementById('profileInfo').textContent = data.email + ' | ' + data.player_id;
      localStorage.setItem('vg_auth', JSON.stringify(data));
    }

    function hideProfile() {
      document.getElementById('signInSection').classList.remove('hidden');
      document.getElementById('profileSection').classList.add('hidden');
      document.getElementById('controls').classList.add('hidden');
    }

    // Check localStorage on load
    const saved = localStorage.getItem('vg_auth');
    if (saved) {
      try {
        const data = JSON.parse(saved);
        showProfile(data);
        log('Restored session: ' + data.display_name + ' (' + data.player_id + ')', 'ok');
      } catch(e) { localStorage.removeItem('vg_auth'); }
    }

    function onSignIn(response) {
      idToken = response.credential;
      localStorage.setItem('vg_id_token', idToken);
      log('Got Google ID token (' + idToken.length + ' chars)', 'ok');
      document.getElementById('controls').classList.remove('hidden');
      connectAndAuth();
    }

    function connectAndAuth() {
      const token = idToken || localStorage.getItem('vg_id_token');
      if (!token) return log('No Google token. Please sign in first.', 'err');
      idToken = token;

      if (ws && ws.readyState === 1) {
        sendAuth();
        return;
      }

      const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
      ws = new WebSocket(proto + '//' + location.host + '/ws');
      document.getElementById('wsStatus').textContent = 'connecting...';

      ws.onopen = () => {
        log('WebSocket connected', 'ok');
        document.getElementById('wsStatus').textContent = 'connected';
        sendAuth();
      };
      ws.onclose = () => {
        log('WebSocket closed', 'err');
        document.getElementById('wsStatus').textContent = 'disconnected';
        authenticated = false;
      };
      ws.onmessage = (e) => {
        log('Server: ' + e.data, 'info');
        try {
          const msg = JSON.parse(e.data);
          if (msg.type === 'authenticated') {
            authenticated = true;
            showProfile(msg);
            log('Authenticated as ' + msg.player_id + ' (' + msg.display_name + ')', 'ok');
          }
          if (msg.type === 'auth_error') {
            log('Auth error: ' + msg.message, 'err');
            // Token might be expired, clear it
            localStorage.removeItem('vg_id_token');
            idToken = null;
          }
        } catch(e) {}
      };
    }

    function sendAuth() {
      if (!ws || ws.readyState !== 1) return log('WebSocket not connected', 'err');
      if (!idToken) return log('No Google token', 'err');
      ws.send(JSON.stringify({type: 'authenticate', id_token: idToken}));
      log('Sent authenticate message', 'info');
    }

    function logout() {
      localStorage.removeItem('vg_auth');
      localStorage.removeItem('vg_id_token');
      idToken = null;
      authenticated = false;
      if (ws) { ws.close(); ws = null; }
      hideProfile();
      log('Logged out', 'info');
      // Revoke Google session
      google.accounts.id.disableAutoSelect();
    }
  </script>
</body>
</html>"
}

fn sign_in_desktop_page(client_id: String, port: String) -> String {
  case port {
    "" ->
      "<!DOCTYPE html><html><head><title>Error</title>
<style>body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#111;color:#fff;}</style>
</head><body><h2>Missing port parameter.</h2></body></html>"
    _ ->
      "<!DOCTYPE html>
<html>
<head>
  <title>VanGambit - Sign In</title>
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <script src=\"https://accounts.google.com/gsi/client\" async defer></script>
  <style>
    body { font-family: system-ui, sans-serif; display: flex; justify-content: center;
      align-items: center; min-height: 100vh; margin: 0; background: #111; color: #fff; }
    .container { text-align: center; }
    h1 { font-size: 1.6em; margin-bottom: 24px; }
    #status { margin-top: 16px; color: #aaa; font-size: 14px; }
  </style>
</head>
<body>
  <div class=\"container\">
    <h1>Sign in to VanGambit</h1>
    <div id=\"signInSection\">
      <div id=\"g_id_onload\"
        data-client_id=\""
      <> client_id
      <> "\"
        data-callback=\"onSignIn\"
        data-auto_prompt=\"false\">
      </div>
      <div class=\"g_id_signin\" data-type=\"standard\" data-size=\"large\" data-theme=\"filled_black\"></div>
    </div>
    <div id=\"status\"></div>
  </div>
  <script>
    function onSignIn(response) {
      var idToken = response.credential;
      var parts = idToken.split('.');
      var payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
      document.getElementById('signInSection').style.display = 'none';
      document.getElementById('status').textContent = 'Signed in! Redirecting back to game...';
      var params = new URLSearchParams({
        id_token: idToken,
        email: payload.email || '',
        display_name: payload.name || payload.email || ''
      });
      window.location.href = 'http://127.0.0.1:"
      <> port
      <> "/callback?' + params.toString();
    }
  </script>
</body>
</html>"
  }
}
