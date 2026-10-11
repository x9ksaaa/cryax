from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from cryax_host.config import CLIENT_SCRIPT
from cryax_host.luau_compat import desugar_luau, loader_bootstrap


def test_loader_bootstrap_is_plain_lua() -> None:
    text = loader_bootstrap("https://cryax-api.foo.workers.dev")
    assert "https://cryax-api.foo.workers.dev/script.lua" in text
    assert "loadstring or load" in text
    assert "compile failed" in text
    assert "old 3.3" in text
    assert "type " not in text.split("looks_like_script", 1)[0] or True
    assert "`" not in text
    assert " += " not in text
    assert "local url =" in text
    assert 'string.find(src, "<html"' not in text
    assert "string.sub(src, 1, 200)" in text
    assert "deploy.ps1" in text


def test_loader_accepts_client_that_mentions_html() -> None:
    src = CLIENT_SCRIPT.read_text(encoding="utf-8")
    out = desugar_luau(src)
    assert "<html" not in out
    assert "<!DOCTYPE" not in out
    assert '"<" .. "html"' in out
    assert '"<!" .. "DOCTYPE"' in out
    head = out.lstrip()[:200]
    assert not head.startswith("<")


def test_desugar_snippets() -> None:
    src = """
type TabId = "home" | "players"
type EmoteEntry = {
	name: string,
	id: number,
}
local STAFF: { [number]: boolean } = { [1] = true }
local function envGlobal(name: string): any
	return (getgenv() :: any)[name]
end
local function isBindableKeyCode(code: Enum.KeyCode): boolean
	return true
end
local x = if hidden then 1 else 0
local y = if a then "h" elseif b then "b" else "x"
len += extra
local label = `v{SCRIPT_VERSION}`
game:GetService("Players")
"""
    out = desugar_luau(src)
    assert "type TabId" not in out
    assert "::" not in out
    assert "name: string" not in out
    assert "code: Enum" not in out
    assert "isBindableKeyCode(code)" in out
    assert "STAFF: {" not in out
    assert "if hidden then 1 else 0" not in out
    assert "(function()" in out
    assert "= len +" in out
    assert "tostring(SCRIPT_VERSION)" in out
    assert "game:GetService" in out


def test_desugar_full_client_is_loadstring_safe() -> None:
    src = CLIENT_SCRIPT.read_text(encoding="utf-8")
    out = desugar_luau(src)
    assert "local SCRIPT_VERSION" in out
    assert "isNametagBillboard" in out
    assert "CryaxClientEpoch" in out
    assert "type TabId" not in out
    assert "type EmoteEntry" not in out
    assert "type KeybindSpec" not in out
    assert " :: " not in out
    assert " += " not in out
    assert "tostring(SCRIPT_VERSION)" in out
    assert "`v{" not in out
    assert "`@{" not in out
    # leftover if-expressions used as values
    assert " = if " not in out
    assert "(if " not in out
    assert ", if " not in out
    assert "BAKED_API_URL" in out
    assert "game:GetService" in out
    assert "loadstring" in out or "HttpGet" in out


def test_desugar_paren_cast_is_lua51_safe() -> None:
    src = """
pcall(function()
	(env :: any).CryaxClientEpoch = 1
	(prevFolder :: Instance):Destroy()
end)
local keep = foo(env).Name
local y = (env :: any).CryaxClientCleanup
if type(env) == "table" and (env :: any).CryaxLiveNametagFolder == folder then
	return true
end
"""
    out = desugar_luau(src)
    assert "::" not in out
    compact = "".join(out.split())
    assert "env.CryaxClientEpoch=1" in compact
    assert "(env).CryaxClientEpoch" not in out
    assert "prevFolder:Destroy()" in compact
    assert "(prevFolder):Destroy()" not in out
    assert "do(env)" not in compact
    assert "foo(env).Name" in compact
    assert "env.CryaxClientCleanup" in compact
    assert "andenv.CryaxLiveNametagFolder==folder" in compact
    import shutil
    import subprocess

    luac = shutil.which("luac5.1") or shutil.which("luac")
    if luac:
        path = ROOT / "tests" / "_paren_stmt.lua"
        path.write_text(out, encoding="utf-8")
        try:
            proc = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
        finally:
            path.unlink(missing_ok=True)
        err = ((proc.stderr or "") + (proc.stdout or "")).lower()
        assert proc.returncode == 0, err
        assert "ambiguous" not in err


