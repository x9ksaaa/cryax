from __future__ import annotations

import sys
import time

from .bot import create_bot
from .config import load_config
from .procutil import InstanceLock
from .store import create_store


def main() -> None:
    cfg = load_config()
    if not cfg.discord_token:
        print("DISCORD_TOKEN is empty", file=sys.stderr)
        raise SystemExit(2)
    lock = InstanceLock(cfg.data_dir / "discord_worker.lock")
    for _ in range(10):
        if lock.acquire():
            break
        time.sleep(0.2)
    else:
        print("[cryax-host] Discord worker already running — refusing a second copy", flush=True)
        raise SystemExit(0)
    try:
        store = create_store(cfg)
        bot = create_bot(cfg, store)
        print("[cryax-host] Discord worker starting", flush=True)
        bot.run(cfg.discord_token)
    finally:
        lock.release()


if __name__ == "__main__":
    main()
