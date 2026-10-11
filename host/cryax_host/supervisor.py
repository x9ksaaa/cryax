from __future__ import annotations

import hashlib
import hmac
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from collections import deque
from pathlib import Path
from typing import Any

from .config import Config, HOST_DIR, paste_loadstring
from .procutil import kill_discord_workers, kill_pids, list_discord_worker_pids
from .store import Store

MAX_LOG_LINES = 400
TUNNEL_URL_RE = re.compile(r"https://[a-zA-Z0-9.-]+\.(?:trycloudflare\.com|ngrok-free\.app|ngrok\.io)")


def _now() -> float:
    return time.time()


def format_uptime(started_at: float | None) -> str:
    if not started_at:
        return "—"
    seconds = max(0, int(_now() - started_at))
    hours, rem = divmod(seconds, 3600)
    minutes, secs = divmod(rem, 60)
    if hours:
        return f"up {hours}h {minutes}m {secs}s"
    if minutes:
        return f"up {minutes}m {secs}s"
    return f"up {secs}s"


def _startup_paths() -> list[Path]:
    paths: list[Path] = []
    appdata = os.environ.get("APPDATA")
    if appdata:
        paths.append(Path(appdata) / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Startup" / "CryaxHost.bat")
    linux = Path.home() / ".config" / "autostart" / "cryax-host.desktop"
    paths.append(linux)
    return paths


def _host_python(hidden: bool = False) -> str:
    win_w = HOST_DIR / ".venv" / "Scripts" / "pythonw.exe"
    win = HOST_DIR / ".venv" / "Scripts" / "python.exe"
    nix = HOST_DIR / ".venv" / "bin" / "python"
    if hidden and os.name == "nt" and win_w.exists():
        return str(win_w)
    if win.exists():
        return str(win)
    if nix.exists():
        return str(nix)
    return sys.executable


def resolve_tunnel_command(cfg: Config) -> tuple[str, str]:
    """Return (shell command, stable public URL or empty)."""
    if cfg.tunnel_command.strip():
        return cfg.tunnel_command.strip(), ""
    binary = shutil.which("cloudflared") or shutil.which("cloudflared.exe")
    token = (cfg.cloudflare_tunnel_token or "").strip()
    if binary and token:
        return f'"{binary}" tunnel run --token {token}', cfg.public_base
    if binary:
        return f'"{binary}" tunnel --url http://127.0.0.1:{cfg.port}', ""
    ngrok = shutil.which("ngrok") or shutil.which("ngrok.exe")
    if ngrok:
        return f'"{ngrok}" http {cfg.port}', ""
    return "", ""


class Supervisor:
    def __init__(self, cfg: Config, store: Store):
        self.cfg = cfg
        self.store = store
        self.api_enabled = True
        self.api_started_at = _now()
        self.api_restarts = 0
        self.discord: subprocess.Popen[bytes] | None = None
        self.tunnel: subprocess.Popen[bytes] | None = None
        self.discord_started_at: float | None = None
        self.tunnel_started_at: float | None = None
        self.discord_restarts = 0
        self.tunnel_restarts = 0
        self.tunnel_url = ""
        self.logs: dict[str, deque[str]] = {
            "api": deque(maxlen=MAX_LOG_LINES),
            "discord": deque(maxlen=MAX_LOG_LINES),
            "tunnel": deque(maxlen=MAX_LOG_LINES),
        }
        self._lock = threading.Lock()
        self._readers: list[threading.Thread] = []
        self.log("api", f"CONTROL ready on http://127.0.0.1:{cfg.port}")
        self.log("api", f"Nametag API secret routes use x-api-secret / ?secret=")

    def log(self, service: str, line: str) -> None:
        text = line.rstrip("\n")
        if not text:
            return
        with self._lock:
            bucket = self.logs.setdefault(service, deque(maxlen=MAX_LOG_LINES))
            bucket.append(text)

    def lines(self, service: str) -> list[str]:
        with self._lock:
            return list(self.logs.get(service, []))

    def session_token(self) -> str:
        raw = (self.cfg.control_password or self.cfg.api_secret).encode("utf-8")
        return hmac.new(raw, b"cryax-control", hashlib.sha256).hexdigest()

    def check_login(self, password: str) -> bool:
        if not self.cfg.control_password:
            return True
        return hmac.compare_digest(password, self.cfg.control_password)

    def autostart_enabled(self) -> bool:
        return any(path.exists() for path in _startup_paths() if "Startup" in str(path) or path.suffix == ".desktop")

    def set_autostart(self, enabled: bool) -> bool:
        host_main = HOST_DIR / "main.py"
        hidden_python = _host_python(hidden=True)
        console_python = _host_python(hidden=False)
        created = False
        for path in _startup_paths():
            if enabled:
                path.parent.mkdir(parents=True, exist_ok=True)
                if path.suffix == ".bat":
                    path.write_text(
                        f'@echo off\r\ncd /d "{HOST_DIR}"\r\nstart "" "{hidden_python}" "{host_main}"\r\n',
                        encoding="utf-8",
                    )
                    created = True
                elif path.suffix == ".desktop":
                    path.write_text(
                        "\n".join(
                            [
                                "[Desktop Entry]",
                                "Type=Application",
                                "Name=Cryax Host",
                                f'Exec="{console_python}" "{host_main}"',
                                f"Path={HOST_DIR}",
                                "Terminal=false",
                                "X-GNOME-Autostart-enabled=true",
                                "",
                            ]
                        ),
                        encoding="utf-8",
                    )
                    created = True
            elif path.exists():
                path.unlink()
                created = True
        return created

    def _alive(self, proc: subprocess.Popen[bytes] | None) -> bool:
        return proc is not None and proc.poll() is None

    def _pipe_logs(self, service: str, proc: subprocess.Popen[bytes]) -> None:
        def reader() -> None:
            assert proc.stdout is not None
            for raw in iter(proc.stdout.readline, b""):
                line = raw.decode("utf-8", errors="replace").rstrip()
                self.log(service, line)
                if service == "tunnel" and not self.cfg.cloudflare_tunnel_token:
                    match = TUNNEL_URL_RE.search(line)
                    if match:
                        self.tunnel_url = match.group(0).rstrip("/")
                        self.log("tunnel", f"Public URL {self.tunnel_url}")
            code = proc.poll()
            if code not in (None, 0):
                self.log(service, f"process exited {code}")

        thread = threading.Thread(target=reader, name=f"log-{service}", daemon=True)
        thread.start()
        self._readers.append(thread)

    def _spawn(self, service: str, argv: list[str], extra_env: dict[str, str] | None = None) -> subprocess.Popen[bytes]:
        env = os.environ.copy()
        if extra_env:
            env.update(extra_env)
        env["PYTHONPATH"] = str(HOST_DIR) + os.pathsep + env.get("PYTHONPATH", "")
        self.log(service, "$ " + " ".join(argv))
        kwargs: dict[str, Any] = {
            "cwd": str(HOST_DIR),
            "stdout": subprocess.PIPE,
            "stderr": subprocess.STDOUT,
            "env": env,
        }
        if os.name == "nt":
            kwargs["creationflags"] = int(getattr(subprocess, "CREATE_NO_WINDOW", 0))
        proc = subprocess.Popen(argv, **kwargs)
        self._pipe_logs(service, proc)
        return proc

    def start_discord(self) -> str:
        own = {os.getpid(), os.getppid()}
        if self._alive(self.discord) and self.discord is not None:
            extras = kill_discord_workers(exclude=own | {int(self.discord.pid or 0)})
            if extras:
                self.log("discord", f"Stopped extra bot pid(s) {', '.join(str(pid) for pid in extras)}")
            return "already running"
        if not self.cfg.discord_token:
            self.log("discord", "DISCORD_TOKEN is empty — set it in .env")
            return "missing token"
        leftovers = kill_discord_workers(exclude=own)
        if leftovers:
            self.log("discord", f"Stopped leftover bot pid(s) {', '.join(str(pid) for pid in leftovers)}")
            time.sleep(0.4)
        self.discord = self._spawn(
            "discord",
            [sys.executable, "-m", "cryax_host.discord_worker"],
        )
        self.discord_started_at = _now()
        self.discord_restarts += 1
        return "started"

    def stop_discord(self) -> str:
        own = {os.getpid(), os.getppid()}
        targets = list_discord_worker_pids(exclude=own)
        if self.discord is not None and self.discord.pid:
            targets = list(dict.fromkeys([int(self.discord.pid), *targets]))
        if not targets:
            self.discord = None
            self.discord_started_at = None
            return "already stopped"
        kill_pids(targets)
        self.discord = None
        self.discord_started_at = None
        self.log("discord", "stopped")
        return "stopped"

    def start_tunnel(self) -> str:
        if self._alive(self.tunnel):
            return "already running"
        cmd, stable = resolve_tunnel_command(self.cfg)
        if not cmd:
            self.log("tunnel", "Install cloudflared or ngrok, or set TUNNEL_COMMAND / CLOUDFLARE_TUNNEL_TOKEN in .env")
            return "missing binary"
        logged = cmd
        token = self.cfg.cloudflare_tunnel_token.strip()
        if token:
            logged = cmd.replace(token, "***")
            if stable and not stable.startswith("http://127.0.0.1"):
                self.tunnel_url = stable.rstrip("/")
                self.log("tunnel", f"Named tunnel — loadstring uses {self.tunnel_url}")
            else:
                self.log(
                    "tunnel",
                    "Named tunnel started. Set PUBLIC_BASE_URL to your stable https:// hostname so the loadstring stays the same.",
                )
        kwargs: dict[str, Any] = {
            "cwd": str(HOST_DIR),
            "stdout": subprocess.PIPE,
            "stderr": subprocess.STDOUT,
            "shell": True,
        }
        if os.name == "nt":
            kwargs["creationflags"] = int(getattr(subprocess, "CREATE_NO_WINDOW", 0))
        self.tunnel = subprocess.Popen(cmd, **kwargs)
        self.log("tunnel", "$ " + logged)
        self._pipe_logs("tunnel", self.tunnel)
        self.tunnel_started_at = _now()
        self.tunnel_restarts += 1
        return "started"

    def stop_tunnel(self) -> str:
        if not self._alive(self.tunnel):
            self.tunnel = None
            self.tunnel_started_at = None
            return "already stopped"
        assert self.tunnel is not None
        self.tunnel.terminate()
        try:
            self.tunnel.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.tunnel.kill()
        self.tunnel = None
        self.tunnel_started_at = None
        self.tunnel_url = ""
        self.log("tunnel", "stopped")
        return "stopped"

    def start_api(self) -> str:
        self.api_enabled = True
        if not self.api_started_at:
            self.api_started_at = _now()
        self.log("api", "Nametag API online")
        return "started"

    def stop_api(self) -> str:
        self.api_enabled = False
        self.log("api", "Nametag API paused (CONTROL stays up)")
        return "stopped"

    def restart_api(self) -> str:
        self.stop_api()
        self.api_restarts += 1
        self.api_started_at = _now()
        return self.start_api()

    def restart_discord(self) -> str:
        self.stop_discord()
        return self.start_discord()

    def restart_tunnel(self) -> str:
        self.stop_tunnel()
        return self.start_tunnel()

    def action(self, service: str, op: str) -> str:
        table = {
            ("api", "start"): self.start_api,
            ("api", "stop"): self.stop_api,
            ("api", "restart"): self.restart_api,
            ("discord", "start"): self.start_discord,
            ("discord", "stop"): self.stop_discord,
            ("discord", "restart"): self.restart_discord,
            ("tunnel", "start"): self.start_tunnel,
            ("tunnel", "stop"): self.stop_tunnel,
            ("tunnel", "restart"): self.restart_tunnel,
        }
        fn = table.get((service, op))
        if not fn:
            return "unknown"
        return fn()

    def start_all(self) -> None:
        self.start_api()
        if self.cfg.discord_token:
            self.start_discord()
        self.start_tunnel()

    def stop_all(self) -> None:
        self.stop_discord()
        self.stop_tunnel()
        self.stop_api()

    def restart_all(self) -> None:
        self.restart_api()
        if self.cfg.discord_token:
            self.restart_discord()
        self.restart_tunnel()

    def start_defaults(self) -> None:
        self.start_api()
        if self.cfg.discord_token and self.cfg.auto_start_discord:
            self.start_discord()
        if self.cfg.auto_start_tunnel:
            self.start_tunnel()

    def shutdown(self) -> None:
        self.stop_discord()
        self.stop_tunnel()

    def snapshot(self) -> dict[str, Any]:
        discord_on = self._alive(self.discord)
        tunnel_on = self._alive(self.tunnel)
        public = self.tunnel_url or self.cfg.public_base
        return {
            "autostart": self.autostart_enabled(),
            "need_login": bool(self.cfg.control_password),
            "public_base_url": public,
            "tunnel_url": self.tunnel_url,
            "loadstring": paste_loadstring(self.cfg),
            "services": {
                "api": {
                    "id": "api",
                    "title": "Cryax API",
                    "blurb": "Nametag API, script host, getkey, and SKY — this is what Roblox talks to.",
                    "online": self.api_enabled,
                    "pid": os.getpid() if self.api_enabled else None,
                    "uptime": format_uptime(self.api_started_at if self.api_enabled else None),
                    "restarts": self.api_restarts,
                },
                "discord": {
                    "id": "discord",
                    "title": "Discord bot",
                    "blurb": "Cryax Discord bot (nametags, keys, welcomer, .nametagpanel).",
                    "online": discord_on,
                    "pid": self.discord.pid if discord_on and self.discord else None,
                    "uptime": format_uptime(self.discord_started_at if discord_on else None),
                    "restarts": max(0, self.discord_restarts - (1 if discord_on else 0)),
                    "hint": None if self.cfg.discord_token else "Set DISCORD_TOKEN in .env",
                },
                "tunnel": {
                    "id": "tunnel",
                    "title": "Cloudflare tunnel",
                    "blurb": "Named Cloudflare tunnel keeps one loadstring. Start with Windows runs this hidden.",
                    "online": tunnel_on,
                    "pid": self.tunnel.pid if tunnel_on and self.tunnel else None,
                    "uptime": format_uptime(self.tunnel_started_at if tunnel_on else None),
                    "restarts": max(0, self.tunnel_restarts - (1 if tunnel_on else 0)),
                    "hint": self.tunnel_url or None,
                },
            },
        }
