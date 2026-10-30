#!/usr/bin/env python3
"""Ponte local entre o shell (QML) e a aba do YouTube Music no Zen.

O shell inicia este servidor em 127.0.0.1:26541. O userscript
(services/ytm_bridge.user.js, instalado no Tampermonkey do Zen) faz polling de
/commands e publica o estado da aba em /state. O shell consulta /state e envia
comandos por /command.

Além disso, o servidor lê o zen-sessions.jsonlz4 para saber se existe uma aba do
YTM aberta mesmo quando o userscript ainda não conectou. Isso evita que o popup
abra uma segunda aba quando o player MPRIS não está disponível.
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HOST = "127.0.0.1"
PORT = 26541
STATE_TTL = 3.0       # um cliente é considerado conectado por até 3 s sem heartbeat
COMMAND_TTL = 10.0    # comandos não consumidos expiram (evita replay ao reabrir)
MAX_COMMANDS = 20
MAX_BODY = 64 * 1024

SCRIPT_PATH = Path(__file__).resolve().with_name("ytm_bridge.user.js")

_lock = threading.Lock()
_clients: dict[str, dict] = {}
_commands: dict[str, list[dict]] = {}
_next_command_id = 1

_session_cache_key: tuple | None = None
_session_cache: dict = {
    "hasYtmTab": False,
    "ytmTabCount": 0,
    "sessionFile": "",
    "sessionError": "",
}

_browser_cache_at = 0.0
_browser_cache = True


# ─────────────────────────────────────────────────────────────────────────────
# Leitura do session store do Zen (mozLz4)
# ─────────────────────────────────────────────────────────────────────────────

def _lz4_block_decompress(src: bytes, expected: int) -> bytes:
    """Descompacta um bloco LZ4 cru (fallback sem o módulo python3-lz4)."""
    out = bytearray()
    i, n = 0, len(src)
    while i < n:
        token = src[i]
        i += 1

        literal_len = token >> 4
        if literal_len == 15:
            while True:
                b = src[i]
                i += 1
                literal_len += b
                if b != 255:
                    break

        if literal_len:
            out += src[i:i + literal_len]
            i += literal_len
        if i >= n:
            break

        if i + 2 > n:
            raise ValueError("bloco LZ4 truncado (offset)")
        offset = src[i] | (src[i + 1] << 8)
        i += 2
        if offset == 0 or offset > len(out):
            raise ValueError("offset LZ4 inválido")

        match_len = token & 0x0F
        if match_len == 15:
            while True:
                b = src[i]
                i += 1
                match_len += b
                if b != 255:
                    break
        match_len += 4

        start = len(out) - offset
        for j in range(match_len):
            out.append(out[start + j])

    if expected and len(out) != expected:
        raise ValueError(f"tamanho LZ4 inesperado: {len(out)} != {expected}")
    return bytes(out)


def _decompress_mozlz4(data: bytes) -> bytes:
    """Descompacta o formato mozLz40 usado pelo Firefox/Zen."""
    if len(data) < 12 or data[:8] != b"mozLz40\0":
        raise ValueError("arquivo não é mozLz4")
    size = struct.unpack("<I", data[8:12])[0]
    payload = data[12:]
    try:
        import lz4.block  # type: ignore
        return lz4.block.decompress(payload, uncompressed_size=size)
    except ImportError:
        return _lz4_block_decompress(payload, size)


def _session_candidates() -> list[Path]:
    home = Path.home()
    roots = [
        home / ".var/app/app.zen_browser.zen/config/zen",
        home / ".var/app/app.zen_browser.zen/.zen",
        home / ".zen",
        home / ".config/zen",
        home / ".mozilla/zen",
    ]
    patterns = (
        "*/zen-sessions.jsonlz4",
        "*/sessionstore-backups/recovery.jsonlz4",
        "*/sessionstore.jsonlz4",
    )
    found: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for pattern in patterns:
            found.extend(root.glob(pattern))
    return found


def _session_file() -> Path | None:
    candidates = [p for p in _session_candidates() if p.is_file()]
    if not candidates:
        return None

    newest = max(candidates, key=lambda p: p.stat().st_mtime)
    # O zen-sessions.jsonlz4 é o store específico do Zen (menor e sem o lixo do
    # sessionstore do Firefox). Se ele estiver atualizado, prefira-o; senão fica
    # com o arquivo mais recente (recovery/sessionstore) como fallback.
    zen_sessions = [p for p in candidates if p.name == "zen-sessions.jsonlz4"]
    if zen_sessions:
        best_zen = max(zen_sessions, key=lambda p: p.stat().st_mtime)
        try:
            if newest.stat().st_mtime - best_zen.stat().st_mtime <= 60:
                return best_zen
        except OSError:
            pass
    return newest


def _url_is_ytm(url: object) -> bool:
    if not isinstance(url, str):
        return False
    return url.startswith("https://music.youtube.com/") or url == "https://music.youtube.com"


def _count_ytm_tabs(obj: dict) -> int:
    tabs: list[dict] = []
    if isinstance(obj.get("tabs"), list):          # Zen (zen-sessions.jsonlz4)
        tabs = obj["tabs"]
    elif isinstance(obj.get("windows"), list):     # Firefox (sessionstore*.jsonlz4)
        for window in obj["windows"]:
            if isinstance(window, dict) and isinstance(window.get("tabs"), list):
                tabs.extend(window["tabs"])

    count = 0
    for tab in tabs:
        if not isinstance(tab, dict):
            continue
        # Glance é uma prévia transitória, não uma aba de verdade.
        if tab.get("zenIsGlance"):
            continue
        entries = tab.get("entries")
        if not isinstance(entries, list):
            continue
        if any(_url_is_ytm(entry.get("url")) for entry in entries if isinstance(entry, dict)):
            count += 1
    return count


def _zen_running() -> bool:
    """Diz se o processo principal do Zen está rodando.

    O session store continua no disco depois que o navegador fecha, então sem
    esta checagem uma aba antiga do YTM seria considerada \"aberta\" para sempre
    (e o popup nunca abriria o navegador de novo).
    """
    global _browser_cache_at, _browser_cache

    now = _now()
    if now - _browser_cache_at < 1.0:
        return _browser_cache

    running = False
    try:
        for entry in Path("/proc").iterdir():
            if not entry.name.isdigit():
                continue
            try:
                raw = (entry / "cmdline").read_bytes()
            except OSError:
                continue
            if not raw:
                continue
            parts = raw.split(b"\0")
            exe = os.path.basename(parts[0].decode("utf-8", "replace")).lower()
            if exe not in ("zen", "zen-bin"):
                continue
            joined = b" ".join(parts).lower()
            if b"-contentproc" in joined:  # subprocessos do navegador
                continue
            running = True
            break
    except OSError:
        # Sem /proc (ou sem permissão), não bloqueia a detecção pela sessão.
        running = True

    _browser_cache_at = now
    _browser_cache = running
    return running


def _session_info() -> dict:
    """Retorna (com cache por mtime) se existe alguma aba do YTM aberta."""
    global _session_cache_key, _session_cache

    path = _session_file()
    if path is None:
        _session_cache_key = None
        _session_cache = {
            "hasYtmTab": False,
            "ytmTabCount": 0,
            "sessionFile": "",
            "sessionError": "",
        }
        return dict(_session_cache)

    try:
        st = path.stat()
        key = (str(path), st.st_mtime_ns, st.st_size)
    except OSError as exc:
        key = None
        _session_cache["sessionError"] = str(exc)

    if key is not None and key == _session_cache_key:
        return dict(_session_cache)

    try:
        raw = _decompress_mozlz4(path.read_bytes())
        obj = json.loads(raw)
        count = _count_ytm_tabs(obj)
        _session_cache = {
            "hasYtmTab": count > 0,
            "ytmTabCount": count,
            "sessionFile": str(path),
            "sessionError": "",
        }
        _session_cache_key = key
    except Exception as exc:  # arquivo em escrita, versão nova etc.
        # Mantém o último resultado bom; só registra o erro.
        _session_cache["sessionError"] = str(exc)
        if _session_cache_key is None:
            _session_cache["sessionFile"] = str(path)

    return dict(_session_cache)


# ─────────────────────────────────────────────────────────────────────────────
# Estado dos clientes (aba do YTM) e fila de comandos
# ─────────────────────────────────────────────────────────────────────────────

def _now() -> float:
    return time.monotonic()


def _prune_clients() -> None:
    cutoff = _now() - STATE_TTL
    dead = [cid for cid, c in _clients.items() if c["last_seen"] < cutoff]
    for cid in dead:
        _clients.pop(cid, None)
        _commands.pop(cid, None)


def _active_client() -> str | None:
    _prune_clients()
    if not _clients:
        return None

    def score(item: tuple[str, dict]) -> tuple[int, float]:
        _, c = item
        state = c["state"]
        points = 0
        # Tocar vale muito mais que estar visível: uma aba em segundo plano
        # tocando é a que o usuário quer controlar.
        if not state.get("paused", True):
            points += 10
        if state.get("hasTrack"):
            points += 2
        if state.get("visibility") == "visible":
            points += 1
        return points, c["last_seen"]

    return max(_clients.items(), key=score)[0]


def _clean_state(payload: dict) -> dict:
    def text(key: str, limit: int) -> str:
        value = payload.get(key, "")
        return value[:limit] if isinstance(value, str) else ""

    duration = payload.get("duration", 0)
    try:
        duration = max(0.0, float(duration))
    except (TypeError, ValueError):
        duration = 0.0

    position = payload.get("position", 0)
    try:
        position = max(0.0, float(position))
    except (TypeError, ValueError):
        position = 0.0
    if duration > 0:
        position = min(position, duration)

    volume = payload.get("volume", 1)
    try:
        volume = max(0.0, min(1.0, float(volume)))
    except (TypeError, ValueError):
        volume = 1.0

    visibility = payload.get("visibility", "hidden")
    if visibility not in ("visible", "hidden"):
        visibility = "hidden"

    return {
        "title": text("title", 500),
        "artist": text("artist", 500),
        "art": text("art", 2000),
        "position": position,
        "duration": duration,
        "paused": bool(payload.get("paused", True)),
        "volume": volume,
        "hasTrack": bool(payload.get("hasTrack", False)),
        "url": text("url", 2000),
        "visibility": visibility,
    }


def _queue_command(client_id: str, cmd: str, extra: dict | None = None) -> int | None:
    global _next_command_id
    if cmd not in ("play", "pause", "toggle", "next", "previous", "seek", "volume"):
        return None
    if client_id not in _clients:
        return None

    now = _now()
    queue = _commands.setdefault(client_id, [])
    queue[:] = [c for c in queue if now - c["ts"] < COMMAND_TTL]
    if len(queue) >= MAX_COMMANDS:
        queue.pop(0)

    command = {"id": _next_command_id, "cmd": cmd, "ts": now}
    _next_command_id += 1
    if extra:
        for key in ("position", "volume"):
            if key in extra:
                try:
                    command[key] = float(extra[key])
                except (TypeError, ValueError):
                    pass
    queue.append(command)
    return command["id"]


def _state_response() -> dict:
    _prune_clients()
    session = _session_info()
    browser_running = _zen_running()
    active = _active_client()

    # Sessão antiga com o navegador fechado não conta como aba aberta.
    session_has_tab = session["hasYtmTab"] and browser_running
    body = {
        "connected": active is not None,
        "hasYtmTab": session_has_tab or bool(_clients),
        "ytmTabCount": max(session["ytmTabCount"] if browser_running else 0, len(_clients)),
        "browserRunning": browser_running,
        "sessionFile": session["sessionFile"],
        "serverTime": time.time(),
    }
    if session.get("sessionError"):
        body["sessionError"] = session["sessionError"]

    if active is not None:
        state = _clients[active]["state"]
        body.update(state)
        body["clientId"] = active
    return body


# ─────────────────────────────────────────────────────────────────────────────
# HTTP
# ─────────────────────────────────────────────────────────────────────────────

class Handler(BaseHTTPRequestHandler):
    server_version = "LksYtmBridge/1.0"

    def log_message(self, fmt: str, *args) -> None:  # noqa: D401 - silencia acesso
        pass

    def _send(self, code: int, data: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def _json(self, code: int, payload: dict) -> None:
        self._send(
            code,
            json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            "application/json; charset=utf-8",
        )

    def _body(self) -> dict | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if length <= 0 or length > MAX_BODY:
            return None
        try:
            payload = json.loads(self.rfile.read(length))
        except (ValueError, UnicodeDecodeError):
            return None
        return payload if isinstance(payload, dict) else None

    def do_OPTIONS(self) -> None:  # noqa: N802
        self._send(204, b"", "text/plain")

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/state":
            with _lock:
                self._json(200, _state_response())
            return

        if path == "/commands":
            client_id = (query.get("client") or [""])[0]
            with _lock:
                _prune_clients()
                if not client_id:
                    client_id = _active_client() or ""
                now = _now()
                queue = _commands.get(client_id, [])
                pending = [c for c in queue if now - c["ts"] < COMMAND_TTL]
                _commands[client_id] = []
            self._json(200, {"commands": pending})
            return

        if path == "/health":
            with _lock:
                session = _session_info()
                browser_running = _zen_running()
                self._json(200, {
                    "ok": True,
                    "connected": _active_client() is not None,
                    "browserRunning": browser_running,
                    "hasYtmTab": (session["hasYtmTab"] and browser_running) or bool(_clients),
                })
            return

        if path == "/ytm_bridge.user.js":
            try:
                data = SCRIPT_PATH.read_bytes()
            except OSError as exc:
                self._json(500, {"ok": False, "error": str(exc)})
                return
            self._send(200, data, "application/javascript; charset=utf-8")
            return

        if path == "/":
            self._json(200, {
                "ok": True,
                "name": "lks-shell YTM bridge",
                "endpoints": ["/state", "/command", "/commands", "/health", "/ytm_bridge.user.js"],
            })
            return

        self._json(404, {"ok": False, "error": "rota desconhecida"})

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path

        if path == "/state":
            payload = self._body()
            if payload is None:
                self._json(400, {"ok": False, "error": "JSON inválido"})
                return
            client_id = payload.get("client")
            if not isinstance(client_id, str) or not client_id:
                client_id = "default"
            client_id = client_id[:100]
            state = _clean_state(payload)
            with _lock:
                _clients[client_id] = {
                    "state": state,
                    "last_seen": _now(),
                }
            self._json(200, {"ok": True, "clientId": client_id})
            return

        if path == "/command":
            payload = self._body()
            if payload is None:
                self._json(400, {"ok": False, "error": "JSON inválido"})
                return
            cmd = payload.get("cmd", "")
            with _lock:
                client_id = payload.get("client")
                if not isinstance(client_id, str) or not client_id:
                    client_id = _active_client() or ""
                command_id = _queue_command(client_id, cmd, payload)
            if command_id is None:
                self._json(409, {"ok": False, "error": "sem cliente YTM conectado"})
                return
            self._json(200, {"ok": True, "id": command_id})
            return

        self._json(404, {"ok": False, "error": "rota desconhecida"})


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> int:
    parser = argparse.ArgumentParser(description="Ponte local do YouTube Music")
    parser.add_argument("--host", default=HOST)
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()

    try:
        server = Server((args.host, args.port), Handler)
    except OSError as exc:
        # Se já existe uma instância saudável (outro shell), não é erro.
        try:
            import urllib.request
            with urllib.request.urlopen(f"http://{args.host}:{args.port}/health", timeout=1) as resp:
                health = json.loads(resp.read())
                if resp.status == 200 and isinstance(health, dict) and health.get("ok") is True:
                    print("Ponte do YouTube Music já está rodando.")
                    return 0
        except Exception:
            pass
        print(f"Não foi possível abrir {args.host}:{args.port}: {exc}", file=sys.stderr)
        return 1

    print(f"Ponte do YouTube Music em http://{args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
