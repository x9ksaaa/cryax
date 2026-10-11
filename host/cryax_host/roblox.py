from __future__ import annotations

from typing import Any

import httpx

USERS_URL = "https://users.roblox.com/v1/users/{user_id}"
USERNAMES_URL = "https://users.roblox.com/v1/usernames/users"


class RobloxLookupError(ValueError):
    pass


def resolve_roblox_user(query: str) -> dict[str, Any]:
    q = str(query or "").strip()
    if not q:
        raise RobloxLookupError("Enter a Roblox username or id.")
    headers = {"Accept": "application/json", "User-Agent": "CryaxHost/1.0"}
    try:
        with httpx.Client(timeout=8.0, headers=headers) as client:
            if q.isdigit():
                response = client.get(USERS_URL.format(user_id=int(q)))
                if response.status_code == 404:
                    raise RobloxLookupError(f"No Roblox user with id `{int(q)}`.")
                response.raise_for_status()
                data = response.json()
                user_id = int(data["id"])
                name = str(data.get("name") or user_id)
                return {
                    "id": user_id,
                    "name": name,
                    "display_name": str(data.get("displayName") or name),
                }
            response = client.post(
                USERNAMES_URL,
                json={"usernames": [q], "excludeBannedUsers": False},
            )
            response.raise_for_status()
            users = (response.json() or {}).get("data") or []
            if not users:
                raise RobloxLookupError(f"No Roblox user named `{q}`.")
            user = users[0]
            user_id = int(user["id"])
            name = str(user.get("name") or q)
            return {
                "id": user_id,
                "name": name,
                "display_name": str(user.get("displayName") or name),
            }
    except RobloxLookupError:
        raise
    except httpx.HTTPError as exc:
        raise RobloxLookupError("Could not reach Roblox to look up that user.") from exc
