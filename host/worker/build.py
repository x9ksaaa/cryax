from __future__ import annotations

import json
from pathlib import Path
import sys

WORKER_DIR = Path(__file__).resolve().parent
HOST_DIR = WORKER_DIR.parent
REPO_ROOT = WORKER_DIR.parents[1]
CLIENT_CANDIDATES = ("cryax.lua", "cryax src.lua", "cryax src.txt")
if str(HOST_DIR) not in sys.path:
    sys.path.insert(0, str(HOST_DIR))

from cryax_host.luau_compat import desugar_luau


def client_script_path() -> Path:
    for name in CLIENT_CANDIDATES:
        path = REPO_ROOT / name
        if path.exists():
            return path
    return REPO_ROOT / "cryax src.lua"


def build() -> Path:
    src = client_script_path()
    if not src.exists():
        raise FileNotFoundError(f"client script missing: {src}")
    text = desugar_luau(src.read_text(encoding="utf-8"))
    out = WORKER_DIR / "src" / "script.generated.js"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("export const CLIENT_SCRIPT = " + json.dumps(text) + ";\n", encoding="utf-8")
    return out


if __name__ == "__main__":
    path = build()
    print(f"wrote {path}")
