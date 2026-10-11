from __future__ import annotations

import json
import secrets
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import shutil

from .config import FONTS, SHAPES, Config
from . import worker_sync

STATE_VERSION = 1

# Roblox renders the verified badge as Private Use Area U+E000
# via utf8.char(0xE000) in Gotham text.
ROBLOX_VERIFIED_BADGE_GLYPH = "\uE000"
ROBLOX_VERIFIED_BADGE_UNICODE = "U+E000"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def json_default(value: Any) -> str:
    iso = getattr(value, "isoformat", None)
    if callable(iso):
        try:
            return str(iso())
        except Exception:
            pass
    return str(value)


def as_plain(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, bool)):
        return value
    if isinstance(value, float):
        if value != value or value in {float("inf"), float("-inf")}:
            return None
        return value
    if isinstance(value, dict):
        return {str(key): as_plain(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [as_plain(item) for item in value]
    iso = getattr(value, "isoformat", None)
    if callable(iso):
        try:
            return str(iso())
        except Exception:
            return str(value)
    return str(value)


def empty_state() -> dict[str, Any]:
    return {
        "version": STATE_VERSION,
        "revision": 0,
        "nametags": {},
        "links": {},
        "presence": {},
        "keys": {},
        "whitelist": {},
        "blacklist": {},
        "bot_whitelist": {},
        "bot_owners": {},
    }


def normalize_hex(value: str | None, fallback: str) -> str:
    clean = str(value or "").strip().lstrip("#")
    if len(clean) == 6:
        try:
            int(clean, 16)
            return "#" + clean.upper()
        except ValueError:
            return fallback
    return fallback


def normalize_font(value: str | None) -> str:
    if value in FONTS:
        return str(value)
    lookup = {item.lower(): item for item in FONTS}
    return lookup.get(str(value or "").strip().lower(), "GothamBlack")


def normalize_shape(value: str | None) -> str:
    lookup = {item.lower(): item for item in SHAPES}
    aliases = {
        "rectangle": "Square",
        "rect": "Square",
        "box": "Square",
        "round": "Rounded",
        "circle": "Pill",
        "capsule": "Pill",
    }
    key = str(value or "Pill").strip().lower()
    return lookup.get(key) or aliases.get(key) or "Pill"


def normalize_glitch(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value or "").strip().lower() in {"1", "true", "yes", "on", "enabled"}


def normalize_discord_id(value: Any) -> str:
    text = str(value or "").strip()
    if text.startswith("<@") and text.endswith(">"):
        text = text[2:-1]
        if text.startswith("!"):
            text = text[1:]
    if text.isdigit() and 15 <= len(text) <= 22:
        return text
    return ""


class Store:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.data_dir = cfg.data_dir
        self.images_dir = self.data_dir / "images"
        self.state_path = self.data_dir / "state.json"
        self.state = empty_state()

    def load(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.images_dir.mkdir(parents=True, exist_ok=True)
        if self.state_path.exists():
            try:
                loaded = json.loads(self.state_path.read_text(encoding="utf-8"))
                if isinstance(loaded, dict):
                    state = empty_state()
                    state.update(loaded)
                    for key in empty_state():
                        if key != "version" and key != "revision" and not isinstance(state.get(key), dict):
                            state[key] = {}
                    self.state = state
            except (OSError, json.JSONDecodeError):
                self.state = empty_state()
        worker_sync.push_snapshot(self)

    def save(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        tmp = self.state_path.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(as_plain(self.state), indent=2, default=json_default), encoding="utf-8")
        tmp.replace(self.state_path)

    def bump(self) -> int:
        self.state["revision"] = int(self.state.get("revision") or 0) + 1
        self.save()
        return int(self.state["revision"])

    def default_tag(self, roblox_id: int) -> dict[str, Any]:
        staff = roblox_id in self.cfg.staff_roblox_ids
        return {
            "roblox_id": roblox_id,
            "roblox_username": "",
            "display_name": "",
            "outline_color": "#FFFFFF",
            "text_color": "#F4F6FF",
            "background_color": "#0C0E14",
            "font": "GothamBlack",
            "shape": "Pill",
            "glitch": False,
            "icon_image_url": "",
            "image_url": "",
            "bg_image_url": "",
            "icon_frames": [],
            "bg_frames": [],
            "icon_frame_delay": 0.08,
            "bg_frame_delay": 0.08,
            "updated_at": utc_now(),
            "staff": staff,
            "verified_badge": False,
            "verified_badge_glyph": "",
            "verified_badge_unicode": "",
            "discord_id": "",
            "icon_name": "",
            "bg_name": "",
        }

    def get_tag(self, roblox_id: int) -> dict[str, Any] | None:
        raw = self.state["nametags"].get(str(roblox_id))
        if not isinstance(raw, dict):
            return None
        tag = self.default_tag(roblox_id)
        tag.update(raw)
        tag["roblox_id"] = roblox_id
        tag["staff"] = bool(tag.get("staff")) or roblox_id in self.cfg.staff_roblox_ids
        tag["verified_badge"] = normalize_glitch(tag.get("verified_badge"))
        tag["verified_badge_glyph"] = ROBLOX_VERIFIED_BADGE_GLYPH if tag["verified_badge"] else ""
        tag["verified_badge_unicode"] = ROBLOX_VERIFIED_BADGE_UNICODE if tag["verified_badge"] else ""
        icon_frames = list(tag.get("icon_frames") or [])
        bg_frames = list(tag.get("bg_frames") or [])
        tag["icon_frames"] = icon_frames
        tag["icon_gif_frames"] = icon_frames
        tag["icon_frame_urls"] = icon_frames
        tag["bg_frames"] = bg_frames
        tag["bg_gif_frames"] = bg_frames
        tag["bg_frame_urls"] = bg_frames
        tag["gif_frame_delay"] = float(tag.get("icon_frame_delay") or 0.08)
        tag["shape"] = normalize_shape(str(tag.get("shape") or "Pill"))
        tag["glitch"] = normalize_glitch(tag.get("glitch"))
        tag["icon_name"] = str(tag.get("icon_name") or "")
        tag["bg_name"] = str(tag.get("bg_name") or "")
        return tag

    def ensure_tag(self, roblox_id: int) -> dict[str, Any]:
        tag = self.get_tag(roblox_id)
        if tag is None:
            tag = self.default_tag(roblox_id)
            self.state["nametags"][str(roblox_id)] = tag
            self.bump()
        return tag

    def upsert_tag(self, roblox_id: int, **fields: Any) -> dict[str, Any]:
        tag = self.ensure_tag(roblox_id)
        if "font" in fields and fields["font"] is not None:
            fields["font"] = normalize_font(str(fields["font"]))
        if "shape" in fields and fields["shape"] is not None:
            fields["shape"] = normalize_shape(str(fields["shape"]))
        if "glitch" in fields and fields["glitch"] is not None:
            fields["glitch"] = normalize_glitch(fields["glitch"])
        if "staff" in fields and fields["staff"] is not None:
            fields["staff"] = bool(fields["staff"])
        if "verified_badge" in fields and fields["verified_badge"] is not None:
            fields["verified_badge"] = normalize_glitch(fields["verified_badge"])
        for field, fallback in (
            ("outline_color", "#FFFFFF"),
            ("text_color", "#F4F6FF"),
            ("background_color", "#0C0E14"),
        ):
            if field in fields and fields[field] is not None:
                fields[field] = normalize_hex(str(fields[field]), fallback)
        if "display_name" in fields and fields["display_name"] is not None:
            fields["display_name"] = str(fields["display_name"])[:32]
        tag.update({k: v for k, v in fields.items() if v is not None})
        tag["roblox_id"] = roblox_id
        tag["updated_at"] = utc_now()
        tag["staff"] = bool(tag.get("staff")) or roblox_id in self.cfg.staff_roblox_ids
        tag["verified_badge"] = normalize_glitch(tag.get("verified_badge"))
        tag["verified_badge_glyph"] = ROBLOX_VERIFIED_BADGE_GLYPH if tag["verified_badge"] else ""
        tag["verified_badge_unicode"] = ROBLOX_VERIFIED_BADGE_UNICODE if tag["verified_badge"] else ""
        self.state["nametags"][str(roblox_id)] = tag
        self.bump()
        self._push_tag(tag)
        return self.get_tag(roblox_id) or tag

    def set_verified_badge(self, roblox_id: int, granted: bool) -> dict[str, Any]:
        return self.upsert_tag(int(roblox_id), verified_badge=bool(granted))

    def set_staff(self, roblox_id: int, granted: bool) -> dict[str, Any]:
        return self.upsert_tag(int(roblox_id), staff=bool(granted))

    def verified_badge_tags(self) -> list[dict[str, Any]]:
        return [tag for tag in self.all_tags().values() if tag.get("verified_badge")]

    def staff_tags(self) -> list[dict[str, Any]]:
        return [tag for tag in self.all_tags().values() if tag.get("staff")]

    def all_tags(self) -> dict[str, dict[str, Any]]:
        users: dict[str, dict[str, Any]] = {}
        for key, raw in self.state["nametags"].items():
            if not isinstance(raw, dict):
                continue
            try:
                roblox_id = int(raw.get("roblox_id") or key)
            except (TypeError, ValueError):
                continue
            tag = self.get_tag(roblox_id)
            if tag:
                users[str(roblox_id)] = tag
        return users

    def find_tags(self, query: str) -> list[dict[str, Any]]:
        needle = str(query or "").strip().lower()
        if not needle:
            return []
        hits: list[dict[str, Any]] = []
        for tag in self.all_tags().values():
            hay = " ".join(
                [
                    str(tag.get("roblox_id") or ""),
                    str(tag.get("roblox_username") or ""),
                    str(tag.get("display_name") or ""),
                ]
            ).lower()
            if needle in hay:
                hits.append(tag)
        return hits

    def find_exact(self, query: str) -> dict[str, Any] | None:
        needle = str(query or "").strip()
        if not needle:
            return None
        if needle.isdigit():
            return self.get_tag(int(needle))
        lowered = needle.lower()
        for tag in self.all_tags().values():
            if str(tag.get("roblox_username") or "").lower() == lowered:
                return tag
        return None

    def clear_image(self, roblox_id: int, kind: str) -> dict[str, Any]:
        kind = "icon" if kind == "icon" else "bg"
        shutil.rmtree(self.images_dir / str(roblox_id) / kind, ignore_errors=True)
        if kind == "icon":
            tag = self.upsert_tag(
                roblox_id,
                icon_image_url="",
                image_url="",
                icon_frames=[],
                icon_name="",
            )
        else:
            tag = self.upsert_tag(roblox_id, bg_image_url="", bg_frames=[], bg_name="")
        worker_sync.push_images(self.cfg, roblox_id, kind, [], 0.08)
        return tag

    def delete_tag(self, roblox_id: int, *, unlink: bool = True) -> bool:
        key = str(int(roblox_id))
        existed = isinstance(self.state["nametags"].get(key), dict)
        self.state["nametags"].pop(key, None)
        if unlink:
            for discord_id, mapped in list(self.state["links"].items()):
                try:
                    mapped_id = int(mapped.get("roblox_id") or 0)
                except (TypeError, ValueError, AttributeError):
                    continue
                if mapped_id == int(roblox_id):
                    self.state["links"].pop(discord_id, None)
        shutil.rmtree(self.images_dir / key, ignore_errors=True)
        if existed:
            self.bump()
            worker_sync.delete_tag(self.cfg, int(roblox_id))
        else:
            self.save()
        return existed

    def transfer_tag(self, source_id: int, target_id: int) -> dict[str, Any]:
        source_id = int(source_id)
        target_id = int(target_id)
        if source_id == target_id:
            raise ValueError("Source and target are the same user.")
        source = self.get_tag(source_id)
        if source is None:
            raise ValueError("Source nametag does not exist.")
        payload = {
            key: value
            for key, value in source.items()
            if key
            not in {
                "roblox_id",
                "icon_gif_frames",
                "icon_frame_urls",
                "bg_gif_frames",
                "bg_frame_urls",
                "gif_frame_delay",
                "staff",
                "verified_badge",
                "verified_badge_glyph",
                "verified_badge_unicode",
            }
        }
        payload["roblox_id"] = target_id
        target_existing = self.get_tag(target_id)
        payload["staff"] = bool(target_existing.get("staff")) if target_existing else False
        payload["verified_badge"] = bool(target_existing.get("verified_badge")) if target_existing else False
        if source.get("discord_id"):
            payload["discord_id"] = source.get("discord_id")
        src_dir = self.images_dir / str(source_id)
        dst_dir = self.images_dir / str(target_id)
        if dst_dir.exists():
            shutil.rmtree(dst_dir, ignore_errors=True)
        if src_dir.exists():
            shutil.copytree(src_dir, dst_dir)

        def rewrite(url: Any) -> Any:
            if isinstance(url, list):
                return [rewrite(item) for item in url]
            text = str(url or "")
            return text.replace(f"/nametag/{source_id}/", f"/nametag/{target_id}/")

        for field in ("icon_image_url", "image_url", "bg_image_url", "icon_frames", "bg_frames"):
            payload[field] = rewrite(payload.get(field))
        self.state["nametags"].pop(str(source_id), None)
        shutil.rmtree(src_dir, ignore_errors=True)
        for mapped in self.state["links"].values():
            if not isinstance(mapped, dict):
                continue
            try:
                if int(mapped.get("roblox_id") or 0) == source_id:
                    mapped["roblox_id"] = target_id
            except (TypeError, ValueError):
                continue
        self.state["nametags"][str(target_id)] = payload
        self.bump()
        tag = self.get_tag(target_id) or payload
        self._push_tag(tag)
        worker_sync.delete_tag(self.cfg, source_id)
        worker_sync.push_snapshot(self)
        return tag

    def revision_payload(self) -> dict[str, Any]:
        users = {
            key: str(tag.get("updated_at") or "")
            for key, tag in self.all_tags().items()
        }
        return {"revision": int(self.state.get("revision") or 0), "users": users}

    def image_dir(self, roblox_id: int, kind: str) -> Path:
        path = self.images_dir / str(roblox_id) / kind
        path.mkdir(parents=True, exist_ok=True)
        return path

    def save_image(self, roblox_id: int, kind: str, processed: Any, public_base: str) -> dict[str, Any]:
        folder = self.image_dir(roblox_id, kind)
        for old in folder.glob("*"):
            if old.is_file():
                old.unlink()
        stamp = str(int(time.time()))
        static_path = folder / f"static_{stamp}.png"
        static_path.write_bytes(processed.static_png)
        frame_urls: list[str] = []
        for index, frame in enumerate(processed.frames_png):
            frame_path = folder / f"frame_{index:03d}_{stamp}.png"
            frame_path.write_bytes(frame)
            frame_urls.append(f"{public_base}/media/nametag/{roblox_id}/{kind}/frame/{index}?v={stamp}")
        static_url = f"{public_base}/media/nametag/{roblox_id}/{kind}?v={stamp}"
        filename = str(getattr(processed, "filename", "") or "")
        fields: dict[str, Any] = {"updated_at": utc_now()}
        if kind == "icon":
            fields["icon_image_url"] = static_url
            fields["image_url"] = static_url
            fields["icon_frames"] = frame_urls if processed.animated else []
            fields["icon_frame_delay"] = processed.delay
            if filename:
                fields["icon_name"] = filename
        else:
            fields["bg_image_url"] = static_url
            fields["bg_frames"] = frame_urls if processed.animated else []
            fields["bg_frame_delay"] = processed.delay
            if filename:
                fields["bg_name"] = filename
        tag = self.upsert_tag(roblox_id, **fields)
        self._push_image_bytes(roblox_id, kind, processed)
        return tag

    def read_static(self, roblox_id: int, kind: str) -> bytes | None:
        folder = self.images_dir / str(roblox_id) / kind
        if not folder.exists():
            return None
        statics = sorted(folder.glob("static_*.png"))
        if statics:
            return statics[-1].read_bytes()
        frames = sorted(folder.glob("frame_*.png"))
        if frames:
            return frames[0].read_bytes()
        return None

    def read_frames(self, roblox_id: int, kind: str) -> list[bytes]:
        folder = self.images_dir / str(roblox_id) / kind
        if not folder.exists():
            return []
        frames = sorted(folder.glob("frame_*.png"))
        return [path.read_bytes() for path in frames]

    def link(self, discord_id: str, roblox_id: int, username: str = "") -> dict[str, Any]:
        for other_discord, mapped in list(self.state["links"].items()):
            if int(mapped.get("roblox_id") or 0) == roblox_id and other_discord != str(discord_id):
                self.state["links"].pop(other_discord, None)
        self.state["links"][str(discord_id)] = {
            "discord_id": str(discord_id),
            "roblox_id": roblox_id,
            "roblox_username": username,
            "updated_at": utc_now(),
        }
        tag = self.upsert_tag(
            roblox_id,
            discord_id=str(discord_id),
            roblox_username=username or self.ensure_tag(roblox_id).get("roblox_username") or "",
        )
        return tag

    def unlink(self, discord_id: str) -> int | None:
        mapped = self.state["links"].pop(str(discord_id), None)
        self.save()
        if not mapped:
            return None
        return int(mapped.get("roblox_id") or 0) or None

    def roblox_for_discord(self, discord_id: str) -> int | None:
        mapped = self.state["links"].get(str(discord_id))
        if not mapped:
            return None
        try:
            return int(mapped.get("roblox_id") or 0) or None
        except (TypeError, ValueError):
            return None

    def heartbeat(self, payload: dict[str, Any]) -> dict[str, Any]:
        roblox_id = int(payload.get("roblox_id") or 0)
        if roblox_id <= 0:
            raise ValueError("roblox_id required")
        entry = {
            "roblox_id": roblox_id,
            "user_id": roblox_id,
            "id": roblox_id,
            "roblox_username": str(payload.get("roblox_username") or ""),
            "display_name": str(payload.get("display_name") or ""),
            "place_id": payload.get("place_id"),
            "job_id": str(payload.get("job_id") or ""),
            "script_name": str(payload.get("script_name") or "Cryax Client"),
            "script_version": str(payload.get("script_version") or ""),
            "key": str(payload.get("key") or ""),
            "last_seen": time.time(),
            "updated_at": time.time(),
        }
        self.state["presence"][str(roblox_id)] = entry
        tag = self.get_tag(roblox_id)
        if tag is None:
            self.ensure_tag(roblox_id)
            tag = self.get_tag(roblox_id)
        if tag and entry["roblox_username"] and not tag.get("roblox_username"):
            self.upsert_tag(roblox_id, roblox_username=entry["roblox_username"])
        else:
            self.save()
        return {"ok": True, "roblox_id": roblox_id}

    def online_ids(self) -> list[int]:
        cutoff = time.time() - max(5, self.cfg.presence_ttl_seconds)
        alive: list[int] = []
        stale: list[str] = []
        for key, entry in self.state["presence"].items():
            if not isinstance(entry, dict):
                stale.append(key)
                continue
            last_seen = float(entry.get("last_seen") or 0)
            if last_seen >= cutoff:
                try:
                    alive.append(int(entry.get("roblox_id") or key))
                except (TypeError, ValueError):
                    stale.append(key)
            else:
                stale.append(key)
        for key in stale:
            self.state["presence"].pop(key, None)
        if stale:
            self.save()
        return alive

    def check_access(self, roblox_id: int, key: str) -> tuple[bool, str]:
        if str(roblox_id) in self.state.get("blacklist", {}):
            return False, "blacklisted"
        mode = self.cfg.access_mode
        if mode == "open":
            return True, "ok"
        if roblox_id in self.cfg.staff_roblox_ids:
            return True, "ok"
        if str(roblox_id) in self.state["whitelist"]:
            return True, "ok"
        if mode == "whitelist":
            return False, "not_authorized"
        normalized = (key or "").strip().upper()
        if not normalized:
            return False, "not_authorized"
        record = self.state["keys"].get(normalized)
        if not record:
            return False, "invalid_key"
        if record.get("revoked"):
            return False, "revoked"
        bound = record.get("roblox_id")
        if bound and int(bound) != int(roblox_id):
            return False, "key_bound"
        if not bound:
            record["roblox_id"] = int(roblox_id)
            self.save()
        return True, "ok"

    def add_whitelist(self, roblox_id: int) -> None:
        self.state["whitelist"][str(roblox_id)] = {"roblox_id": roblox_id, "added_at": utc_now()}
        self.save()

    def remove_whitelist(self, roblox_id: int) -> None:
        self.state["whitelist"].pop(str(roblox_id), None)
        self.save()

    def _bot_acl(self, key: str) -> dict[str, Any]:
        bucket = self.state.setdefault(key, {})
        if not isinstance(bucket, dict):
            bucket = {}
            self.state[key] = bucket
        return bucket

    def _set_bot_acl(self, key: str, collection: str, discord_id: str, added_by: str = "") -> dict[str, Any]:
        uid = normalize_discord_id(discord_id)
        if not uid:
            raise ValueError("invalid Discord id")
        record = {
            "discord_id": uid,
            "added_at": utc_now(),
            "added_by": normalize_discord_id(added_by) or str(added_by or ""),
        }
        self._bot_acl(key)[uid] = record
        self.save()
        return record

    def _remove_bot_acl(self, key: str, collection: str, discord_id: str) -> bool:
        uid = normalize_discord_id(discord_id)
        if not uid:
            return False
        existed = self._bot_acl(key).pop(uid, None) is not None
        if existed:
            self.save()
        return existed

    def _list_bot_acl(self, key: str) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        for uid, raw in self._bot_acl(key).items():
            record = dict(raw) if isinstance(raw, dict) else {"discord_id": uid}
            record["discord_id"] = str(record.get("discord_id") or uid)
            items.append(record)
        items.sort(key=lambda item: item["discord_id"])
        return items

    def is_bot_whitelisted(self, discord_id: str) -> bool:
        uid = normalize_discord_id(discord_id)
        return bool(uid) and uid in self._bot_acl("bot_whitelist")

    def is_bot_owner(self, discord_id: str) -> bool:
        uid = normalize_discord_id(discord_id)
        return bool(uid) and uid in self._bot_acl("bot_owners")

    def add_bot_whitelist(self, discord_id: str, added_by: str = "") -> dict[str, Any]:
        return self._set_bot_acl("bot_whitelist", "bot_whitelist", discord_id, added_by)

    def remove_bot_whitelist(self, discord_id: str) -> bool:
        return self._remove_bot_acl("bot_whitelist", "bot_whitelist", discord_id)

    def list_bot_whitelist(self) -> list[dict[str, Any]]:
        return self._list_bot_acl("bot_whitelist")

    def add_bot_owner(self, discord_id: str, added_by: str = "") -> dict[str, Any]:
        return self._set_bot_acl("bot_owners", "bot_owners", discord_id, added_by)

    def remove_bot_owner(self, discord_id: str) -> bool:
        return self._remove_bot_acl("bot_owners", "bot_owners", discord_id)

    def list_bot_owners(self) -> list[dict[str, Any]]:
        return self._list_bot_acl("bot_owners")

    def create_key(self, note: str = "") -> str:
        key = secrets.token_hex(4).upper()
        self.state["keys"][key] = {"key": key, "note": note, "created_at": utc_now(), "revoked": False}
        self.save()
        return key

    def revoke_key(self, key: str) -> bool:
        record = self.state["keys"].get(key.strip().upper())
        if not record:
            return False
        record["revoked"] = True
        self.save()
        return True

    def set_blacklist(self, roblox_id: int, blocked: bool) -> None:
        if blocked:
            self.state.setdefault("blacklist", {})[str(roblox_id)] = {
                "roblox_id": roblox_id,
                "updated_at": utc_now(),
            }
        else:
            self.state.setdefault("blacklist", {}).pop(str(roblox_id), None)
        self.save()

    def _push_tag(self, tag: dict[str, Any]) -> None:
        worker_sync.push_tag(self.cfg, tag)

    def _push_image_bytes(self, roblox_id: int, kind: str, processed: Any) -> None:
        frames = list(getattr(processed, "frames_png", None) or [])
        if not frames and getattr(processed, "static_png", None):
            frames = [processed.static_png]
        worker_sync.push_images(self.cfg, roblox_id, kind, frames, float(getattr(processed, "delay", 0.08) or 0.08))


def create_store(cfg: Config) -> Store:
    store = Store(cfg)
    store.load()
    return store
