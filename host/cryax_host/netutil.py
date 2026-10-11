from __future__ import annotations

import json
import re
import socket
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass

WIN_LISTEN_RE = re.compile(r":(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$", re.I)
UNIX_LISTEN_RE = re.compile(r":(\d+)\b.*\b(?:LISTEN|LISTENING)\b.*?(\d+)", re.I)


@dataclass
class PortStatus:
    port: int
    in_use: bool
    cryax_healthy: bool
    pids: list[int]


def tcp_open(port: int, host: str = "127.0.0.1") -> bool:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.4)
    try:
        return sock.connect_ex((host, port)) == 0
    finally:
        sock.close()


def probe_cryax(port: int) -> bool:
    url = f"http://127.0.0.1:{port}/health"
    try:
        with urllib.request.urlopen(url, timeout=1.2) as response:
            payload = json.loads(response.read().decode("utf-8", errors="replace"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError, ValueError):
        return False
    return isinstance(payload, dict) and payload.get("ok") is True


def parse_listening_pids(output: str, port: int) -> list[int]:
    found: list[int] = []
    seen: set[int] = set()
    for line in output.splitlines():
        match = WIN_LISTEN_RE.search(line) or UNIX_LISTEN_RE.search(line)
        if not match:
            continue
        if int(match.group(1)) != port:
            continue
        pid = int(match.group(2))
        if pid and pid not in seen:
            seen.add(pid)
            found.append(pid)
    return found


def listening_pids(port: int) -> list[int]:
    commands: list[list[str]]
    if sys.platform == "win32":
        commands = [["netstat", "-ano", "-p", "tcp"]]
    else:
        commands = [
            ["ss", "-ltnp"],
            ["netstat", "-ltnp"],
            ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"],
        ]
    for argv in commands:
        try:
            output = subprocess.check_output(argv, text=True, stderr=subprocess.STDOUT, timeout=4)
        except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
            continue
        pids = parse_listening_pids(output, port)
        if pids:
            return pids
        if sys.platform != "win32" and "lsof" in argv[0]:
            numeric = []
            for line in output.splitlines()[1:]:
                parts = line.split()
                if len(parts) >= 2 and parts[1].isdigit():
                    numeric.append(int(parts[1]))
            if numeric:
                return list(dict.fromkeys(numeric))
    return []


def inspect_port(port: int) -> PortStatus:
    in_use = tcp_open(port)
    healthy = probe_cryax(port) if in_use else False
    pids = listening_pids(port) if in_use else []
    return PortStatus(port=port, in_use=in_use, cryax_healthy=healthy, pids=pids)


def format_port_help(status: PortStatus) -> str:
    port = status.port
    pid_text = ", ".join(str(pid) for pid in status.pids) if status.pids else "unknown"
    if status.cryax_healthy:
        return "\n".join(
            [
                f"[cryax-host] CONTROL is already running at http://127.0.0.1:{port}",
                "Open that page. Do not start a second copy (port 8787 is already taken).",
                "To stop it and start fresh, in PowerShell:",
                *(
                    [f"  taskkill /PID {pid} /T /F" for pid in status.pids]
                    if status.pids
                    else [
                        f"  netstat -ano | findstr :{port}",
                        "  taskkill /PID <pid> /T /F",
                    ]
                ),
                "Then run .\\start.ps1 again.",
            ]
        )
    return "\n".join(
        [
            f"[cryax-host] Port {port} is already in use (PID {pid_text}).",
            "That is a leftover Cryax host or another app. Stop it, then start again:",
            *(
                [f"  taskkill /PID {pid} /T /F" for pid in status.pids]
                if status.pids
                else [
                    f"  netstat -ano | findstr :{port}",
                    "  taskkill /PID <pid> /T /F",
                ]
            ),
            "Or in PowerShell:  cd $HOME\\cryax\\host ; .\\start.ps1 -Restart",
        ]
    )


def bind_failed(exc: BaseException) -> bool:
    winerror = getattr(exc, "winerror", None)
    errno = getattr(exc, "errno", None)
    return winerror == 10048 or errno in {48, 98, 10048} or "10048" in str(exc)
