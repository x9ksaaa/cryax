<<<<<<< HEAD
from __future__ import annotations

import io
import sys
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scorp_host.api import create_app
from scorp_host.config import Config
from scorp_host.images import process_upload
from scorp_host.store import Store


def _png(color: tuple[int, int, int] = (220, 52, 60)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (32, 32), color).save(buf, format="PNG")
    return buf.getvalue()


def make_client(tmp_path: Path) -> tuple[TestClient, Store, Config]:
    cfg = Config(
        api_secret="bloodontop",
        public_base_url="http://127.0.0.1:8787",
        access_mode="open",
        data_dir=tmp_path / "data",
    )
    store = Store(cfg)
    store.load()
    return TestClient(create_app(cfg, store)), store, cfg


def test_health_and_secret(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    assert client.get("/health").json()["ok"] is True
    denied = client.get("/nametags")
    assert denied.status_code == 401
    ok = client.get("/nametags", headers={"x-api-secret": "bloodontop"})
    assert ok.status_code == 200
    assert ok.json()["users"] == {}


def test_nametag_roundtrip(tmp_path: Path) -> None:
    client, store, cfg = make_client(tmp_path)
    processed = process_upload(_png(), "icon")
    store.save_image(123, "icon", processed, cfg.public_base)
    store.upsert_tag(
        123,
        display_name="Kryptex",
        roblox_username="kryptex",
        text_color="#F4F6FF",
        background_color="#0C0E14",
        shape="Pill",
        glitch=False,
    )
    headers = {"x-api-secret": "bloodontop"}
    tags = client.get("/nametags", headers=headers).json()["users"]
    assert tags["123"]["display_name"] == "Kryptex"
    assert tags["123"]["roblox_username"] == "kryptex"
    assert tags["123"]["shape"] == "Pill"
    assert tags["123"]["glitch"] is False
    assert tags["123"]["verified_badge"] is False
    assert tags["123"]["staff"] is False
    assert "?v=" in tags["123"]["icon_image_url"]
    via_root = client.get("/scorp/v1/nametags", headers=headers).json()["users"]
    assert via_root["123"]["display_name"] == "Kryptex"
    revision = client.get("/nametags/revision", headers=headers).json()
    assert revision["revision"] >= 1
    assert "123" in revision["users"]
    assert client.get("/scorp/v1/nametags/revision", headers=headers).status_code == 200
    payload = client.get("/images/nametag/123/icon/b64", headers=headers).json()
    assert payload["data"]
    assert payload["frames"]
    media = client.get("/media/nametag/123/icon")
    assert media.status_code == 200
    assert media.headers["content-type"] == "image/png"
    assert "no-store" in (media.headers.get("cache-control") or "")


def test_verified_badge_in_nametags_payload(tmp_path: Path) -> None:
    client, store, _ = make_client(tmp_path)
    store.upsert_tag(55, display_name="Badge", roblox_username="badgeuser")
    store.set_verified_badge(55, True)
    headers = {"x-api-secret": "bloodontop"}
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["verified_badge"] is True
    assert tag["verified_badge_unicode"] == "U+E000"
    assert tag["verified_badge_glyph"] == "\uE000"
    store.set_verified_badge(55, False)
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["verified_badge"] is False
    assert tag["verified_badge_glyph"] == ""


def test_staff_flag_in_nametags_payload(tmp_path: Path) -> None:
    client, store, _ = make_client(tmp_path)
    store.upsert_tag(55, display_name="Staff", roblox_username="staffuser")
    store.set_staff(55, True)
    headers = {"x-api-secret": "bloodontop"}
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["staff"] is True
    store.set_staff(55, False)
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["staff"] is False


def test_nametags_datetime_does_not_500(tmp_path: Path) -> None:
    from datetime import datetime, timezone

    client, store, _ = make_client(tmp_path)
    store.upsert_tag(8, display_name="Dated", roblox_username="dated")
    store.state["nametags"]["8"]["updated_at"] = datetime.now(timezone.utc)
    tags = client.get("/nametags", headers={"x-api-secret": "bloodontop"})
    assert tags.status_code == 200
    assert tags.json()["users"]["8"]["display_name"] == "Dated"


def test_control_firebase_push_without_credentials(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    pushed = client.post("/control/api/firebase/push")
    assert pushed.status_code == 200
    body = pushed.json()
    assert body["ok"] is False
    assert "GOOGLE_APPLICATION_CREDENTIALS" in (body.get("detail") or body.get("hint") or "")


def test_heartbeat_online_access(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    headers = {"x-api-secret": "bloodontop"}
    posted = client.post(
        "/scorp/v1/heartbeat",
        headers=headers,
        json={"roblox_id": 99, "roblox_username": "demo"},
    )
    assert posted.status_code == 200
    via_get = client.get(
        "/scorp/v1/heartbeat",
        headers=headers,
        params={"roblox_id": 100, "roblox_username": "demo2"},
    )
    assert via_get.status_code == 200
    online = client.get("/scorp/v1/online", headers=headers).json()
    assert 99 in online["user_ids"]
    assert 100 in online["user_ids"]
    access = client.get("/scorp/v1/access", headers=headers, params={"roblox_id": 99})
    assert access.json()["allowed"] is True
    revision = client.get("/nametags/revision", headers=headers).json()
    assert "revision" in revision
    home = client.get("/")
    assert home.status_code == 200
    assert b"CONTROL" in home.content
    assert b"FIREBASE" in home.content
    assert b"scorp-api.scorpontop.workers.dev/loader" in home.content
    assert b"Push everything" in home.content
    assert b"firebase-service-account.json" in home.content
    panel = client.get("/control/api/status")
    assert panel.status_code == 200
    assert panel.json()["services"]["api"]["online"] is True
    assert panel.json()["loadstring"] == (
        'loadstring(game:HttpGet("https://scorp-api.scorpontop.workers.dev/loader"))()'
    )
    assert panel.json()["firebase"]["online"] is False
    hint = panel.json()["firebase"]["hint"] or ""
    assert "GOOGLE_APPLICATION_CREDENTIALS" in hint
    assert "firebase-service-account.json" in hint
    stopped = client.post("/control/api/services/api/stop")
    assert stopped.status_code == 200
    paused = client.get("/nametags", headers={"x-api-secret": "bloodontop"})
    assert paused.status_code == 503
    client.post("/control/api/services/api/start")


def test_control_password(tmp_path: Path) -> None:
    cfg = Config(
        api_secret="bloodontop",
        public_base_url="http://127.0.0.1:8787",
        access_mode="open",
        data_dir=tmp_path / "data",
        control_password="secret",
    )
    store = Store(cfg)
    store.load()
    client = TestClient(create_app(cfg, store))
    assert client.get("/control/api/status").status_code == 401
    denied = client.post("/control/api/login", json={"password": "nope"})
    assert denied.status_code == 401
    ok = client.post("/control/api/login", json={"password": "secret"})
    assert ok.status_code == 200
    assert client.get("/control/api/status").status_code == 200


def _gif() -> bytes:
    buf = io.BytesIO()
    frames = [Image.new("RGB", (24, 24), color) for color in ((220, 52, 60), (52, 211, 153), (59, 130, 246))]
    frames[0].save(buf, format="GIF", save_all=True, append_images=frames[1:], duration=80, loop=0)
    return buf.getvalue()


def test_gif_becomes_png_frames(tmp_path: Path) -> None:
    client, store, cfg = make_client(tmp_path)
    processed = process_upload(_gif(), "icon")
    assert processed.animated is True
    assert len(processed.frames_png) >= 2
    assert processed.static_png[:8] == b"\x89PNG\r\n\x1a\n"
    store.save_image(7, "icon", processed, cfg.public_base)
    headers = {"x-api-secret": "bloodontop"}
    payload = client.get("/images/nametag/7/icon/b64", headers=headers).json()
    assert len(payload["frames"]) >= 2
    assert payload["delay"] > 0
    tags = client.get("/nametags", headers=headers).json()["users"]["7"]
    assert tags["icon_gif_frames"]
    assert tags["gif_frame_delay"] > 0


def test_script_loadstring(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    script = client.get("/script.lua")
    assert script.status_code == 200
    assert b"SCRIPT_VERSION" in script.content
    assert b'local SCRIPT_VERSION = "3.14"' in script.content
    assert b"BAKED_API_URL" in script.content
    assert b"stripForeignNametags" in script.content
    assert b"ScorpAnimGen" in script.content
    assert b"ScorpClientEpoch" in script.content
    assert b"candleStroke" in script.content
    assert b"paintCandle" in script.content
    assert b"Unload Script" in script.content
    assert b"Remove the hub, nametags, and tools from this game" in script.content
    assert b"function unloadScript" in script.content
    assert b'Instance.new("BlurEffect")' not in script.content
    assert b"uiBlur.Enabled = open" not in script.content
    assert b"tween(uiBlur" not in script.content
    assert b"hoverGrow(row, 1.02)" not in script.content
    assert b"candleBreathing" not in script.content
    assert b'Text = "SCORP"' in script.content
    assert b"https://shield.xao.wtf/api/loader/550af30c-aaa3-4338-acab-f44010a5ef09" in script.content
    assert b"ScorpAntiVc" not in script.content
    assert b"toggle_mic_mute_new" not in script.content
    assert b"ScorpKeybinds.json" in script.content
    assert b'addNav("keybinds"' in script.content
    assert b"pages.keybinds" in script.content
    assert b"setKeybindAction" in script.content
    assert b"hasVerifiedBadge" in script.content
    assert b"local TAG_HEIGHT = 58" in script.content
    assert b'ScorpNametagGui' in script.content
    assert b"NameDisplayDistance = 0" in script.content
    assert b"Players.NameDisplayDistance = 0" in script.content
    assert b"function mountBillboard" in script.content
    assert b"gui.Parent = folder" in script.content
    assert b'miscSection("Script", 90)' in script.content
    assert b"Unload Script" in script.content
    assert b"utf8.char(0xE000)" in script.content
    assert b"badge.Text = VERIFIED_BADGE_GLYPH" in script.content
    assert b"badge.Font = Enum.Font.Gotham" in script.content
    assert b"shownName .. VERIFIED_BADGE_GLYPH" not in script.content
    assert b"HasVerifiedBadge.png" not in script.content
    assert b"verified_badge" in script.content
    assert b"isScriptStaff" in script.content
    assert b"FIREBASE_STAFF" in script.content
    assert b"setFakeout" in script.content
    assert b"restoreLocalAfterFakeout" in script.content
    assert b"neverVoidLocalPlayer" in script.content
    assert b"rodeToVoid" in script.content
    assert b'Text = "Fakeout"' in script.content
    assert b"id = \"fakeout\"" in script.content
    assert b"staffAccessListeners" in script.content
    assert b"notifyStaffAccess" in script.content
    assert b"badge.Visible = staff" not in script.content
    assert b"ScorpNametagEpoch" in script.content
    assert b"message (15) Kryptex nametag renderer" in script.content
    assert b'local function usernameFor' in script.content
    assert b'network.fetchSite("/nametags")' in script.content
    assert b'network.fetchSite("/nametags/revision")' in script.content
    assert client.get("/scorp.lua").status_code == 200
    loader = client.get("/loadstring")
    assert loader.status_code == 200
    assert "loadstring(game:HttpGet(" in loader.text
    assert "scorp-api.scorpontop.workers.dev/loader" in loader.text
    status = client.get("/control/api/status").json()
    assert "loadstring" in status
    assert status["loadstring"] == 'loadstring(game:HttpGet("https://scorp-api.scorpontop.workers.dev/loader"))()'
    loader_file = client.get("/loader.lua")
    assert loader_file.status_code == 200
    assert b"script.lua" in loader_file.content
    assert b"looks_like_script" in loader_file.content
    assert b"string.sub(src, 1, 200)" in loader_file.content
    assert b'string.find(src, "<html"' not in loader_file.content
    assert b"<html" not in script.content
    assert b"<!DOCTYPE" not in script.content
    assert b"loadstring or load" in loader_file.content
    assert b"local SCRIPT_VERSION" not in loader_file.content
    loader_body = client.get("/loader")
    assert loader_body.status_code == 200
    assert b"Scorp loader" in loader_body.content
    assert b"type TabId" not in loader_body.content
    assert len(loader_body.content) < 4000
    assert b"compile failed" in loader_body.content
    assert b"old 3.3" in loader_body.content
    assert b"type TabId" not in script.content
    assert b"env.ScorpClientEpoch = nextEpoch" in script.content
    assert b"(env :: any).ScorpClientEpoch" not in script.content
    assert b"(env).ScorpClient" not in script.content
    assert b"(env ).ScorpClient" not in script.content
    assert b"do (env).ScorpClientEpoch" not in script.content
    for line in script.text.splitlines():
        stripped = line.lstrip(" \t")
        if stripped.startswith("(env") or stripped.startswith("(prevFolder"):
            raise AssertionError(f"ambiguous paren statement: {line}")


def test_worker_loadstring_in_control(tmp_path: Path) -> None:
    cfg = Config(
        api_secret="bloodontop",
        public_base_url="http://127.0.0.1:8787",
        access_mode="open",
        data_dir=tmp_path / "data",
        worker_base_url="https://scorp-api.foo.workers.dev",
    )
    store = Store(cfg)
    store.load()
    client = TestClient(create_app(cfg, store))
    line = client.get("/control/api/status").json()["loadstring"]
    assert line == 'loadstring(game:HttpGet("https://scorp-api.foo.workers.dev/loader"))()'
    assert "workers.dev/loader" in client.get("/loadstring").text
=======
from __future__ import annotations

import io
import sys
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scorp_host.api import create_app
from scorp_host.config import Config
from scorp_host.images import process_upload
from scorp_host.store import Store


def _png(color: tuple[int, int, int] = (220, 52, 60)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (32, 32), color).save(buf, format="PNG")
    return buf.getvalue()


def make_client(tmp_path: Path) -> tuple[TestClient, Store, Config]:
    cfg = Config(
        api_secret="bloodontop",
        public_base_url="http://127.0.0.1:8787",
        access_mode="open",
        data_dir=tmp_path / "data",
    )
    store = Store(cfg)
    store.load()
    return TestClient(create_app(cfg, store)), store, cfg


def test_health_and_secret(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    assert client.get("/health").json()["ok"] is True
    denied = client.get("/nametags")
    assert denied.status_code == 401
    ok = client.get("/nametags", headers={"x-api-secret": "bloodontop"})
    assert ok.status_code == 200
    assert ok.json()["users"] == {}


def test_nametag_roundtrip(tmp_path: Path) -> None:
    client, store, cfg = make_client(tmp_path)
    processed = process_upload(_png(), "icon")
    store.save_image(123, "icon", processed, cfg.public_base)
    store.upsert_tag(
        123,
        display_name="Kryptex",
        roblox_username="kryptex",
        text_color="#F4F6FF",
        background_color="#0C0E14",
        shape="Pill",
        glitch=False,
    )
    headers = {"x-api-secret": "bloodontop"}
    tags = client.get("/nametags", headers=headers).json()["users"]
    assert tags["123"]["display_name"] == "Kryptex"
    assert tags["123"]["roblox_username"] == "kryptex"
    assert tags["123"]["shape"] == "Pill"
    assert tags["123"]["glitch"] is False
    assert tags["123"]["verified_badge"] is False
    assert tags["123"]["staff"] is False
    assert "?v=" in tags["123"]["icon_image_url"]
    via_root = client.get("/scorp/v1/nametags", headers=headers).json()["users"]
    assert via_root["123"]["display_name"] == "Kryptex"
    revision = client.get("/nametags/revision", headers=headers).json()
    assert revision["revision"] >= 1
    assert "123" in revision["users"]
    assert client.get("/scorp/v1/nametags/revision", headers=headers).status_code == 200
    payload = client.get("/images/nametag/123/icon/b64", headers=headers).json()
    assert payload["data"]
    assert payload["frames"]
    media = client.get("/media/nametag/123/icon")
    assert media.status_code == 200
    assert media.headers["content-type"] == "image/png"
    assert "no-store" in (media.headers.get("cache-control") or "")


def test_verified_badge_in_nametags_payload(tmp_path: Path) -> None:
    client, store, _ = make_client(tmp_path)
    store.upsert_tag(55, display_name="Badge", roblox_username="badgeuser")
    store.set_verified_badge(55, True)
    headers = {"x-api-secret": "bloodontop"}
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["verified_badge"] is True
    assert tag["verified_badge_unicode"] == "U+E000"
    assert tag["verified_badge_glyph"] == "\uE000"
    store.set_verified_badge(55, False)
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["verified_badge"] is False
    assert tag["verified_badge_glyph"] == ""


def test_staff_flag_in_nametags_payload(tmp_path: Path) -> None:
    client, store, _ = make_client(tmp_path)
    store.upsert_tag(55, display_name="Staff", roblox_username="staffuser")
    store.set_staff(55, True)
    headers = {"x-api-secret": "bloodontop"}
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["staff"] is True
    store.set_staff(55, False)
    tag = client.get("/nametags", headers=headers).json()["users"]["55"]
    assert tag["staff"] is False


def test_nametags_datetime_does_not_500(tmp_path: Path) -> None:
    from datetime import datetime, timezone

    client, store, _ = make_client(tmp_path)
    store.upsert_tag(8, display_name="Dated", roblox_username="dated")
    store.state["nametags"]["8"]["updated_at"] = datetime.now(timezone.utc)
    tags = client.get("/nametags", headers={"x-api-secret": "bloodontop"})
    assert tags.status_code == 200
    assert tags.json()["users"]["8"]["display_name"] == "Dated"


def test_control_firebase_push_without_credentials(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    pushed = client.post("/control/api/firebase/push")
    assert pushed.status_code == 200
    body = pushed.json()
    assert body["ok"] is False
    assert "GOOGLE_APPLICATION_CREDENTIALS" in (body.get("detail") or body.get("hint") or "")


def test_heartbeat_online_access(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    headers = {"x-api-secret": "bloodontop"}
    posted = client.post(
        "/scorp/v1/heartbeat",
        headers=headers,
        json={"roblox_id": 99, "roblox_username": "demo"},
    )
    assert posted.status_code == 200
    via_get = client.get(
        "/scorp/v1/heartbeat",
        headers=headers,
        params={"roblox_id": 100, "roblox_username": "demo2"},
    )
    assert via_get.status_code == 200
    online = client.get("/scorp/v1/online", headers=headers).json()
    assert 99 in online["user_ids"]
    assert 100 in online["user_ids"]
    access = client.get("/scorp/v1/access", headers=headers, params={"roblox_id": 99})
    assert access.json()["allowed"] is True
    revision = client.get("/nametags/revision", headers=headers).json()
    assert "revision" in revision
    home = client.get("/")
    assert home.status_code == 200
    assert b"CONTROL" in home.content
    assert b"FIREBASE" in home.content
    assert b"scorp-api.scorpontop.workers.dev/loader" in home.content
    assert b"Push everything" in home.content
    assert b"firebase-service-account.json" in home.content
    panel = client.get("/control/api/status")
    assert panel.status_code == 200
    assert panel.json()["services"]["api"]["online"] is True
    assert panel.json()["loadstring"] == (
        'loadstring(game:HttpGet("https://scorp-api.scorpontop.workers.dev/loader"))()'
    )
    assert panel.json()["firebase"]["online"] is False
    hint = panel.json()["firebase"]["hint"] or ""
    assert "GOOGLE_APPLICATION_CREDENTIALS" in hint
    assert "firebase-service-account.json" in hint
    stopped = client.post("/control/api/services/api/stop")
    assert stopped.status_code == 200
    paused = client.get("/nametags", headers={"x-api-secret": "bloodontop"})
    assert paused.status_code == 503
    client.post("/control/api/services/api/start")


def test_control_password(tmp_path: Path) -> None:
    cfg = Config(
        api_secret="bloodontop",
        public_base_url="http://127.0.0.1:8787",
        access_mode="open",
        data_dir=tmp_path / "data",
        control_password="secret",
    )
    store = Store(cfg)
    store.load()
    client = TestClient(create_app(cfg, store))
    assert client.get("/control/api/status").status_code == 401
    denied = client.post("/control/api/login", json={"password": "nope"})
    assert denied.status_code == 401
    ok = client.post("/control/api/login", json={"password": "secret"})
    assert ok.status_code == 200
    assert client.get("/control/api/status").status_code == 200


def _gif() -> bytes:
    buf = io.BytesIO()
    frames = [Image.new("RGB", (24, 24), color) for color in ((220, 52, 60), (52, 211, 153), (59, 130, 246))]
    frames[0].save(buf, format="GIF", save_all=True, append_images=frames[1:], duration=80, loop=0)
    return buf.getvalue()


def test_gif_becomes_png_frames(tmp_path: Path) -> None:
    client, store, cfg = make_client(tmp_path)
    processed = process_upload(_gif(), "icon")
    assert processed.animated is True
    assert len(processed.frames_png) >= 2
    assert processed.static_png[:8] == b"\x89PNG\r\n\x1a\n"
    store.save_image(7, "icon", processed, cfg.public_base)
    headers = {"x-api-secret": "bloodontop"}
    payload = client.get("/images/nametag/7/icon/b64", headers=headers).json()
    assert len(payload["frames"]) >= 2
    assert payload["delay"] > 0
    tags = client.get("/nametags", headers=headers).json()["users"]["7"]
    assert tags["icon_gif_frames"]
    assert tags["gif_frame_delay"] > 0


def test_script_loadstring(tmp_path: Path) -> None:
    client, _, _ = make_client(tmp_path)
    script = client.get("/script.lua")
    assert script.status_code == 200
    assert b"SCRIPT_VERSION" in script.content
    assert b'local SCRIPT_VERSION = "3.14"' in script.content
    assert b"BAKED_API_URL" in script.content
    assert b"stripForeignNametags" in script.content
    assert b"ScorpAnimGen" in script.content
    assert b"ScorpClientEpoch" in script.content
    assert b"candleStroke" in script.content
    assert b"paintCandle" in script.content
    assert b"Unload Script" in script.content
    assert b"Remove the hub, nametags, and tools from this game" in script.content
    assert b"function unloadScript" in script.content
    assert b'Instance.new("BlurEffect")' not in script.content
    assert b"uiBlur.Enabled = open" not in script.content
    assert b"tween(uiBlur" not in script.content
    assert b"hoverGrow(row, 1.02)" not in script.content
    assert b"candleBreathing" not in script.content
    assert b'Text = "SCORP"' in script.content
    assert b"https://shield.xao.wtf/api/loader/550af30c-aaa3-4338-acab-f44010a5ef09" in script.content
    assert b"ScorpAntiVc" not in script.content
    assert b"toggle_mic_mute_new" not in script.content
    assert b"ScorpKeybinds.json" in script.content
    assert b'addNav("keybinds"' in script.content
    assert b"pages.keybinds" in script.content
    assert b"setKeybindAction" in script.content
    assert b"hasVerifiedBadge" in script.content
    assert b"local TAG_HEIGHT = 58" in script.content
    assert b'ScorpNametagGui' in script.content
    assert b"NameDisplayDistance = 0" in script.content
    assert b"Players.NameDisplayDistance = 0" in script.content
    assert b"function mountBillboard" in script.content
    assert b"gui.Parent = folder" in script.content
    assert b'miscSection("Script", 90)' in script.content
    assert b"Unload Script" in script.content
    assert b"utf8.char(0xE000)" in script.content
    assert b"badge.Text = VERIFIED_BADGE_GLYPH" in script.content
    assert b"badge.Font = Enum.Font.Gotham" in script.content
    assert b"shownName .. VERIFIED_BADGE_GLYPH" not in script.content
    assert b"HasVerifiedBadge.png" not in script.content
    assert b"verified_badge" in script.content
    assert b"isScriptStaff" in script.content
    assert b"FIREBASE_STAFF" in script.content
    assert b"setFakeout" in script.content
    assert b"restoreLocalAfterFakeout" in script.content
    assert b"neverVoidLocalPlayer" in script.content
    assert b"rodeToVoid" in script.content
    assert b'miscToggle(8, "Fakeout"' in script.content
    assert b'id = "fakeout"' in script.content
    assert b"staffAccessListeners" in script.content
    assert b"notifyStaffAccess" in script.content
    assert b"badge.Visible = staff" not in script.content
    assert b"ScorpNametagEpoch" in script.content
    assert b"message (15) Kryptex nametag renderer" in script.content
    assert b'local function usernameFor' in script.content
    assert b'network.fetchSite("/nametags")' in script.content
    assert b'network.fetchSite("/nametags/revision")' in script.content
    assert client.get("/scorp.lua").status_code == 200
    loader = client.get("/loadstring")
    assert loader.status_code == 200
    assert "loadstring(game:HttpGet(" in loader.text
    assert "scorp-api.scorpontop.workers.dev/loader" in loader.text
    status = client.get("/control/api/status").json()
    assert "loadstring" in status
    assert status["loadstring"] == 'loadstring(game:HttpGet("https://scorp-api.scorpontop.workers.dev/loader"))()'
    loader_file = client.get("/loader.lua")
    assert loader_file.status_code == 200
    assert b"script.lua" in loader_file.content
    assert b"looks_like_script" in loader_file.content
    assert b"string.sub(src, 1, 200)" in loader_file.content
    assert b'string.find(src, "<html"' not in loader_file.content
    assert b"<html" not in script.content
    assert b"<!DOCTYPE" not in script.content
    assert b"loadstring or load" in loader_file.content
    assert b"local SCRIPT_VERSION" not in loader_file.content
    loader_body = client.get("/loader")
    assert loader_body.status_code == 200
    assert b"Scorp loader" in loader_body.content
    assert b"type TabId" not in loader_body.content
    assert len(loader_body.content) < 4000
    assert b"compile failed" in loader_body.content
    assert b"old 3.3" in loader_body.content
    assert b"type TabId" not in script.content
    assert b"env.ScorpClientEpoch = nextEpoch" in script.content
    assert b"(env :: any).ScorpClientEpoch" not in script.content
    assert b"(env).ScorpClient" not in script.content
    assert b"(env ).ScorpClient" not in script.content
    assert b"do (env).ScorpClientEpoch" not in script.content
    for line in script.text.splitlines():
        stripped = line.lstrip(" \t")
        if stripped.startswith("(env") or stripped.startswith("(prevFolder"):
            raise AssertionError(f"ambiguous paren statement: {line}")


def test_worker_loadstring_in_control(tmp_path: Path) -> None:
    cfg = Config(
        api_secret="bloodontop",
        public_base_url="http://127.0.0.1:8787",
        access_mode="open",
        data_dir=tmp_path / "data",
        worker_base_url="https://scorp-api.foo.workers.dev",
    )
    store = Store(cfg)
    store.load()
    client = TestClient(create_app(cfg, store))
    line = client.get("/control/api/status").json()["loadstring"]
    assert line == 'loadstring(game:HttpGet("https://scorp-api.foo.workers.dev/loader"))()'
    assert "workers.dev/loader" in client.get("/loadstring").text
>>>>>>> 58a20b8 (Fix Fakeout script test to match the Misc toggle title in source.)
