from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from cryax_host.procutil import (
    InstanceLock,
    is_discord_worker_command,
    list_discord_worker_pids,
)


def test_is_discord_worker_command() -> None:
    assert is_discord_worker_command(r"C:\Python\python.exe -m cryax_host.discord_worker")
    assert is_discord_worker_command("/usr/bin/python3 -m cryax_host.discord_worker")
    assert is_discord_worker_command(r"C:\cryax\host\.venv\Scripts\python.exe C:\cryax\host\cryax_host\discord_worker.py")
    assert not is_discord_worker_command("python main.py")
    assert not is_discord_worker_command("pytest host/tests/test_api.py")


def test_list_discord_worker_pids_skips_self(monkeypatch) -> None:
    import cryax_host.procutil as procutil

    monkeypatch.setattr(
        procutil,
        "process_command_lines",
        lambda: [
            (os.getpid(), "python -m cryax_host.discord_worker"),
            (4242, "python -m cryax_host.discord_worker"),
            (7, "python main.py"),
        ],
    )
    assert list_discord_worker_pids() == [4242]
    assert list_discord_worker_pids(exclude={4242}) == []


def test_instance_lock_blocks_second_process(tmp_path: Path) -> None:
    path = tmp_path / "discord_worker.lock"
    holder = subprocess.Popen(
        [
            sys.executable,
            "-c",
            (
                "import sys, time; from pathlib import Path; "
                f"sys.path.insert(0, {str(ROOT)!r}); "
                "from cryax_host.procutil import InstanceLock; "
                f"lock = InstanceLock(Path({str(path)!r})); "
                "assert lock.acquire(); time.sleep(8); lock.release()"
            ),
        ]
    )
    try:
        for _ in range(20):
            if path.exists() and path.stat().st_size > 0:
                break
            time.sleep(0.1)
        other = InstanceLock(path)
        assert other.acquire() is False
    finally:
        holder.terminate()
        holder.wait(timeout=5)
