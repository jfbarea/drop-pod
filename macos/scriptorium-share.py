#!/usr/bin/env python3
"""Bridge HTTP local para el boton «Compartir» del scriptorium.

Escucha SOLO en 127.0.0.1:8737 y expone:
  POST /share  {"path": "/<rel>.html"} -> publica (o actualiza) el fichero
               como Artifact de claude.ai lanzando una sesion interactiva de
               `claude` en tmux -- la herramienta Artifact solo existe en
               modo interactivo, no en `claude -p` ni en el Agent SDK.
  GET  /shares -> mapping persistido rel-path -> {url, sharedAt}

Lo arranca scriptorium-share-serve.sh vía el LaunchAgent
com.fran.scriptorium-share. El proxy same-origin (/-/*) que lo expone al
visor lo añade el Caddyfile (macos/scriptorium.Caddyfile); este bridge no
debe exponerse fuera de localhost.
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = "127.0.0.1"
# 8081 ya lo ocupa otro proceso en este Mac (node/sunproxyadmin, en wildcard);
# coexistian por bindar interfaces distintas pero era fragil. 8737 esta libre.
PORT = 8737

# Empieza en haiku por coste; verificado a mano que expone la herramienta
# Artifact en modo interactivo con --allowedTools. Si algun dia deja de
# exponerla, vaciar esta variable para caer al modelo por defecto.
MODEL = "claude-haiku-4-5-20251001"

CLAUDE_BIN = str(Path.home() / ".local" / "bin" / "claude")
BASE_DIR = (Path.home() / "src" / "html").resolve()
MAPPING_FILE = BASE_DIR / ".scriptorium-shares.json"
SESSION_NAME = "scriptorium-share"
RESULT_DIR = Path(tempfile.gettempdir()) / "scriptorium-share"
TIMEOUT_SECONDS = 180
POLL_INTERVAL_SECONDS = 1.0

# cwd de la sesion claude: tiene que ser un directorio ya confiado para no
# quedarse bloqueada en el dialogo de confianza de carpeta la primera vez
# (comprobado: ~/src/html no esta confiado y bloquea el arranque en tmux;
# el propio repo de dotfiles si lo esta). Los paths que se le pasan en el
# prompt son siempre absolutos, asi que el cwd no afecta a que fichero
# publica.
CLAUDE_CWD = str(Path.home() / "drop-pod")

publish_lock = threading.Lock()


def load_mapping() -> dict:
    if not MAPPING_FILE.exists():
        return {}
    try:
        return json.loads(MAPPING_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def save_mapping(mapping: dict) -> None:
    MAPPING_FILE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(
        dir=str(MAPPING_FILE.parent), prefix=".scriptorium-shares-", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(mapping, f, indent=2, sort_keys=True)
            f.write("\n")
        os.replace(tmp_path, MAPPING_FILE)
    except Exception:
        Path(tmp_path).unlink(missing_ok=True)
        raise


def resolve_shared_path(raw_path: str) -> Path | None:
    if not raw_path or not isinstance(raw_path, str):
        return None
    rel = raw_path.lstrip("/")
    if not rel:
        return None
    candidate = (BASE_DIR / rel).resolve()
    if candidate.suffix != ".html":
        return None
    try:
        candidate.relative_to(BASE_DIR)
    except ValueError:
        return None
    if not candidate.is_file():
        return None
    return candidate


def tmux_session_exists(name: str) -> bool:
    result = subprocess.run(["tmux", "has-session", "-t", name], capture_output=True)
    return result.returncode == 0


def tmux_kill_session(name: str) -> None:
    subprocess.run(["tmux", "kill-session", "-t", name], capture_output=True)


def build_prompt(abs_path: Path, resultfile: Path, existing_url: str | None) -> str:
    update_clause = ""
    if existing_url:
        update_clause = (
            f' Ya existe un artifact publicado para este documento en '
            f'"{existing_url}"; pasalo como el parametro url de la '
            f'herramienta Artifact para actualizarlo en sitio en vez de '
            f'crear uno nuevo.'
        )
    return (
        f"Lee el fichero {abs_path} y publicalo como Claude Artifact usando "
        f"la herramienta Artifact.{update_clause} Usa un favicon estable "
        f'(el emoji de documento "\U0001F4C4") y una description breve '
        f"derivada del titulo del documento. No pidas confirmacion ni des "
        f"explicaciones. En cuanto la herramienta Artifact devuelva la URL, "
        f"usa la herramienta Write para escribir EXACTAMENTE este JSON y "
        f"nada mas (sin fences de markdown, sin texto extra) en el fichero "
        f'{resultfile} : {{"url": "<URL devuelta por Artifact>"}}. Despues '
        f"no hagas nada mas."
    )


def publish(abs_path: Path, existing_url: str | None) -> tuple[int, dict]:
    if tmux_session_exists(SESSION_NAME):
        return 409, {"error": "ya hay una publicacion en curso"}

    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    resultfile = RESULT_DIR / f"{uuid.uuid4().hex}.json"
    prompt = build_prompt(abs_path, resultfile, existing_url)

    cmd = [CLAUDE_BIN, "--allowedTools", "Artifact,Read,Write"]
    if MODEL:
        cmd += ["--model", MODEL]
    cmd.append(prompt)

    tmux_cmd = ["tmux", "new-session", "-d", "-s", SESSION_NAME, "-c", CLAUDE_CWD] + cmd

    try:
        subprocess.run(tmux_cmd, check=True, capture_output=True)

        deadline = time.monotonic() + TIMEOUT_SECONDS
        while time.monotonic() < deadline:
            if resultfile.exists():
                try:
                    data = json.loads(resultfile.read_text())
                except (json.JSONDecodeError, OSError):
                    data = None
                if data and data.get("url"):
                    return 200, {"url": data["url"]}
            if not tmux_session_exists(SESSION_NAME):
                return 502, {"error": "la sesion claude termino sin publicar resultado"}
            time.sleep(POLL_INTERVAL_SECONDS)
        return 504, {"error": "timeout esperando la publicacion"}
    finally:
        tmux_kill_session(SESSION_NAME)
        resultfile.unlink(missing_ok=True)


class Handler(BaseHTTPRequestHandler):
    server_version = "scriptorium-share/1"

    def log_message(self, fmt, *args):
        pass

    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/shares":
            self._send_json(200, load_mapping())
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/share":
            self._send_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", 0) or 0)
        raw_body = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw_body or b"{}")
        except json.JSONDecodeError:
            self._send_json(400, {"error": "JSON invalido"})
            return

        abs_path = resolve_shared_path(body.get("path", "")) if isinstance(body, dict) else None
        if abs_path is None:
            self._send_json(
                400,
                {"error": "path invalido: debe ser un .html existente bajo ~/src/html"},
            )
            return

        if not publish_lock.acquire(blocking=False):
            self._send_json(409, {"error": "ya hay una publicacion en curso"})
            return

        try:
            rel_key = str(abs_path.relative_to(BASE_DIR))
            mapping = load_mapping()
            existing_url = (mapping.get(rel_key) or {}).get("url")

            status, payload = publish(abs_path, existing_url)

            if status == 200:
                mapping[rel_key] = {
                    "url": payload["url"],
                    "sharedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }
                save_mapping(mapping)

            self._send_json(status, payload)
        finally:
            publish_lock.release()


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"scriptorium-share bridge escuchando en http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
