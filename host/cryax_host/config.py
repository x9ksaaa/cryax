from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

HOST_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = HOST_DIR.parent
GITHUB_RAW_SCRIPT = "https://raw.githubusercontent.com/x9ksa/cryax/main/cryax.lua"


def resolve_client_script() -> Path:
    for name in ("cryax.lua", "cryax src.lua", "cryax src.txt"):
        path = REPO_ROOT / name
        if path.exists():
            return path
    return REPO_ROOT / "cryax src.lua"


CLIENT_SCRIPT = resolve_client_script()
OFFICIAL_WORKER_BASE = "https://cryax-api.cryaxontop.workers.dev"

load_dotenv(REPO_ROOT / ".env")
load_dotenv(HOST_DIR / ".env")

FONTS = (
    "GothamBlack",
    "GothamBold",
    "Gotham",
    "Bangers",
    "SourceSansBold",
)

SHAPES = (
    "Pill",
    "Rounded",
    "Square",
)


def _csv_ids(raw: str | None) -> set[str]:
    values: set[str] = set()
    for part in (raw or "").split(","):
        part = part.strip()
        if part:
            values.add(part)
    return values


def _csv_ints(raw: str | None) -> set[int]:
    values: set[int] = set()
    for part in _csv_ids(raw):
        try:
            values.add(int(part))
        except ValueError:
            continue
    return values


@dataclass
class Config:
    api_secret: str = "bloodontop"
    host: str = "0.0.0.0"
    port: int = 8787
    public_base_url: str = "http://127.0.0.1:8787"
    access_mode: str = "open"
    staff_roblox_ids: set[int] = field(default_factory=set)
    staff_discord_ids: set[str] = field(default_factory=set)
    discord_owner_id: str = ""
    presence_ttl_seconds: int = 15
    data_dir: Path = field(default_factory=lambda: REPO_ROOT / "data")
    discord_token: str = ""
    discord_client_id: str = ""
    discord_guild_id: str = ""
    command_prefix: str = "."
    control_password: str = ""
    tunnel_command: str = ""
    cloudflare_tunnel_token: str = ""
    worker_base_url: str = ""
    auto_start_discord: bool = True
    auto_start_tunnel: bool = False

    @property
    def public_base(self) -> str:
        return self.public_base_url.rstrip("/")


def load_config() -> Config:
    data_dir = Path(os.environ.get("DATA_DIR") or (REPO_ROOT / "data"))
    if not data_dir.is_absolute():
        data_dir = (REPO_ROOT / data_dir).resolve()
    cfg = Config(
        api_secret=os.environ.get("API_SECRET") or "bloodontop",
        host=os.environ.get("HOST") or "0.0.0.0",
        port=int(os.environ.get("PORT") or "8787"),
        public_base_url=os.environ.get("PUBLIC_BASE_URL") or "http://127.0.0.1:8787",
        access_mode=(os.environ.get("ACCESS_MODE") or "open").strip().lower(),
        staff_roblox_ids=_csv_ints(os.environ.get("STAFF_ROBLOX_IDS")),
        staff_discord_ids=_csv_ids(os.environ.get("STAFF_DISCORD_IDS")),
        discord_owner_id=(os.environ.get("DISCORD_OWNER_ID") or "").strip(),
        presence_ttl_seconds=int(os.environ.get("PRESENCE_TTL_SECONDS") or "15"),
        data_dir=data_dir,
        discord_token=(os.environ.get("DISCORD_TOKEN") or "").strip(),
        discord_client_id=(os.environ.get("DISCORD_CLIENT_ID") or "").strip(),
        discord_guild_id=(os.environ.get("DISCORD_GUILD_ID") or "").strip(),
        command_prefix=os.environ.get("COMMAND_PREFIX") or ".",
        control_password=(os.environ.get("CONTROL_PASSWORD") or "").strip(),
        tunnel_command=(os.environ.get("TUNNEL_COMMAND") or "").strip(),
        cloudflare_tunnel_token=(os.environ.get("CLOUDFLARE_TUNNEL_TOKEN") or "").strip(),
        worker_base_url=(os.environ.get("WORKER_BASE_URL") or "").strip().rstrip("/")
        or OFFICIAL_WORKER_BASE,
        auto_start_discord=(os.environ.get("AUTO_START_DISCORD") or "1").strip() not in {"0", "false", "no"},
        auto_start_tunnel=(os.environ.get("AUTO_START_TUNNEL") or "0").strip() in {"1", "true", "yes"},
    )
    if cfg.discord_owner_id:
        cfg.staff_discord_ids.add(cfg.discord_owner_id)
    if cfg.access_mode not in {"open", "whitelist", "key"}:
        cfg.access_mode = "open"
    return cfg


def script_public_base(cfg: Config, tunnel_url: str | None = None) -> str:
    return (
        (cfg.worker_base_url or "").strip()
        or (tunnel_url or "").strip()
        or cfg.public_base
    ).rstrip("/")


def paste_script_base(cfg: Config | None = None) -> str:
    if cfg is not None:
        worker = (cfg.worker_base_url or "").strip().rstrip("/")
        if worker:
            return worker
    return OFFICIAL_WORKER_BASE


def paste_loadstring(cfg: Config | None = None) -> str:
    return loadstring_for(paste_script_base(cfg))


def loadstring_for(base_url: str | None = None) -> str:
    raw = str(base_url or "http://127.0.0.1:8787").rstrip("/")
    lower = raw.lower()
    if lower.endswith("/loader") or lower.endswith("/script.lua") or lower.endswith("/cryax.lua"):
        url = raw
    elif "workers.dev" in lower:
        url = raw + "/loader"
    else:
        url = raw + "/script.lua"
    return f'loadstring(game:HttpGet("{url}"))()'
