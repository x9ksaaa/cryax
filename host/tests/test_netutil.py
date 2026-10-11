from __future__ import annotations

import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from cryax_host.netutil import format_port_help, inspect_port, parse_listening_pids, probe_cryax, tcp_open


def test_parse_windows_netstat() -> None:
    sample = """
  TCP    0.0.0.0:8787           0.0.0.0:0              LISTENING       7932
  TCP    [::]:8787              [::]:0                 LISTENING       7932
  TCP    127.0.0.1:18787        0.0.0.0:0              LISTENING       99
"""
    assert parse_listening_pids(sample, 8787) == [7932]


def test_format_already_running_mentions_dashboard() -> None:
    from cryax_host.netutil import PortStatus

    text = format_port_help(PortStatus(port=8787, in_use=True, cryax_healthy=True, pids=[7932]))
    assert "already running" in text
    assert "http://127.0.0.1:8787" in text
    assert "7932" in text


def test_probe_health_on_local_server() -> None:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            body = json.dumps({"ok": True}).encode("ascii")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: object) -> None:
            return

    server = HTTPServer(("127.0.0.1", 0), Handler)
    port = int(server.server_address[1])
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        assert tcp_open(port) is True
        assert probe_cryax(port) is True
        status = inspect_port(port)
        assert status.in_use is True
        assert status.cryax_healthy is True
    finally:
        server.shutdown()
        server.server_close()
