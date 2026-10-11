from __future__ import annotations

import base64
import json
import threading
import urllib.error
import urllib.request
from typing import Any

from .config import Config


def _base(cfg: Config) -> str:
    return (getattr(cfg, "worker_base_url", "") or "").strip().rstrip("/")


def _request(cfg: Config, method: str, path: str, payload: Any | None = None) -> None:
    base = _base(cfg)
    if not base:
        return
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        base + path,
        data=data,
        method=method,
        headers={
            "Content-Type": "application/json",
            "x-api-secret": cfg.api_secret,
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            resp.read()
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError):
        return


def _spawn(fn) -> None:
    thread = threading.Thread(target=fn, daemon=True, name="cryax-worker-sync")
    thread.start()


def push_tag(cfg: Config, tag: dict[str, Any]) -> None:
    roblox_id = int(tag.get("roblox_id") or 0)
    if roblox_id <= 0:
        return
    payload = dict(tag)
    _spawn(lambda: _request(cfg, "PUT", f"/internal/tags/{roblox_id}", payload))


def delete_tag(cfg: Config, roblox_id: int) -> None:
    _spawn(lambda: _request(cfg, "DELETE", f"/internal/tags/{int(roblox_id)}"))


def push_images(cfg: Config, roblox_id: int, kind: str, frames: list[bytes], delay: float) -> None:
    encoded = [base64.b64encode(frame).decode("ascii") for frame in frames if frame]
    _spawn(
        lambda: _request(
            cfg,
            "PUT",
            f"/internal/images/{int(roblox_id)}/{kind}",
            {"frames": encoded, "delay": float(delay or 0.08)},
        )
    )


def push_snapshot(store: Any) -> None:
    cfg = store.cfg
    if not _base(cfg):
        return

    def run() -> None:
        users = store.all_tags()
        images: dict[str, Any] = {}
        for key in users:
            try:
                roblox_id = int(key)
            except ValueError:
                continue
            for kind in ("icon", "bg"):
                frames = store.read_frames(roblox_id, kind)
                if not frames:
                    static = store.read_static(roblox_id, kind)
                    frames = [static] if static else []
                if not frames:
                    continue
                tag = users.get(str(roblox_id)) or {}
                delay = tag.get("icon_frame_delay" if kind == "icon" else "bg_frame_delay") or 0.08
                images[f"{roblox_id}:{kind}"] = {
                    "frames": [base64.b64encode(frame).decode("ascii") for frame in frames],
                    "delay": float(delay),
                }
        _request(cfg, "PUT", "/internal/snapshot", {"users": users, "images": images})

    _spawn(run)
