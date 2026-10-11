from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from cryax_host.config import Config
from cryax_host.store import Store
from cryax_host.supervisor import Supervisor, resolve_tunnel_command


def test_named_tunnel_uses_token_and_public_url(monkeypatch) -> None:
    cfg = Config(
        public_base_url="https://cryax.example.com",
        cloudflare_tunnel_token="tok_abc",
        port=8787,
    )

    def fake_which(name: str) -> str | None:
        if name in {"cloudflared", "cloudflared.exe"}:
            return "/usr/bin/cloudflared"
        return None

    monkeypatch.setattr("cryax_host.supervisor.shutil.which", fake_which)
    cmd, url = resolve_tunnel_command(cfg)
    assert "tunnel run --token tok_abc" in cmd
    assert url == "https://cryax.example.com"


def test_tunnel_command_override_wins(monkeypatch) -> None:
    cfg = Config(
        tunnel_command="ngrok http 8787",
        cloudflare_tunnel_token="ignored",
        public_base_url="https://cryax.example.com",
    )
    monkeypatch.setattr("cryax_host.supervisor.shutil.which", lambda _name: "/usr/bin/cloudflared")
    cmd, url = resolve_tunnel_command(cfg)
    assert cmd == "ngrok http 8787"
    assert url == ""


def test_autostart_hidden_launchers(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("APPDATA", str(tmp_path / "appdata"))
    monkeypatch.setenv("HOME", str(tmp_path))
    # Path.home() ignores HOME on Windows, so pin it to the sandbox for the
    # Linux autostart .desktop path assertion.
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: tmp_path))
    cfg = Config(data_dir=tmp_path / "data")
    store = Store(cfg)
    store.load()
    boss = Supervisor(cfg, store)
    logs = "\n".join(boss.lines("api"))
    assert "CONTROL ready" in logs
    assert boss.set_autostart(True) is True
    bat = (
        tmp_path
        / "appdata"
        / "Microsoft"
        / "Windows"
        / "Start Menu"
        / "Programs"
        / "Startup"
        / "CryaxHost.bat"
    )
    text = bat.read_text(encoding="utf-8")
    assert 'start ""' in text
    assert "main.py" in text
    desktop = tmp_path / ".config" / "autostart" / "cryax-host.desktop"
    desk = desktop.read_text(encoding="utf-8")
    assert "Terminal=false" in desk
    assert boss.autostart_enabled() is True
    assert boss.set_autostart(False) is True
    assert not bat.exists()


def test_install_tunnel_script_requires_admin() -> None:
    text = (ROOT / "install-tunnel.ps1").read_text(encoding="utf-8")
    assert "Test-IsAdmin" in text
    assert "service install" in text
    assert "Run as administrator" in text


def test_powershell_scripts_are_ascii() -> None:
    for name in ("start.ps1", "install-tunnel.ps1", "worker/deploy.ps1"):
        raw = (ROOT / name).read_bytes()
        raw.decode("ascii")
        assert b"\xe2\x80\x94" not in raw


def test_deploy_script_rejects_env_cast_leftovers() -> None:
    text = (ROOT / "worker/deploy.ps1").read_text(encoding="utf-8")
    assert r"(?m)^[ \t]+\(env" not in text
    assert "Contains('(env).CryaxClient')" in text
    assert "Contains('(env ).CryaxClient')" in text
    assert "Contains('string.sub(src, 1, 200)')" in text
    assert "Contains('<html')" in text


def test_start_script_kills_leftover_discord_bots() -> None:
    text = (ROOT / "start.ps1").read_text(encoding="utf-8")
    assert "Stop-DiscordWorkers" in text
    assert "cryax_host\\.discord_worker" in text


def test_start_discord_kills_leftover_workers(tmp_path, monkeypatch) -> None:
    killed: list[list[int]] = []

    def fake_kill(exclude=None):
        killed.append(list(exclude or []))
        return [111]

    monkeypatch.setattr("cryax_host.supervisor.kill_discord_workers", fake_kill)
    monkeypatch.setattr("cryax_host.supervisor.time.sleep", lambda _seconds: None)
    cfg = Config(discord_token="tok", data_dir=tmp_path / "data")
    store = Store(cfg)
    store.load()
    boss = Supervisor(cfg, store)

    class FakeProc:
        pid = 99

        def poll(self):
            return None

    monkeypatch.setattr(boss, "_spawn", lambda *_args, **_kwargs: FakeProc())
    assert boss.start_discord() == "started"
    assert killed
    assert boss.discord.pid == 99
    logs = "\n".join(boss.lines("discord"))
    assert "111" in logs


def test_stop_discord_kills_orphan_workers(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr("cryax_host.supervisor.list_discord_worker_pids", lambda exclude=None: [222])
    called: list[int] = []
    monkeypatch.setattr("cryax_host.supervisor.kill_pids", lambda pids, **_kwargs: called.extend(list(pids)))
    cfg = Config(discord_token="tok", data_dir=tmp_path / "data")
    store = Store(cfg)
    store.load()
    boss = Supervisor(cfg, store)
    assert boss.stop_discord() == "stopped"
    assert 222 in called
    assert "stopped" in "\n".join(boss.lines("discord"))
