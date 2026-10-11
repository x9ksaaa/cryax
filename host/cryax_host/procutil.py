from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from collections.abc import Iterable
from pathlib import Path
from typing import Any

WORKER_MARKERS = (
    "cryax_host.discord_worker",
    "cryax_host/discord_worker.py",
    "cryax_host\\discord_worker.py",
)


def is_discord_worker_command(command: str) -> bool:
    text = str(command or "")
    compact = text.replace("\\", "/").lower()
    return any(marker.replace("\\", "/").lower() in compact for marker in WORKER_MARKERS)


def process_command_lines() -> list[tuple[int, str]]:
    if sys.platform == "win32":
        return _windows_process_command_lines()
    return _linux_process_command_lines()


def _linux_process_command_lines() -> list[tuple[int, str]]:
    rows: list[tuple[int, str]] = []
    proc = Path("/proc")
    if not proc.is_dir():
        return rows
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            raw = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        cmd = raw.replace(b"\x00", b" ").decode("utf-8", errors="replace").strip()
        if cmd:
            rows.append((int(entry.name), cmd))
    return rows


def _windows_process_command_lines() -> list[tuple[int, str]]:
    script = (
        "$ErrorActionPreference='SilentlyContinue'; "
        "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine } | "
        "Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    )
    try:
        output = subprocess.check_output(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=8,
        )
    except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return []
    output = output.strip()
    if not output:
        return []
    try:
        data = json.loads(output)
    except json.JSONDecodeError:
        return []
    if isinstance(data, dict):
        data = [data]
    rows: list[tuple[int, str]] = []
    if not isinstance(data, list):
        return rows
    for item in data:
        if not isinstance(item, dict):
            continue
        try:
            pid = int(item.get("ProcessId") or 0)
        except (TypeError, ValueError):
            continue
        cmd = str(item.get("CommandLine") or "")
        if pid > 0 and cmd:
            rows.append((pid, cmd))
    return rows


def list_discord_worker_pids(*, exclude: Iterable[int] | None = None) -> list[int]:
    skip = {os.getpid(), os.getppid()}
    if exclude:
        skip |= {int(pid) for pid in exclude if pid}
    found: list[int] = []
    seen: set[int] = set()
    for pid, cmd in process_command_lines():
        if pid in skip or pid in seen or pid <= 0:
            continue
        if is_discord_worker_command(cmd):
            seen.add(pid)
            found.append(pid)
    return found


def pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if sys.platform == "win32":
        try:
            output = subprocess.check_output(
                ["tasklist", "/FI", f"PID eq {pid}", "/NH"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=4,
            )
        except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
            return False
        return str(pid) in output and "No tasks" not in output
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def _terminate(pid: int) -> None:
    if sys.platform == "win32":
        subprocess.run(
            ["taskkill", "/PID", str(pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=8,
            check=False,
        )
        return
    os.kill(pid, signal.SIGTERM)


def _kill_force(pid: int) -> None:
    if sys.platform == "win32":
        _terminate(pid)
        return
    os.kill(pid, signal.SIGKILL)


def kill_pids(pids: Iterable[int], *, timeout: float = 5.0) -> list[int]:
    targets = [int(pid) for pid in dict.fromkeys(pids) if pid and pid not in {os.getpid(), os.getppid()}]
    if not targets:
        return []
    for pid in targets:
        try:
            _terminate(pid)
        except ProcessLookupError:
            continue
        except OSError:
            continue
    deadline = time.time() + timeout
    remaining = {pid for pid in targets if pid_alive(pid)}
    while remaining and time.time() < deadline:
        time.sleep(0.1)
        remaining = {pid for pid in remaining if pid_alive(pid)}
    for pid in list(remaining):
        try:
            _kill_force(pid)
        except (ProcessLookupError, OSError):
            pass
    return [pid for pid in targets if not pid_alive(pid)]


def kill_discord_workers(*, exclude: Iterable[int] | None = None) -> list[int]:
    return kill_pids(list_discord_worker_pids(exclude=exclude))


class InstanceLock:
    def __init__(self, path: Path):
        self.path = Path(path)
        self._fp: Any = None

    def acquire(self) -> bool:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._fp = open(self.path, "a+", encoding="utf-8")
        try:
            if self._fp.tell() == 0:
                self._fp.write("0")
                self._fp.flush()
            self._fp.seek(0)
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(self._fp.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl

                fcntl.flock(self._fp.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.release()
            return False
        self._fp.seek(0)
        self._fp.truncate()
        self._fp.write(str(os.getpid()))
        self._fp.flush()
        return True

    def release(self) -> None:
        fp = self._fp
        self._fp = None
        if fp is None:
            return
        try:
            fp.seek(0)
            if os.name == "nt":
                import msvcrt

                try:
                    msvcrt.locking(fp.fileno(), msvcrt.LK_UNLCK, 1)
                except OSError:
                    pass
            else:
                import fcntl

                fcntl.flock(fp.fileno(), fcntl.LOCK_UN)
        except OSError:
            pass
        finally:
            fp.close()
