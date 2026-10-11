from __future__ import annotations

import base64
import traceback
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse, Response

from .config import Config, CLIENT_SCRIPT, paste_loadstring, script_public_base
from .luau_compat import desugar_luau, loader_bootstrap
from .store import Store, as_plain
from .supervisor import Supervisor

STATIC_DIR = Path(__file__).resolve().parent / "static"
CONTROL_HTML = STATIC_DIR / "control.html"
COOKIE = "cryax_control"
PAUSED_PREFIXES = ("/nametags", "/images/nametag", "/media/nametag", "/cryax/")


def _b64(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def create_app(cfg: Config, store: Store, supervisor: Supervisor | None = None) -> FastAPI:
    app = FastAPI(title="Cryax nametag host", version="1.0.0")
    no_store = {"Cache-Control": "no-store, no-cache, must-revalidate", "Pragma": "no-cache"}
    boss = supervisor or Supervisor(cfg, store)
    app.state.supervisor = boss

    def require_secret(
        request: Request,
        secret: str | None = None,
        x_api_secret: str | None = Header(default=None, alias="x-api-secret"),
    ) -> None:
        provided = (x_api_secret or secret or request.query_params.get("secret") or "").strip()
        if provided != cfg.api_secret:
            raise HTTPException(status_code=401, detail="bad secret")

    def control_ok(request: Request) -> bool:
        if not cfg.control_password:
            return True
        return request.cookies.get(COOKIE) == boss.session_token()

    def require_control(request: Request) -> None:
        if not control_ok(request):
            raise HTTPException(status_code=401, detail="login")

    @app.exception_handler(Exception)
    async def unhandled(request: Request, exc: Exception):
        boss.log("api", traceback.format_exc())
        return JSONResponse(
            {"detail": str(exc) or exc.__class__.__name__},
            status_code=500,
        )

    @app.middleware("http")
    async def control_and_logs(request: Request, call_next):
        path = request.url.path
        if path.startswith(PAUSED_PREFIXES) and not boss.api_enabled:
            return JSONResponse({"detail": "api_paused"}, status_code=503)
        response = await call_next(request)
        if not path.startswith("/control"):
            client = request.client.host if request.client else "127.0.0.1"
            port = request.client.port if request.client else 0
            phrase = "OK" if response.status_code < 400 else "ERR"
            boss.log(
                "api",
                f'INFO:     {client}:{port} - "{request.method} {path} HTTP/1.1" {response.status_code} {phrase}',
            )
        return response

    @app.get("/")
    def home() -> FileResponse:
        return FileResponse(CONTROL_HTML, media_type="text/html")

    @app.get("/favicon.ico")
    def favicon() -> Response:
        return Response(status_code=204)

    @app.get("/health")
    def health() -> dict[str, Any]:
        return {
            "ok": True,
            "revision": int(store.state.get("revision") or 0),
            "public_base_url": cfg.public_base,
            "access_mode": cfg.access_mode,
            "bot": bool(cfg.discord_token),
        }

    _script_mtime = None
    _script_text = None

    def _client_script() -> Response:
        nonlocal _script_mtime, _script_text
        if not CLIENT_SCRIPT.exists():
            raise HTTPException(status_code=404, detail="client script missing")
        mtime = CLIENT_SCRIPT.stat().st_mtime
        if _script_text is None or _script_mtime != mtime:
            try:
                _script_text = desugar_luau(CLIENT_SCRIPT.read_text(encoding="utf-8"))
                _script_mtime = mtime
            except Exception as exc:
                raise HTTPException(status_code=500, detail=f"script compile failed: {exc}") from exc
        return Response(
            content=_script_text,
            media_type="text/plain; charset=utf-8",
            headers={
                **no_store,
                "Content-Disposition": "inline; filename=cryax.lua",
            },
        )

    @app.get("/script.lua")
    def script_lua() -> Response:
        return _client_script()

    @app.get("/script")
    def script_alias() -> Response:
        return _client_script()

    @app.get("/cryax.lua")
    def cryax_lua() -> Response:
        return _client_script()

    @app.get("/loadstring")
    def loadstring_text() -> Response:
        return Response(
            content=paste_loadstring(cfg) + "\n",
            media_type="text/plain; charset=utf-8",
            headers=no_store,
        )

    def _loader() -> Response:
        base = script_public_base(cfg, boss.tunnel_url)
        return Response(
            content=loader_bootstrap(base),
            media_type="text/plain; charset=utf-8",
            headers={**no_store, "Content-Disposition": "inline; filename=loader.lua"},
        )

    @app.get("/loader")
    def loader() -> Response:
        return _loader()

    @app.get("/loader.lua")
    def loader_lua() -> Response:
        return _loader()

    @app.get("/nametags")
    @app.get("/cryax/v1/nametags")
    def nametags(request: Request, secret: str | None = None, x_api_secret: str | None = Header(default=None, alias="x-api-secret")):
        require_secret(request, secret, x_api_secret)
        return JSONResponse({"users": as_plain(store.all_tags())}, headers=no_store)

    @app.get("/nametags/revision")
    @app.get("/cryax/v1/nametags/revision")
    def nametags_revision(request: Request, secret: str | None = None, x_api_secret: str | None = Header(default=None, alias="x-api-secret")):
        require_secret(request, secret, x_api_secret)
        return JSONResponse(as_plain(store.revision_payload()), headers=no_store)

    @app.get("/images/nametag/{user_id}/{kind}/b64")
    def nametag_b64(
        user_id: int,
        kind: str,
        request: Request,
        secret: str | None = None,
        x_api_secret: str | None = Header(default=None, alias="x-api-secret"),
    ):
        require_secret(request, secret, x_api_secret)
        if kind not in {"icon", "bg"}:
            raise HTTPException(status_code=404, detail="unknown kind")
        tag = store.get_tag(user_id)
        frames = store.read_frames(user_id, kind)
        if not frames:
            static = store.read_static(user_id, kind)
            if static:
                frames = [static]
        if not frames:
            return JSONResponse({"data": "", "frames": []})
        delay = 0.08
        if tag:
            delay = float(tag.get("icon_frame_delay" if kind == "icon" else "bg_frame_delay") or 0.08)
        encoded = [_b64(frame) for frame in frames]
        return JSONResponse(
            {
                "data": encoded[0],
                "frames": encoded,
                "delay": delay,
                "content_type": "image/png",
            },
            headers=no_store,
        )

    @app.get("/images/nametag/{user_id}/{kind}.png")
    def nametag_png(user_id: int, kind: str):
        if kind not in {"icon", "bg"}:
            raise HTTPException(status_code=404, detail="unknown kind")
        blob = store.read_static(user_id, kind)
        if not blob:
            raise HTTPException(status_code=404, detail="missing image")
        return Response(content=blob, media_type="image/png", headers=no_store)

    @app.get("/images/nametag/{user_id}/{kind}/frames/{index}.png")
    def nametag_frame_png(user_id: int, kind: str, index: int):
        if kind not in {"icon", "bg"}:
            raise HTTPException(status_code=404, detail="unknown kind")
        frames = store.read_frames(user_id, kind)
        if index < 0 or index >= len(frames):
            raise HTTPException(status_code=404, detail="missing frame")
        return Response(content=frames[index], media_type="image/png", headers=no_store)

    @app.get("/media/nametag/{user_id}/{kind}")
    def media_static(user_id: int, kind: str):
        if kind not in {"icon", "bg"}:
            raise HTTPException(status_code=404, detail="unknown kind")
        blob = store.read_static(user_id, kind)
        if not blob:
            raise HTTPException(status_code=404, detail="missing image")
        return Response(content=blob, media_type="image/png", headers=no_store)

    @app.get("/media/nametag/{user_id}/{kind}/frame/{index}")
    def media_frame(user_id: int, kind: str, index: int):
        if kind not in {"icon", "bg"}:
            raise HTTPException(status_code=404, detail="unknown kind")
        frames = store.read_frames(user_id, kind)
        if index < 0 or index >= len(frames):
            raise HTTPException(status_code=404, detail="missing frame")
        return Response(content=frames[index], media_type="image/png", headers=no_store)

    def _heartbeat_payload(raw: dict[str, Any], request: Request) -> dict[str, Any]:
        merged = dict(raw)
        for key in ("roblox_id", "roblox_username", "display_name", "place_id", "job_id", "script_version", "key"):
            if key in request.query_params and not merged.get(key):
                merged[key] = request.query_params.get(key)
        return store.heartbeat(merged)

    @app.api_route("/cryax/v1/heartbeat", methods=["GET", "POST"])
    async def heartbeat(
        request: Request,
        secret: str | None = None,
        x_api_secret: str | None = Header(default=None, alias="x-api-secret"),
    ):
        require_secret(request, secret, x_api_secret)
        body: dict[str, Any] = {}
        if request.method == "POST":
            try:
                parsed = await request.json()
                if isinstance(parsed, dict):
                    body = parsed
            except Exception:
                body = {}
        try:
            return _heartbeat_payload(body, request)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc

    @app.get("/cryax/v1/online")
    def online(request: Request, secret: str | None = None, x_api_secret: str | None = Header(default=None, alias="x-api-secret")):
        require_secret(request, secret, x_api_secret)
        ids = store.online_ids()
        return {
            "user_ids": ids,
            "users": [{"roblox_id": user_id} for user_id in ids],
        }

    @app.get("/cryax/v1/access")
    def access(
        request: Request,
        roblox_id: int = Query(default=0),
        roblox_username: str = Query(default=""),
        key: str = Query(default=""),
        secret: str | None = None,
        x_api_secret: str | None = Header(default=None, alias="x-api-secret"),
    ):
        require_secret(request, secret, x_api_secret)
        allowed, reason = store.check_access(roblox_id, key)
        return {"allowed": allowed, "reason": reason, "username": roblox_username}

    @app.post("/cryax/v1/session")
    async def session(
        request: Request,
        secret: str | None = None,
        x_api_secret: str | None = Header(default=None, alias="x-api-secret"),
    ):
        require_secret(request, secret, x_api_secret)
        body: dict[str, Any] = {}
        try:
            parsed = await request.json()
            if isinstance(parsed, dict):
                body = parsed
        except Exception:
            body = {}
        if body.get("roblox_id"):
            try:
                store.heartbeat(body)
            except ValueError:
                pass
        ids = store.online_ids()
        return {
            "ok": True,
            "presence": {
                "user_ids": ids,
                "users": [{"roblox_id": user_id} for user_id in ids],
            },
            "config": {
                "presence_interval": 3,
                "command_poll_interval": 0.35,
            },
        }

    @app.post("/cryax/v1/executions")
    def executions(request: Request, secret: str | None = None, x_api_secret: str | None = Header(default=None, alias="x-api-secret")):
        require_secret(request, secret, x_api_secret)
        return {"ok": True}

    @app.get("/cryax/v1/commands")
    def commands_get(request: Request, secret: str | None = None, x_api_secret: str | None = Header(default=None, alias="x-api-secret")):
        require_secret(request, secret, x_api_secret)
        return {"commands": []}

    @app.post("/cryax/v1/commands")
    def commands_post(request: Request, secret: str | None = None, x_api_secret: str | None = Header(default=None, alias="x-api-secret")):
        require_secret(request, secret, x_api_secret)
        return {"ok": False, "reason": "commands_disabled"}

    @app.get("/control/api/status")
    def control_status(request: Request):
        require_control(request)
        return JSONResponse(as_plain(boss.snapshot()), headers=no_store)

    @app.get("/control/api/logs")
    def control_logs(request: Request, service: str = Query(default="api")):
        require_control(request)
        if service not in {"api", "discord", "tunnel"}:
            service = "api"
        return JSONResponse({"service": service, "lines": boss.lines(service)}, headers=no_store)

    @app.post("/control/api/login")
    async def control_login(request: Request):
        body: dict[str, Any] = {}
        try:
            parsed = await request.json()
            if isinstance(parsed, dict):
                body = parsed
        except Exception:
            body = {}
        password = str(body.get("password") or "")
        if not boss.check_login(password):
            raise HTTPException(status_code=401, detail="bad password")
        response = JSONResponse({"ok": True})
        response.set_cookie(COOKIE, boss.session_token(), httponly=True, samesite="lax")
        return response

    @app.post("/control/api/logout")
    def control_logout():
        response = JSONResponse({"ok": True})
        response.delete_cookie(COOKIE)
        return response

    @app.post("/control/api/services/{service}/{op}")
    def control_service(service: str, op: str, request: Request):
        require_control(request)
        if service not in {"api", "discord", "tunnel"} or op not in {"start", "stop", "restart"}:
            raise HTTPException(status_code=404, detail="unknown")
        result = boss.action(service, op)
        return {"ok": True, "result": result, **boss.snapshot()}

    @app.post("/control/api/all/{op}")
    def control_all(op: str, request: Request):
        require_control(request)
        if op == "start":
            boss.start_all()
        elif op == "stop":
            boss.stop_all()
        elif op == "restart":
            boss.restart_all()
        else:
            raise HTTPException(status_code=404, detail="unknown")
        return {"ok": True, **boss.snapshot()}

    @app.post("/control/api/autostart")
    async def control_autostart(request: Request):
        require_control(request)
        body: dict[str, Any] = {}
        try:
            parsed = await request.json()
            if isinstance(parsed, dict):
                body = parsed
        except Exception:
            body = {}
        enabled = bool(body.get("enabled"))
        boss.set_autostart(enabled)
        return {"ok": True, "autostart": boss.autostart_enabled()}

    return app


create_api = create_app
