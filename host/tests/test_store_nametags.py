from __future__ import annotations

import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from cryax_host.config import Config
from cryax_host.images import process_upload, render_preview
from cryax_host.nametag_ui import can_use_bot, is_owner, is_staff_member
from cryax_host.roblox import RobloxLookupError, resolve_roblox_user
from cryax_host.store import (
    ROBLOX_VERIFIED_BADGE_GLYPH,
    Store,
    as_plain,
    normalize_discord_id,
    normalize_glitch,
    normalize_shape,
)


def _png() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (16, 16), (220, 52, 60)).save(buf, format="PNG")
    return buf.getvalue()


def make_store(tmp_path: Path) -> Store:
    cfg = Config(api_secret="bloodontop", data_dir=tmp_path / "data")
    store = Store(cfg)
    store.load()
    return store


def test_shape_and_glitch_defaults(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    tag = store.upsert_tag(1, display_name="A", roblox_username="alpha", shape="rounded", glitch="enabled")
    assert tag["shape"] == "Rounded"
    assert tag["glitch"] is True
    assert normalize_shape("rectangle") == "Square"
    assert normalize_glitch("no") is False


def test_search_delete_transfer(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    store.upsert_tag(10, display_name="Owner", roblox_username="kryptex")
    processed = process_upload(_png(), "icon")
    processed.filename = "icon.png"
    store.save_image(10, "icon", processed, "http://127.0.0.1:8787")
    hits = store.find_tags("kryp")
    assert len(hits) == 1
    assert store.find_exact("Kryptex")["roblox_id"] == 10
    moved = store.transfer_tag(10, 20)
    assert moved["roblox_id"] == 20
    assert moved["roblox_username"] == "kryptex"
    assert store.get_tag(10) is None
    assert store.read_static(20, "icon")
    assert store.delete_tag(20) is True
    assert store.get_tag(20) is None
    assert store.read_static(20, "icon") is None


def test_preview_shape_bytes() -> None:
    png = render_preview(
        "Demo",
        "demo",
        "#FFFFFF",
        "#000000",
        "#111111",
        None,
        None,
        False,
        shape="Square",
        glitch=True,
    )
    assert png[:8] == b"\x89PNG\r\n\x1a\n"


def test_roblox_lookup_empty() -> None:
    try:
        resolve_roblox_user("  ")
    except RobloxLookupError as exc:
        assert "username" in str(exc).lower()
        return
    raise AssertionError("expected lookup error")


class _DummyUser:
    def __init__(self, user_id: int) -> None:
        self.id = user_id


def test_staff_ids_do_not_auto_grant_verified(tmp_path: Path) -> None:
    cfg = Config(api_secret="bloodontop", data_dir=tmp_path / "data", staff_roblox_ids={10826781066})
    store = Store(cfg)
    store.load()
    tag = store.ensure_tag(10826781066)
    assert tag["staff"] is True
    assert tag["verified_badge"] is False
    assert tag["verified_badge_glyph"] == ""
    store.set_staff(10826781066, False)
    assert store.get_tag(10826781066)["staff"] is True
    assert store.get_tag(10826781066)["verified_badge"] is False


def test_verified_badge_grant_persists_and_lists(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    granted = store.set_verified_badge(42, True)
    assert granted["verified_badge"] is True
    assert granted["verified_badge_unicode"] == "U+E000"
    assert granted["verified_badge_glyph"] == ROBLOX_VERIFIED_BADGE_GLYPH
    store.upsert_tag(42, display_name="Shown", roblox_username="shown")
    listed = store.verified_badge_tags()
    assert len(listed) == 1
    assert listed[0]["roblox_id"] == 42
    store.set_verified_badge(42, False)
    assert store.get_tag(42)["verified_badge"] is False
    assert store.verified_badge_tags() == []


def test_verified_badge_not_copied_on_transfer(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    store.upsert_tag(10, display_name="Owner", roblox_username="kryptex")
    store.set_verified_badge(10, True)
    moved = store.transfer_tag(10, 20)
    assert moved["roblox_id"] == 20
    assert moved["verified_badge"] is False
    assert store.get_tag(10) is None


def test_staff_grant_persists_and_lists(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    granted = store.set_staff(42, True)
    assert granted["staff"] is True
    store.upsert_tag(42, display_name="Shown", roblox_username="shown")
    listed = store.staff_tags()
    assert len(listed) == 1
    assert listed[0]["roblox_id"] == 42
    store.set_staff(42, False)
    assert store.get_tag(42)["staff"] is False
    assert store.staff_tags() == []


def test_staff_not_copied_on_transfer(tmp_path: Path) -> None:
    store = make_store(tmp_path)
    store.upsert_tag(10, display_name="Owner", roblox_username="kryptex")
    store.set_staff(10, True)
    moved = store.transfer_tag(10, 20)
    assert moved["roblox_id"] == 20
    assert moved["staff"] is False
    assert store.get_tag(10) is None


def test_verified_badge_preview_bytes() -> None:
    png = render_preview(
        "Demo",
        "demo",
        "#FFFFFF",
        "#000000",
        "#111111",
        None,
        None,
        False,
        shape="Pill",
        glitch=False,
        verified_badge=True,
    )
    assert png[:8] == b"\x89PNG\r\n\x1a\n"
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    blues = [
        pixel
        for pixel in img.getdata()
        if pixel[0] < 40 and 70 <= pixel[1] <= 140 and pixel[2] > 220 and pixel[3] > 200
    ]
    assert blues


def test_owner_only_verified_helpers() -> None:
    cfg = Config(discord_owner_id="111", staff_discord_ids={"222"})
    assert is_owner(cfg, _DummyUser(111)) is True
    assert is_owner(cfg, _DummyUser(222)) is False
    assert is_staff_member(cfg, _DummyUser(222)) is True
    assert is_staff_member(cfg, _DummyUser(111)) is True
    assert is_owner(Config(discord_owner_id=""), _DummyUser(111)) is False


def test_bot_whitelist_and_owner_whitelist(tmp_path: Path) -> None:
    root = "1330465176297668651"
    staff = "222333444555666777"
    extra_owner = "111222333444555666"
    friend = "999888777666555444"
    stranger = "555444333222111000"
    cfg = Config(discord_owner_id=root, staff_discord_ids={staff}, data_dir=tmp_path / "data")
    store = Store(cfg)
    store.load()
    assert "bot_whitelist" in store.state
    assert "bot_owners" in store.state
    assert normalize_discord_id(f"<@{friend}>") == friend
    assert store.add_bot_whitelist(friend, root)["discord_id"] == friend
    assert store.add_bot_owner(extra_owner, root)["discord_id"] == extra_owner
    assert can_use_bot(cfg, _DummyUser(int(root)), store) is True
    assert can_use_bot(cfg, _DummyUser(int(staff)), store) is True
    assert can_use_bot(cfg, _DummyUser(int(friend)), store) is True
    assert can_use_bot(cfg, _DummyUser(int(stranger)), store) is False
    assert is_owner(cfg, _DummyUser(int(extra_owner)), store) is True
    assert is_owner(cfg, _DummyUser(int(friend)), store) is False
    assert is_staff_member(cfg, _DummyUser(int(extra_owner)), store) is True
    assert store.remove_bot_whitelist(friend) is True
    assert can_use_bot(cfg, _DummyUser(int(friend)), store) is False
    assert store.remove_bot_owner(extra_owner) is True
    assert is_owner(cfg, _DummyUser(int(extra_owner)), store) is False
    loaded = Store(cfg)
    loaded.load()
    assert loaded.is_bot_whitelisted(friend) is False
    store.add_bot_whitelist(friend, root)
    loaded2 = Store(cfg)
    loaded2.load()
    assert loaded2.is_bot_whitelisted(friend) is True


def test_as_plain_allows_datetime_state_save(tmp_path: Path) -> None:
    from datetime import datetime, timezone

    stamp = datetime(2026, 9, 20, tzinfo=timezone.utc)
    assert as_plain({"updated_at": stamp})["updated_at"].startswith("2026-09-20")
    store = make_store(tmp_path)
    store.state["nametags"]["7"] = {"roblox_id": 7, "updated_at": stamp}
    store.save()
    loaded = json.loads(store.state_path.read_text(encoding="utf-8"))
    assert loaded["nametags"]["7"]["roblox_id"] == 7
    assert isinstance(loaded["nametags"]["7"]["updated_at"], str)
