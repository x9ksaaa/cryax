from __future__ import annotations

import asyncio
import traceback
from typing import Any

import discord
from discord import app_commands
from discord.ext import commands

from .config import Config, paste_loadstring
from .nametag_ui import (
    can_use_bot,
    handle_nametag_upload,
    is_owner,
    is_root_owner,
    is_staff_member,
    send_management,
)
from .store import Store, normalize_discord_id


NOT_WHITELISTED = "You are not whitelisted to use this bot. An owner can add you with `/botwhitelist add`."
OWNER_ONLY = "Owner only."
STAFF_ONLY = "Staff only."


def _format_discord_ids(rows: list[dict[str, Any]], extra: list[str] | None = None) -> str:
    lines = list(extra or [])
    seen = {line.split("`")[1] for line in lines if "`" in line}
    for row in rows:
        uid = str(row.get("discord_id") or "")
        if not uid or uid in seen:
            continue
        seen.add(uid)
        lines.append(f"<@{uid}> `{uid}`")
    return "\n".join(lines) if lines else "Nobody yet."


async def _resolve_user(bot: commands.Bot, raw: str, mentions: list[Any] | None = None) -> discord.User | None:
    if mentions:
        return mentions[0]
    uid = normalize_discord_id(raw)
    if not uid:
        return None
    user = bot.get_user(int(uid))
    if user is not None:
        return user
    try:
        return await bot.fetch_user(int(uid))
    except (discord.HTTPException, ValueError):
        return None


async def _slash_reply(interaction: discord.Interaction, message: str) -> None:
    try:
        if interaction.response.is_done():
            await interaction.followup.send(message, ephemeral=True)
        else:
            await interaction.response.send_message(message, ephemeral=True)
    except discord.HTTPException:
        return


async def _slash_defer(interaction: discord.Interaction) -> None:
    if not interaction.response.is_done():
        await interaction.response.defer(ephemeral=True)


class NametagBot(commands.Bot):
    def __init__(self, cfg: Config, store: Store):
        intents = discord.Intents.default()
        intents.message_content = True
        super().__init__(command_prefix=cfg.command_prefix, intents=intents)
        self.cfg = cfg
        self.store = store
        self.pending_uploads: dict[int, dict[str, Any]] = {}

    async def setup_hook(self) -> None:
        # Discord's command API sometimes returns 500 Internal Server Error on
        # bulk slash sync. Keep the bot online even if one attempt fails.
        for attempt in range(1, 4):
            try:
                if self.cfg.discord_guild_id:
                    guild = discord.Object(id=int(self.cfg.discord_guild_id))
                    self.tree.copy_global_to(guild=guild)
                    synced = await self.tree.sync(guild=guild)
                else:
                    synced = await self.tree.sync()
                print(f"[cryax-host] Synced {len(synced)} Discord slash command(s)", flush=True)
                return
            except discord.HTTPException as exc:
                print(f"[cryax-host] Discord command sync failed ({attempt}/3): {exc}", flush=True)
                await asyncio.sleep(attempt * 2)
        print("[cryax-host] Discord slash sync skipped; prefix commands still work.", flush=True)

    async def on_ready(self) -> None:
        print(f"[cryax-host] Discord connected as {self.user}")

    async def on_message(self, message: discord.Message) -> None:
        if message.author.bot:
            await super().on_message(message)
            return
        if await handle_nametag_upload(self, message):
            return
        await super().on_message(message)


