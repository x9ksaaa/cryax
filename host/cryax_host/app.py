from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import uvicorn

from .api import create_app
from .config import load_config
from .netutil import bind_failed, format_port_help, inspect_port
from .store import Store
from .supervisor import Supervisor

HOST_DIR = Path(__file__).resolve().parents[1]
if str(HOST_DIR) not in sys.path:
    sys.path.insert(0, str(HOST_DIR))


async def run() -> None:
    cfg = load_config()
    status = inspect_port(cfg.port)
    if status.in_use:
        print(format_port_help(status))
        raise SystemExit(0 if status.cryax_healthy else 1)

    store = Store(cfg)
    store.load()
    supervisor = Supervisor(cfg, store)
    supervisor.start_defaults()
    app = create_app(cfg, store, supervisor)
    server = uvicorn.Server(
        uvicorn.Config(app, host=cfg.host, port=cfg.port, log_level="info")
    )
    print(f"[cryax-host] CONTROL http://127.0.0.1:{cfg.port}")
    print(f"[cryax-host] API on http://{cfg.host}:{cfg.port}")
    print(f"[cryax-host] Public URL {cfg.public_base}")
    print("[cryax-host] Localhost only reaches the executor on this PC; other players need a tunnel URL.")
    try:
        await server.serve()
        if not getattr(server, "started", False):
            print(format_port_help(inspect_port(cfg.port)))
            raise SystemExit(1)
    except OSError as exc:
        if bind_failed(exc):
            print(format_port_help(inspect_port(cfg.port)))
            raise SystemExit(1)
        raise
    finally:
        supervisor.shutdown()


def main() -> None:
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        print("\n[cryax-host] stopped")


if __name__ == "__main__":
    main()
