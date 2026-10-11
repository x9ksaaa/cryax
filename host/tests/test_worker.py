from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "worker"
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if str(WORKER) not in sys.path:
    sys.path.insert(0, str(WORKER))

from scorp_host.config import Config, loadstring_for, paste_loadstring, script_public_base
from scorp_host.worker_sync import push_tag

import build


def test_loadstring_uses_loader_on_workers_dev() -> None:
    assert (
        loadstring_for("https://scorp-api.foo.workers.dev")
        == 'loadstring(game:HttpGet("https://scorp-api.foo.workers.dev/loader"))()'
    )
    assert "/script.lua" in loadstring_for("http://127.0.0.1:8787")


def test_paste_loadstring_defaults_to_official_worker() -> None:
    assert (
        paste_loadstring(Config(public_base_url="http://127.0.0.1:8787"))
        == 'loadstring(game:HttpGet("https://scorp-api.scorpontop.workers.dev/loader"))()'
    )
    assert (
        paste_loadstring(Config(worker_base_url="https://scorp-api.foo.workers.dev"))
        == 'loadstring(game:HttpGet("https://scorp-api.foo.workers.dev/loader"))()'
    )
    cfg = Config(public_base_url="http://127.0.0.1:8787", worker_base_url="https://scorp-api.foo.workers.dev")
    assert script_public_base(cfg, "https://ignored.trycloudflare.com") == "https://scorp-api.foo.workers.dev"


def test_push_tag_noop_without_worker_url() -> None:
    push_tag(Config(), {"roblox_id": 1, "display_name": "x"})


def test_worker_build_embeds_client() -> None:
    out = build.build()
    text = out.read_text(encoding="utf-8")
    assert "export const CLIENT_SCRIPT" in text
    assert "SCRIPT_VERSION" in text
    assert "https://shield.xao.wtf/api/loader/550af30c-aaa3-4338-acab-f44010a5ef09" in text
    assert "ScorpAntiVc" not in text
    assert "ScorpKeybinds.json" in text
    assert "pages.keybinds" in text
    assert "hasVerifiedBadge" in text
    assert "isScriptStaff" in text
    assert "FIREBASE_STAFF" in text
    assert "utf8.char(0xE000)" in text
    assert "local TAG_HEIGHT = 58" in text
    assert "SCRIPT_VERSION" in text
    assert "3.14" in text
    assert "paintCandle" in text
    assert "Fakeout" in text
    assert "setFakeout" in text
    assert "restoreLocalAfterFakeout" in text
    assert "neverVoidLocalPlayer" in text
    assert "Smoother hub + official loader" in text
    assert "Unload Script" in text
    assert "Misc Unload + visible tags" in text
    assert "ScorpNametagGui" in text
    assert "NameDisplayDistance = 0" in text
    assert "Players.NameDisplayDistance = 0" in text
    assert "Unload Script" in text
    assert "function mountBillboard" in text
    assert "gui.Parent = folder" in text
    assert 'Instance.new("BlurEffect")' not in text
    assert "startCandleLoop" not in text
    assert "badge.Text = VERIFIED_BADGE_GLYPH" in text
    assert "badge.Font = Enum.Font.Gotham" in text
    assert "shownName .. VERIFIED_BADGE_GLYPH" not in text
    assert "HasVerifiedBadge.png" not in text
    assert "isNametagBillboard" in text
    assert "game:HttpGet(options.Url)" in text
    js = (WORKER / "src" / "worker.js").read_text(encoding="utf-8")
    assert "looks_like_script" in js
    assert "Scorp loader" in js
    assert 'path === "/loader"' in js
    assert "CLIENT_SCRIPT" in js
    assert "ScorpStore" in js
    assert "this.ensure()" in js
    assert "this.dispatch" in js
    assert "/internal/snapshot" in js
    assert "/nametags" in js
    root_toml = WORKER.parents[1] / "wrangler.toml"
    toml = root_toml.read_text(encoding="utf-8")
    assert 'main = "host/worker/src/worker.js"' in toml
    assert "build.mjs" in toml
    assert "ScorpStore" in toml
    assert (WORKER / "build.mjs").exists()