def create_bot(cfg: Config, store: Store, api: Any | None = None) -> NametagBot:
    bot = NametagBot(cfg, store)

    @bot.tree.error
    async def on_app_command_error(interaction: discord.Interaction, error: app_commands.AppCommandError) -> None:
        print(f"[cryax-host] Slash command error: {error}", flush=True)
        traceback.print_exception(type(error), error, error.__traceback__)
        root = getattr(error, "original", error)
        await _slash_reply(interaction, f"Command failed: {root}")

    @bot.check
    async def prefix_allowed(ctx: commands.Context) -> bool:
        if ctx.author.bot:
            return False
        if can_use_bot(cfg, ctx.author, store):
            return True
        raise commands.CheckFailure("not_whitelisted")

    @bot.tree.interaction_check
    async def slash_allowed(interaction: discord.Interaction) -> bool:
        if can_use_bot(cfg, interaction.user, store):
            return True
        await _slash_reply(interaction, NOT_WHITELISTED)
        return False

    @bot.event
    async def on_command_error(ctx: commands.Context, error: commands.CommandError) -> None:
        if isinstance(error, commands.CheckFailure):
            await ctx.reply(NOT_WHITELISTED)
            return
        if isinstance(error, commands.CommandNotFound):
            return
        print(f"[cryax-host] Command error: {error}", flush=True)

    @bot.command(name="nametagpanel", aliases=["nametag"])
    async def nametagpanel(ctx: commands.Context) -> None:
        await send_management(ctx, bot, store, cfg)

    @bot.command(name="loadstring")
    async def loadstring_prefix(ctx: commands.Context) -> None:
        line = paste_loadstring(cfg)
        await ctx.reply(
            "Official Cryax loader. Paste this in your executor.\n"
            f"```lua\n{line}\n```\n"
            "If HttpGet fails, run host\\worker\\deploy.ps1 then try again."
        )

    @bot.tree.command(name="loadstring", description="Get the Cryax executor loadstring")
    async def loadstring_slash(interaction: discord.Interaction) -> None:
        line = paste_loadstring(cfg)
        await interaction.response.send_message(
            "Official Cryax loader. Paste this in your executor.\n"
            f"```lua\n{line}\n```\n"
            "If HttpGet fails, run host\\worker\\deploy.ps1 then try again.",
            ephemeral=True,
        )

    @bot.command(name="link")
    async def link_prefix(ctx: commands.Context, roblox_id: int, username: str = "") -> None:
        tag = store.link(str(ctx.author.id), roblox_id, username)
        await ctx.reply(f"Linked to Roblox `{tag['roblox_id']}`. Use `.nametagpanel` next.")

    @bot.hybrid_command(name="unlink", description="Unlink your Discord from Roblox")
    async def unlink(ctx: commands.Context) -> None:
        store.unlink(str(ctx.author.id))
        await ctx.reply("Unlinked.")

    @bot.tree.command(name="link", description="Link your Discord account to a Roblox user id")
    async def link_slash(interaction: discord.Interaction, roblox_id: int, username: str = "") -> None:
        tag = store.link(str(interaction.user.id), roblox_id, username)
        await interaction.response.send_message(
            f"Linked to Roblox `{tag['roblox_id']}`. Open `/nametag` or `.nametagpanel`.",
            ephemeral=True,
        )

    @bot.tree.command(name="nametag", description="Open nametag management")
    async def nametag_slash(interaction: discord.Interaction) -> None:
        try:
            await send_management(interaction, bot, store, cfg, ephemeral=True)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to open nametag panel: {exc}")

    @bot.tree.command(name="nametagpanel", description="Open nametag management")
    async def nametagpanel_slash(interaction: discord.Interaction) -> None:
        try:
            await send_management(interaction, bot, store, cfg, ephemeral=True)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to open nametag panel: {exc}")

    staff = app_commands.Group(name="staff", description="Nametag host staff tools")

    @staff.command(name="whitelist", description="Add or remove a Roblox id from the whitelist")
    @app_commands.describe(action="add or remove", roblox_id="Roblox user id")
    async def staff_whitelist(interaction: discord.Interaction, action: str, roblox_id: int) -> None:
        if not is_staff_member(cfg, interaction.user, store):
            await interaction.response.send_message(STAFF_ONLY, ephemeral=True)
            return
        action = action.lower().strip()
        if action == "add":
            store.add_whitelist(roblox_id)
            await interaction.response.send_message(f"Whitelisted `{roblox_id}`.", ephemeral=True)
        elif action == "remove":
            store.remove_whitelist(roblox_id)
            await interaction.response.send_message(f"Removed `{roblox_id}`.", ephemeral=True)
        else:
            await interaction.response.send_message("Use action `add` or `remove`.", ephemeral=True)

    @staff.command(name="key", description="Create or revoke a script key")
    async def staff_key(interaction: discord.Interaction, action: str, value: str = "") -> None:
        if not is_staff_member(cfg, interaction.user, store):
            await interaction.response.send_message(STAFF_ONLY, ephemeral=True)
            return
        action = action.lower().strip()
        if action == "create":
            key = store.create_key(value)
            await interaction.response.send_message(f"Key `{key}` created.", ephemeral=True)
        elif action == "revoke":
            ok = store.revoke_key(value)
            await interaction.response.send_message("Revoked." if ok else "Unknown key.", ephemeral=True)
        else:
            await interaction.response.send_message("Use action `create` or `revoke`.", ephemeral=True)

    @staff.command(name="flag", description="Grant or revoke in-game Staff panel access")
    async def staff_flag(interaction: discord.Interaction, roblox_id: int, staff: bool) -> None:
        if not is_staff_member(cfg, interaction.user, store):
            await interaction.response.send_message(STAFF_ONLY, ephemeral=True)
            return
        await _slash_defer(interaction)
        try:
            tag = await asyncio.to_thread(store.set_staff, roblox_id, staff)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to update staff: {exc}")
            return
        await _slash_reply(
            interaction,
            f"Roblox `{tag['roblox_id']}` staff={bool(tag.get('staff'))} (in-game Staff panel).",
        )

    @staff.command(name="panel", description="Grant or revoke the in-game Staff panel")
    @app_commands.describe(roblox_id="Roblox user id", granted="True opens the script Staff button")
    async def staff_panel(interaction: discord.Interaction, roblox_id: int, granted: bool) -> None:
        if not is_staff_member(cfg, interaction.user, store):
            await interaction.response.send_message(STAFF_ONLY, ephemeral=True)
            return
        await _slash_defer(interaction)
        try:
            tag = await asyncio.to_thread(store.set_staff, roblox_id, granted)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to update staff: {exc}")
            return
        if bool(tag.get("staff")):
            await _slash_reply(
                interaction,
                f"Roblox `{tag['roblox_id']}` can use the in-game Staff panel. Stored on the host.",
            )
        else:
            await _slash_reply(
                interaction,
                f"Roblox `{tag['roblox_id']}` no longer has the in-game Staff panel.",
            )

    @staff.command(name="list", description="List Roblox ids with in-game Staff panel access")
    async def staff_list(interaction: discord.Interaction) -> None:
        if not is_staff_member(cfg, interaction.user, store):
            await interaction.response.send_message(STAFF_ONLY, ephemeral=True)
            return
        await _slash_defer(interaction)
        try:
            tags = await asyncio.to_thread(store.staff_tags)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to list staff: {exc}")
            return
        if not tags:
            await _slash_reply(interaction, "Nobody has Staff panel access.")
            return
        lines = [
            f"`{tag.get('roblox_id')}` {tag.get('roblox_username') or '—'} — {tag.get('display_name') or '—'}"
            for tag in tags[:25]
        ]
        extra = "" if len(tags) <= 25 else f"\n…and {len(tags) - 25} more"
        await _slash_reply(interaction, "\n".join(lines) + extra)

    @staff.command(name="blacklist", description="Block or unblock a Roblox id")
    async def staff_blacklist(interaction: discord.Interaction, roblox_id: int, blocked: bool) -> None:
        if not is_staff_member(cfg, interaction.user, store):
            await interaction.response.send_message(STAFF_ONLY, ephemeral=True)
            return
        store.set_blacklist(roblox_id, blocked)
        await interaction.response.send_message(
            f"Roblox `{roblox_id}` blacklist={blocked}.",
            ephemeral=True,
        )

    bot.tree.add_command(staff)

    @bot.command(name="staffpanel")
    async def staffpanel_prefix(ctx: commands.Context, target: str, granted: str = "on") -> None:
        if not is_staff_member(cfg, ctx.author, store):
            await ctx.reply(STAFF_ONLY)
            return
        if target.lower() in {"list", "ls"}:
            try:
                tags = await asyncio.to_thread(store.staff_tags)
            except Exception as exc:
                await ctx.reply(f"Failed to list staff: {exc}")
                return
            if not tags:
                await ctx.reply("Nobody has Staff panel access.")
                return
            lines = [
                f"`{tag.get('roblox_id')}` {tag.get('roblox_username') or '—'}"
                for tag in tags[:25]
            ]
            await ctx.reply("\n".join(lines))
            return
        try:
            roblox_id = int(target)
        except ValueError:
            await ctx.reply("Use a Roblox id, or `.staffpanel list`.")
            return
        token = granted.lower().strip()
        if token in {"0", "false", "no", "off", "revoke", "disable"}:
            on = False
        elif token in {"1", "true", "yes", "on", "grant", "enable"}:
            on = True
        else:
            await ctx.reply("Use `.staffpanel <roblox id> on|off` or `.staffpanel list`.")
            return
        try:
            tag = await asyncio.to_thread(store.set_staff, roblox_id, on)
        except Exception as exc:
            await ctx.reply(f"Failed to update staff: {exc}")
            return
        if tag.get("staff"):
            await ctx.reply(
                f"Roblox `{tag['roblox_id']}` can use the in-game Staff panel. Stored on the host."
            )
        else:
            await ctx.reply(f"Roblox `{tag['roblox_id']}` no longer has the in-game Staff panel.")

    verified = app_commands.Group(name="verified", description="Owner-only Roblox verified badge grants")

    @verified.command(name="grant", description="Give a Roblox id the verified nametag badge (U+E000)")
    async def verified_grant(interaction: discord.Interaction, roblox_id: int) -> None:
        if not is_owner(cfg, interaction.user, store):
            await interaction.response.send_message(OWNER_ONLY, ephemeral=True)
            return
        await _slash_defer(interaction)
        try:
            tag = await asyncio.to_thread(store.set_verified_badge, roblox_id, True)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to grant verified: {exc}")
            return
        await _slash_reply(
            interaction,
            f"Roblox `{tag['roblox_id']}` now has the verified badge (U+E000). Stored on the host.",
        )

    @verified.command(name="revoke", description="Remove the verified nametag badge from a Roblox id")
    async def verified_revoke(interaction: discord.Interaction, roblox_id: int) -> None:
        if not is_owner(cfg, interaction.user, store):
            await interaction.response.send_message(OWNER_ONLY, ephemeral=True)
            return
        await _slash_defer(interaction)
        try:
            tag = await asyncio.to_thread(store.set_verified_badge, roblox_id, False)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to revoke verified: {exc}")
            return
        await _slash_reply(
            interaction,
            f"Roblox `{tag['roblox_id']}` no longer has the verified badge.",
        )

    @verified.command(name="list", description="List Roblox ids with the verified nametag badge")
    async def verified_list(interaction: discord.Interaction) -> None:
        if not is_owner(cfg, interaction.user, store):
            await interaction.response.send_message(OWNER_ONLY, ephemeral=True)
            return
        await _slash_defer(interaction)
        try:
            tags = await asyncio.to_thread(store.verified_badge_tags)
        except Exception as exc:
            await _slash_reply(interaction, f"Failed to list verified: {exc}")
            return
        if not tags:
            await _slash_reply(interaction, "Nobody has the verified badge.")
            return
        lines = [
            f"`{tag.get('roblox_id')}` {tag.get('roblox_username') or '—'} — {tag.get('display_name') or '—'}"
            for tag in tags[:25]
        ]
        extra = "" if len(tags) <= 25 else f"\n…and {len(tags) - 25} more"
        await _slash_reply(interaction, "\n".join(lines) + extra)

    bot.tree.add_command(verified)

    @bot.command(name="verified")
    async def verified_prefix(ctx: commands.Context, target: str, granted: str = "on") -> None:
        if not is_owner(cfg, ctx.author, store):
            await ctx.reply(OWNER_ONLY)
            return
        if target.lower() in {"list", "ls"}:
            tags = store.verified_badge_tags()
            if not tags:
                await ctx.reply("Nobody has the verified badge.")
                return
            lines = [
                f"`{tag.get('roblox_id')}` {tag.get('roblox_username') or '—'}"
                for tag in tags[:25]
            ]
            await ctx.reply("\n".join(lines))
            return
        try:
            roblox_id = int(target)
        except ValueError:
            await ctx.reply("Use a Roblox id, or `.verified list`.")
            return
        token = granted.lower().strip()
        if token in {"0", "false", "no", "off", "revoke", "disable"}:
            on = False
        elif token in {"1", "true", "yes", "on", "grant", "enable"}:
            on = True
        else:
            await ctx.reply("Use `.verified <roblox id> on|off` or `.verified list`.")
            return
        try:
            tag = await asyncio.to_thread(store.set_verified_badge, roblox_id, on)
        except Exception as exc:
            await ctx.reply(f"Failed to update verified: {exc}")
            return
        if tag.get("verified_badge"):
            await ctx.reply(
                f"Roblox `{tag['roblox_id']}` verified badge on (U+E000). Stored on the host."
            )
        else:
            await ctx.reply(f"Roblox `{tag['roblox_id']}` verified badge off.")

    bot_wl = app_commands.Group(name="botwhitelist", description="Who can use this Discord bot")
    owner_wl = app_commands.Group(name="ownerwhitelist", description="Who has owner permissions on this Discord bot")

    def _root_owner_line() -> str | None:
        root = str(cfg.discord_owner_id or "").strip()
        if not root:
            return None
        return f"<@{root}> `{root}` (root)"

    async def _require_owner_interaction(interaction: discord.Interaction) -> bool:
        if is_owner(cfg, interaction.user, store):
            return True
        await interaction.response.send_message(OWNER_ONLY, ephemeral=True)
        return False

    async def _require_owner_ctx(ctx: commands.Context) -> bool:
        if is_owner(cfg, ctx.author, store):
            return True
        await ctx.reply(OWNER_ONLY)
        return False

    @bot_wl.command(name="add", description="Allow a Discord user to use this bot")
    async def bot_wl_add(interaction: discord.Interaction, user: discord.User) -> None:
        if not await _require_owner_interaction(interaction):
            return
        store.add_bot_whitelist(str(user.id), str(interaction.user.id))
        await interaction.response.send_message(
            f"Whitelisted {user.mention} `{user.id}` to use the bot.",
            ephemeral=True,
        )

    @bot_wl.command(name="remove", description="Remove a Discord user from the bot whitelist")
    async def bot_wl_remove(interaction: discord.Interaction, user: discord.User) -> None:
        if not await _require_owner_interaction(interaction):
            return
        if is_owner(cfg, user, store) or is_staff_member(cfg, user, store):
            await interaction.response.send_message(
                "Owners and staff already have access. Remove them from owner whitelist or STAFF_DISCORD_IDS instead.",
                ephemeral=True,
            )
            return
        ok = store.remove_bot_whitelist(str(user.id))
        await interaction.response.send_message(
            f"Removed {user.mention} from the bot whitelist." if ok else f"{user.mention} was not on the bot whitelist.",
            ephemeral=True,
        )

    @bot_wl.command(name="list", description="List Discord users allowed to use this bot")
    async def bot_wl_list(interaction: discord.Interaction) -> None:
        if not await _require_owner_interaction(interaction):
            return
        extras = []
        root = _root_owner_line()
        if root:
            extras.append(root)
        for row in store.list_bot_owners():
            uid = str(row.get("discord_id") or "")
            if uid:
                extras.append(f"<@{uid}> `{uid}` (owner)")
        for staff_id in sorted(cfg.staff_discord_ids):
            extras.append(f"<@{staff_id}> `{staff_id}` (staff)")
        body = _format_discord_ids(store.list_bot_whitelist(), extras)
        await interaction.response.send_message(
            "**Can use the bot**\nOwners and staff always can. Extra users:\n" + body,
            ephemeral=True,
        )

    @owner_wl.command(name="add", description="Give a Discord user owner permissions on this bot")
    async def owner_wl_add(interaction: discord.Interaction, user: discord.User) -> None:
        if not await _require_owner_interaction(interaction):
            return
        if is_root_owner(cfg, user):
            await interaction.response.send_message("That user is already the root owner from DISCORD_OWNER_ID.", ephemeral=True)
            return
        store.add_bot_owner(str(user.id), str(interaction.user.id))
        store.add_bot_whitelist(str(user.id), str(interaction.user.id))
        await interaction.response.send_message(
            f"{user.mention} `{user.id}` now has owner permissions on the bot.",
            ephemeral=True,
        )

    @owner_wl.command(name="remove", description="Remove owner permissions from a Discord user")
    async def owner_wl_remove(interaction: discord.Interaction, user: discord.User) -> None:
        if not await _require_owner_interaction(interaction):
            return
        if is_root_owner(cfg, user):
            await interaction.response.send_message("The .env DISCORD_OWNER_ID cannot be removed.", ephemeral=True)
            return
        ok = store.remove_bot_owner(str(user.id))
        await interaction.response.send_message(
            f"Removed owner permissions from {user.mention}." if ok else f"{user.mention} was not on the owner whitelist.",
            ephemeral=True,
        )

    @owner_wl.command(name="list", description="List Discord users with owner permissions")
    async def owner_wl_list(interaction: discord.Interaction) -> None:
        if not await _require_owner_interaction(interaction):
            return
        extras = []
        root = _root_owner_line()
        if root:
            extras.append(root)
        body = _format_discord_ids(store.list_bot_owners(), extras)
        await interaction.response.send_message("**Bot owners**\n" + body, ephemeral=True)

    bot.tree.add_command(bot_wl)
    bot.tree.add_command(owner_wl)

    @bot.command(name="botwhitelist", aliases=["botwl"])
    async def botwhitelist_prefix(ctx: commands.Context, action: str = "list", target: str = "") -> None:
        if not await _require_owner_ctx(ctx):
            return
        token = action.lower().strip()
        if token in {"list", "ls", ""}:
            extras = []
            root = _root_owner_line()
            if root:
                extras.append(root)
            for row in store.list_bot_owners():
                uid = str(row.get("discord_id") or "")
                if uid:
                    extras.append(f"<@{uid}> `{uid}` (owner)")
            for staff_id in sorted(cfg.staff_discord_ids):
                extras.append(f"<@{staff_id}> `{staff_id}` (staff)")
            body = _format_discord_ids(store.list_bot_whitelist(), extras)
            await ctx.reply("**Can use the bot**\n" + body)
            return
        user = await _resolve_user(bot, target or action, list(ctx.message.mentions))
        if user is None:
            await ctx.reply("Use `.botwhitelist add @user`, `.botwhitelist remove @user`, or `.botwhitelist list`.")
            return
        if token in {"add", "grant"}:
            store.add_bot_whitelist(str(user.id), str(ctx.author.id))
            await ctx.reply(f"Whitelisted {user.mention} `{user.id}` to use the bot.")
            return
        if token in {"remove", "rm", "revoke"}:
            if is_owner(cfg, user, store) or is_staff_member(cfg, user, store):
                await ctx.reply("Owners and staff already have access.")
                return
            ok = store.remove_bot_whitelist(str(user.id))
            await ctx.reply(
                f"Removed {user.mention} from the bot whitelist." if ok else f"{user.mention} was not on the bot whitelist."
            )
            return
        await ctx.reply("Use `.botwhitelist add @user`, `.botwhitelist remove @user`, or `.botwhitelist list`.")

    @bot.command(name="ownerwhitelist", aliases=["ownerwl"])
    async def ownerwhitelist_prefix(ctx: commands.Context, action: str = "list", target: str = "") -> None:
        if not await _require_owner_ctx(ctx):
            return
        token = action.lower().strip()
        if token in {"list", "ls", ""}:
            extras = []
            root = _root_owner_line()
            if root:
                extras.append(root)
            await ctx.reply("**Bot owners**\n" + _format_discord_ids(store.list_bot_owners(), extras))
            return
        user = await _resolve_user(bot, target or action, list(ctx.message.mentions))
        if user is None:
            await ctx.reply("Use `.ownerwhitelist add @user`, `.ownerwhitelist remove @user`, or `.ownerwhitelist list`.")
            return
        if token in {"add", "grant"}:
            if is_root_owner(cfg, user):
                await ctx.reply("That user is already the root owner from DISCORD_OWNER_ID.")
                return
            store.add_bot_owner(str(user.id), str(ctx.author.id))
            store.add_bot_whitelist(str(user.id), str(ctx.author.id))
            await ctx.reply(f"{user.mention} `{user.id}` now has owner permissions on the bot.")
            return
        if token in {"remove", "rm", "revoke"}:
            if is_root_owner(cfg, user):
                await ctx.reply("The .env DISCORD_OWNER_ID cannot be removed.")
                return
            ok = store.remove_bot_owner(str(user.id))
            await ctx.reply(
                f"Removed owner permissions from {user.mention}." if ok else f"{user.mention} was not on the owner whitelist."
            )
            return
        await ctx.reply("Use `.ownerwhitelist add @user`, `.ownerwhitelist remove @user`, or `.ownerwhitelist list`.")

    return bot