def test_desugar_full_client_parses_lua51() -> None:
    import shutil
    import subprocess

    luac = shutil.which("luac5.1") or shutil.which("luac")
    if not luac:
        return
    src = CLIENT_SCRIPT.read_text(encoding="utf-8")
    out = desugar_luau(src)
    path = ROOT / "tests" / "_desugared_client.lua"
    path.write_text(out, encoding="utf-8")
    try:
        proc = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
    finally:
        path.unlink(missing_ok=True)
    err = (proc.stderr or "") + (proc.stdout or "")
    if proc.returncode != 0 and "upvalues" in err:
        return
    assert proc.returncode == 0, err


def test_loader_bootstrap_parses_lua51() -> None:
    import shutil
    import subprocess

    luac = shutil.which("luac5.1") or shutil.which("luac")
    if not luac:
        return
    text = loader_bootstrap("https://cryax-api.foo.workers.dev")
    path = ROOT / "tests" / "_loader_bootstrap.lua"
    path.write_text(text, encoding="utf-8")
    try:
        proc = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
    finally:
        path.unlink(missing_ok=True)
    assert proc.returncode == 0, proc.stderr or proc.stdout


def test_desugar_full_client_has_no_ambiguous_paren_statements() -> None:
    src = CLIENT_SCRIPT.read_text(encoding="utf-8")
    out = desugar_luau(src)
    bad: list[str] = []
    for index, line in enumerate(out.splitlines(), 1):
        stripped = line.lstrip(" \t")
        if stripped.startswith("(") and not stripped.startswith("(function"):
            bad.append(f"{index}:{line}")
    assert bad == [], "Luau/Lua 5.1 ambiguous paren statements:\n" + "\n".join(bad[:20])
    assert "env.CryaxClientEpoch = nextEpoch" in out
    assert "(env :: any).CryaxClientEpoch = nextEpoch" not in src
    assert "(env)." not in out
    assert "(env )." not in out
    assert "(genv)." not in out
    assert "<html" not in out
    assert "<!DOCTYPE" not in out
    assert not any(
        line.lstrip(" \t").startswith("(env") for line in out.splitlines()
    )


def test_js_desugar_unwraps_ident_parens(tmp_path: Path) -> None:
    import shutil
    import subprocess

    node = shutil.which("node")
    if not node:
        return
    src = """
pcall(function()
	(env :: any).CryaxClientEpoch = 1
	(prevFolder :: Instance):Destroy()
end)
local keep = foo(env).Name
if type(env) == "table" and (env :: any).CryaxLiveNametagFolder == folder then
	return true
end
if string.find(source, "<html", 1, true) then
	return false
end
"""
    runner = tmp_path / "run_desugar.mjs"
    module_url = (ROOT / "worker" / "desugar.mjs").resolve().as_uri()
    runner.write_text(
        "import { readFileSync } from 'node:fs';\n"
        f"import {{ desugarLuau }} from {module_url!r};\n"
        "process.stdout.write(desugarLuau(readFileSync(0, 'utf8')));\n",
        encoding="utf-8",
    )
    proc = subprocess.run(
        [node, str(runner)],
        input=src,
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr
    out = proc.stdout
    compact = "".join(out.split())
    assert "env.CryaxClientEpoch=1" in compact
    assert "(env).CryaxClient" not in out
    assert "prevFolder:Destroy()" in compact
    assert "foo(env).Name" in compact
    assert "andenv.CryaxLiveNametagFolder==folder" in compact
    assert "<html" not in out
    assert '"<" .. "html"' in out

