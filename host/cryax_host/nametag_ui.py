from __future__ import annotations

import asyncio
import io
from typing import Any

import discord

from .config import FONTS, SHAPES, Config
from .images import ImageError, process_upload, render_preview
from .roblox import RobloxLookupError, resolve_roblox_user
from .store import Store, normalize_glitch, normalize_hex, normalize_shape

EMBED_COLOR = 0x1E1F22
PANEL_TIMEOUT = 600


def _user_id(user: discord.abc.User) -> str:
    return str(getattr(user, "id", "") or "")


def is_root_owner(cfg: Config, user: discord.abc.User) -> bool:
    owner = str(cfg.discord_owner_id or "").strip()
    return bool(owner) and _user_id(user) == owner


def is_owner(cfg: Config, user: discord.abc.User, store: Store | None = None) -> bool:
    if is_root_owner(cfg, user):
        return True
    if store is not None:
        return store.is_bot_owner(_user_id(user))
    return False


def is_staff_member(cfg: Config, user: discord.abc.User, store: Store | None = None) -> bool:
    if is_owner(cfg, user, store):
        return True
    return _user_id(user) in cfg.staff_discord_ids


def can_use_bot(cfg: Config, user: discord.abc.User, store: Store) -> bool:
    if is_staff_member(cfg, user, store):
        return True
    return store.is_bot_whitelisted(_user_id(user))


def can_edit_tag(cfg: Config, store: Store, user: discord.abc.User, roblox_id: int) -> bool:
    if is_staff_member(cfg, user, store):
        return True
    linked = store.roblox_for_discord(str(user.id))
    return linked == int(roblox_id)


def management_embed() -> discord.Embed:
    embed = discord.Embed(title="Nametag Management", color=EMBED_COLOR)
    embed.description = (
        "Manage player nametags. **Save** writes the style the Roblox client polls "
        "(`GET /nametags`). In-game tags are the message-15 pill: Discord display name, "
        "@username, icon, colors, shape, and glitch.\n\n"
        "**Create** — New player configuration\n"
        "**View** — Check existing settings\n"
        "**Edit** — Modify colors, fonts, images\n"
        "**Delete** — Remove configuration\n"
        "**Transfer** — Move tag to different user\n"
        "**Search** — Find tags by text\n\n"
        "In-game **Staff panel** access is a host grant (`/staff panel` or Grant Staff). "
        "The Roblox verified badge (U+E000) is owner-only. Use `/verified grant` "
        "or the Grant Verified button — grants are stored on this host."
    )
    return embed


def _image_label(name: str, url: str, pending: bool, removed: bool) -> str:
    if removed:
        return "*(removed)*"
    if pending:
        return f"{name or 'staged image'} *(not saved)*"
    if name:
        return name
    if url:
        return url.rsplit("/", 1)[-1]
    return "—"


def customizing_embed(draft: dict[str, Any], username: str) -> discord.Embed:
    embed = discord.Embed(title=f"Customizing: {username}", color=EMBED_COLOR)
    embed.description = (
        "Modify the fields below. **Remove** hides an image. **Save** updates the in-game "
        "message-15 tag through the Cryax host (`GET /nametags`)."
    )
    embed.add_field(name="Display Name", value=str(draft.get("display_name") or "—")[:64] or "—", inline=True)
    embed.add_field(name="Text Color", value=str(draft.get("text_color") or "—"), inline=True)
    embed.add_field(name="Outline Color", value=str(draft.get("outline_color") or "—"), inline=True)
    embed.add_field(name="BG Color", value=str(draft.get("background_color") or "—"), inline=True)
    embed.add_field(name="Font", value=str(draft.get("font") or "GothamBlack"), inline=True)
    embed.add_field(name="Shape", value=str(draft.get("shape") or "Pill"), inline=True)
    embed.add_field(name="Glitch Effect", value="Enabled" if draft.get("glitch") else "Disabled", inline=True)
    embed.add_field(name="Staff panel", value="Yes" if draft.get("staff") else "No", inline=True)
    embed.add_field(
        name="Verified badge",
        value="Yes (U+E000)" if draft.get("verified_badge") else "No",
        inline=True,
    )
    embed.add_field(
        name="BG Image",
        value=_image_label(str(draft.get("bg_name") or ""), str(draft.get("bg_image_url") or ""), bool(draft.get("pending_bg")), bool(draft.get("remove_bg"))),
        inline=False,
    )
    embed.add_field(
        name="Icon Image",
        value=_image_label(str(draft.get("icon_name") or ""), str(draft.get("icon_image_url") or ""), bool(draft.get("pending_icon")), bool(draft.get("remove_icon"))),
        inline=False,
    )
    embed.set_image(url="attachment://nametag.png")
    return embed


def draft_from_tag(tag: dict[str, Any]) -> dict[str, Any]:
    return {
        "display_name": str(tag.get("display_name") or ""),
        "roblox_username": str(tag.get("roblox_username") or ""),
        "text_color": str(tag.get("text_color") or "#F4F6FF"),
        "outline_color": str(tag.get("outline_color") or "#FFFFFF"),
        "background_color": str(tag.get("background_color") or "#0C0E14"),
        "font": str(tag.get("font") or "GothamBlack"),
        "shape": str(tag.get("shape") or "Pill"),
        "glitch": bool(tag.get("glitch")),
        "staff": bool(tag.get("staff")),
        "verified_badge": bool(tag.get("verified_badge")),
        "icon_name": str(tag.get("icon_name") or ""),
        "bg_name": str(tag.get("bg_name") or ""),
        "icon_image_url": str(tag.get("icon_image_url") or ""),
        "bg_image_url": str(tag.get("bg_image_url") or ""),
        "pending_icon": None,
        "pending_bg": None,
        "remove_icon": False,
        "remove_bg": False,
        "icon_png": None,
        "bg_png": None,
    }


def preview_file(store: Store, roblox_id: int, draft: dict[str, Any]) -> discord.File:
    icon_png = draft.get("icon_png")
    bg_png = draft.get("bg_png")
    if not draft.get("remove_icon"):
        if icon_png is None and not draft.get("pending_icon"):
            icon_png = store.read_static(roblox_id, "icon")
        elif draft.get("pending_icon") is not None:
            icon_png = draft["pending_icon"].static_png
    else:
        icon_png = None
    if not draft.get("remove_bg"):
        if bg_png is None and not draft.get("pending_bg"):
            bg_png = store.read_static(roblox_id, "bg")
        elif draft.get("pending_bg") is not None:
            bg_png = draft["pending_bg"].static_png
    else:
        bg_png = None
    png = render_preview(
        display_name=str(draft.get("display_name") or draft.get("roblox_username") or roblox_id),
        username=str(draft.get("roblox_username") or ""),
        outline=str(draft.get("outline_color") or "#FFFFFF"),
        text_color=str(draft.get("text_color") or "#F4F6FF"),
        background=str(draft.get("background_color") or "#0C0E14"),
        icon_png=icon_png,
        bg_png=bg_png,
        staff=bool(draft.get("staff")),
        shape=str(draft.get("shape") or "Pill"),
        glitch=bool(draft.get("glitch")),
        verified_badge=bool(draft.get("verified_badge")),
    )
    return discord.File(io.BytesIO(png), filename="nametag.png")


async def resolve_player(store: Store, query: str) -> dict[str, Any]:
    local = store.find_exact(query)
    try:
        remote = await asyncio.to_thread(resolve_roblox_user, query)
        return remote
    except RobloxLookupError:
        if local:
            return {
                "id": int(local["roblox_id"]),
                "name": str(local.get("roblox_username") or local["roblox_id"]),
                "display_name": str(local.get("display_name") or local.get("roblox_username") or local["roblox_id"]),
            }
        raise


async def edit_panel(
    interaction: discord.Interaction,
    *,
    embed: discord.Embed,
    view: discord.ui.View,
    file: discord.File | None = None,
) -> None:
    kwargs: dict[str, Any] = {"embed": embed, "view": view}
    kwargs["attachments"] = [file] if file is not None else []
    if not interaction.response.is_done():
        await interaction.response.edit_message(**kwargs)
    else:
        await interaction.edit_original_response(**kwargs)


async def ephemeral_error(interaction: discord.Interaction, message: str) -> None:
    if not interaction.response.is_done():
        await interaction.response.send_message(message, ephemeral=True)
    else:
        await interaction.followup.send(message, ephemeral=True)


async def view_allows(interaction: discord.Interaction, cfg: Config, store: Store) -> bool:
    if can_use_bot(cfg, interaction.user, store):
        return True
    await ephemeral_error(interaction, "You are not whitelisted to use this bot.")
    return False


async def show_management(interaction: discord.Interaction, bot: Any, store: Store, cfg: Config) -> None:
    await edit_panel(interaction, embed=management_embed(), view=ManagementView(bot, store, cfg), file=None)


async def show_customizing(
    interaction: discord.Interaction,
    bot: Any,
    store: Store,
    cfg: Config,
    roblox_id: int,
    username: str,
    draft: dict[str, Any],
    *,
    readonly: bool = False,
) -> None:
    view = CustomizingView(
        bot, store, cfg, roblox_id, username, draft, readonly=readonly, actor=interaction.user
    )
    await edit_panel(
        interaction,
        embed=customizing_embed(draft, username),
        view=view,
        file=preview_file(store, roblox_id, draft),
    )
    view.panel_message = interaction.message


class UsernameModal(discord.ui.Modal):
    username = discord.ui.TextInput(label="Roblox Username", placeholder="Enter Roblox username", required=True, max_length=32)

    def __init__(self, bot: Any, store: Store, cfg: Config, mode: str):
        titles = {
            "create": "Create Nametag",
            "view": "View Nametag",
            "edit": "Edit Nametag",
            "delete": "Delete Nametag",
        }
        super().__init__(title=titles[mode])
        self.bot = bot
        self.store = store
        self.cfg = cfg
        self.mode = mode

    async def on_submit(self, interaction: discord.Interaction) -> None:
        if not await view_allows(interaction, self.cfg, self.store):
            return
        query = str(self.username.value or "").strip()
        try:
            player = await resolve_player(self.store, query)
        except RobloxLookupError as exc:
            await ephemeral_error(interaction, str(exc))
            return
        roblox_id = int(player["id"])
        username = str(player["name"])
        if self.mode == "create":
            linked = self.store.roblox_for_discord(str(interaction.user.id))
            if not is_staff_member(self.cfg, interaction.user, self.store):
                if linked is None:
                    await ephemeral_error(interaction, "Link your account first with `.link <roblox id>` or `/link`.")
                    return
                if int(linked) != roblox_id:
                    await ephemeral_error(interaction, "You can only create a nametag for your linked Roblox account.")
                    return
            existing = self.store.get_tag(roblox_id)
            if existing is None:
                existing = self.store.upsert_tag(
                    roblox_id,
                    roblox_username=username,
                    display_name=str(player.get("display_name") or username)[:32],
                )
            elif not existing.get("roblox_username"):
                existing = self.store.upsert_tag(roblox_id, roblox_username=username)
            await show_customizing(interaction, self.bot, self.store, self.cfg, roblox_id, username, draft_from_tag(existing))
            return
        tag = self.store.get_tag(roblox_id)
        if tag is None:
            await ephemeral_error(interaction, f"No nametag for `{username}`. Use **Create** first.")
            return
        username = str(tag.get("roblox_username") or username)
        if self.mode == "view":
            await show_customizing(interaction, self.bot, self.store, self.cfg, roblox_id, username, draft_from_tag(tag), readonly=True)
            return
        if self.mode == "edit":
            if not can_edit_tag(self.cfg, self.store, interaction.user, roblox_id):
                await ephemeral_error(interaction, "You can only edit your own nametag.")
                return
            await show_customizing(interaction, self.bot, self.store, self.cfg, roblox_id, username, draft_from_tag(tag))
            return
        if not can_edit_tag(self.cfg, self.store, interaction.user, roblox_id):
            await ephemeral_error(interaction, "You can only delete your own nametag.")
            return
        self.store.delete_tag(roblox_id)
        embed = management_embed()
        embed.set_footer(text=f"Deleted nametag for {username} ({roblox_id}).")
        await edit_panel(interaction, embed=embed, view=ManagementView(self.bot, self.store, self.cfg))


class TransferModal(discord.ui.Modal, title="Transfer Nametag"):
    source = discord.ui.TextInput(label="Source Roblox Username", required=True, max_length=32)
    target = discord.ui.TextInput(label="Target Roblox Username", required=True, max_length=32)

    def __init__(self, bot: Any, store: Store, cfg: Config):
        super().__init__()
        self.bot = bot
        self.store = store
        self.cfg = cfg

    async def on_submit(self, interaction: discord.Interaction) -> None:
        if not await view_allows(interaction, self.cfg, self.store):
            return
        if not is_staff_member(self.cfg, interaction.user, self.store):
            await ephemeral_error(interaction, "Staff only.")
            return
        try:
            src = await resolve_player(self.store, str(self.source.value))
            dst = await resolve_player(self.store, str(self.target.value))
            tag = self.store.transfer_tag(int(src["id"]), int(dst["id"]))
        except (RobloxLookupError, ValueError) as exc:
            await ephemeral_error(interaction, str(exc))
            return
        username = str(tag.get("roblox_username") or dst["name"])
        self.store.upsert_tag(int(dst["id"]), roblox_username=str(dst["name"]))
        embed = management_embed()
        embed.set_footer(text=f"Moved nametag {src['name']} → {dst['name']}.")
        await edit_panel(interaction, embed=embed, view=ManagementView(self.bot, self.store, self.cfg))


class SearchModal(discord.ui.Modal, title="Search Nametags"):
    query = discord.ui.TextInput(
        label="Search text",
        placeholder="Username, display name, or Roblox ID",
        required=True,
        max_length=64,
    )

    def __init__(self, bot: Any, store: Store, cfg: Config):
        super().__init__()
        self.bot = bot
        self.store = store
        self.cfg = cfg

    async def on_submit(self, interaction: discord.Interaction) -> None:
        if not await view_allows(interaction, self.cfg, self.store):
            return
        hits = self.store.find_tags(str(self.query.value))
        embed = management_embed()
        if not hits:
            embed.set_footer(text=f"No nametags matched {self.query.value!s}.")
        else:
            lines = []
            for tag in hits[:15]:
                lines.append(
                    f"`{tag.get('roblox_id')}` {tag.get('roblox_username') or '—'} — {tag.get('display_name') or '—'}"
                )
            extra = "" if len(hits) <= 15 else f"\n…and {len(hits) - 15} more"
            embed.add_field(name=f"Search results ({len(hits)})", value="\n".join(lines) + extra, inline=False)
        await edit_panel(interaction, embed=embed, view=ManagementView(self.bot, self.store, self.cfg))


class TextColorModal(discord.ui.Modal, title="Text & Colors"):
    def __init__(self, owner: "CustomizingView"):
        super().__init__()
        self.owner = owner
        draft = owner.draft
        self.display_name = discord.ui.TextInput(label="Display Name", max_length=32, required=True, default=str(draft.get("display_name") or owner.username or "")[:32])
        self.text_color = discord.ui.TextInput(label="Text Color", max_length=7, required=True, default=str(draft.get("text_color") or "#F4F6FF"))
        self.outline_color = discord.ui.TextInput(label="Outline Color", max_length=7, required=True, default=str(draft.get("outline_color") or "#FFFFFF"))
        self.background_color = discord.ui.TextInput(label="BG Color", max_length=7, required=True, default=str(draft.get("background_color") or "#0C0E14"))
        self.font = discord.ui.TextInput(label="Font", max_length=24, required=True, default=str(draft.get("font") or "GothamBlack"))
        for item in (self.display_name, self.text_color, self.outline_color, self.background_color, self.font):
            self.add_item(item)

    async def on_submit(self, interaction: discord.Interaction) -> None:
        if not await view_allows(interaction, self.owner.cfg, self.owner.store):
            return
        draft = self.owner.draft
        draft["display_name"] = str(self.display_name.value).strip()[:32]
        draft["text_color"] = normalize_hex(str(self.text_color.value), "#F4F6FF")
        draft["outline_color"] = normalize_hex(str(self.outline_color.value), "#FFFFFF")
        draft["background_color"] = normalize_hex(str(self.background_color.value), "#0C0E14")
        wanted = str(self.font.value or "").strip()
        lookup = {item.lower(): item for item in FONTS}
        draft["font"] = lookup.get(wanted.lower(), draft.get("font") or "GothamBlack")
        await show_customizing(
            interaction,
            self.owner.bot,
            self.owner.store,
            self.owner.cfg,
            self.owner.roblox_id,
            self.owner.username,
            draft,
            readonly=self.owner.readonly,
        )


class ShapeSelect(discord.ui.Select):
    def __init__(self, owner: "CustomizingView"):
        self.owner = owner
        options = [
            discord.SelectOption(label=shape, value=shape, default=str(owner.draft.get("shape") or "Pill") == shape)
            for shape in SHAPES
        ]
        super().__init__(placeholder="Select Shape", min_values=1, max_values=1, options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        self.owner.draft["shape"] = normalize_shape(self.values[0])
        await show_customizing(
            interaction,
            self.owner.bot,
            self.owner.store,
            self.owner.cfg,
            self.owner.roblox_id,
            self.owner.username,
            self.owner.draft,
        )


class ShapeView(discord.ui.View):
    def __init__(self, owner: "CustomizingView"):
        super().__init__(timeout=PANEL_TIMEOUT)
        self.owner = owner
        self.add_item(ShapeSelect(owner))

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        return await view_allows(interaction, self.owner.cfg, self.owner.store)

    @discord.ui.button(label="Back", style=discord.ButtonStyle.secondary, row=1)
    async def back(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await show_customizing(
            interaction,
            self.owner.bot,
            self.owner.store,
            self.owner.cfg,
            self.owner.roblox_id,
            self.owner.username,
            self.owner.draft,
        )


class ImageActionView(discord.ui.View):
    def __init__(self, owner: "CustomizingView"):
        super().__init__(timeout=PANEL_TIMEOUT)
        self.owner = owner

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        return await view_allows(interaction, self.owner.cfg, self.owner.store)

    async def _arm(self, interaction: discord.Interaction, kind: str) -> None:
        self.owner.bot.pending_uploads[interaction.user.id] = {
            "kind": kind,
            "roblox_id": self.owner.roblox_id,
            "view": self.owner,
        }
        self.owner.panel_message = interaction.message
        await interaction.response.send_message(
            f"Send a PNG, JPG, or GIF in this channel for the **{kind}**. Click **Save** after it stages.",
            ephemeral=True,
        )

    @discord.ui.button(label="Upload Icon", style=discord.ButtonStyle.success, row=0)
    async def upload_icon(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await self._arm(interaction, "icon")

    @discord.ui.button(label="Upload Background", style=discord.ButtonStyle.success, row=0)
    async def upload_bg(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await self._arm(interaction, "bg")

    @discord.ui.button(label="Back", style=discord.ButtonStyle.secondary, row=1)
    async def back(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await show_customizing(
            interaction,
            self.owner.bot,
            self.owner.store,
            self.owner.cfg,
            self.owner.roblox_id,
            self.owner.username,
            self.owner.draft,
        )


class CustomizingView(discord.ui.View):
    def __init__(
        self,
        bot: Any,
        store: Store,
        cfg: Config,
        roblox_id: int,
        username: str,
        draft: dict[str, Any],
        *,
        readonly: bool = False,
        actor: discord.abc.User | None = None,
    ):
        super().__init__(timeout=PANEL_TIMEOUT)
        self.bot = bot
        self.store = store
        self.cfg = cfg
        self.roblox_id = int(roblox_id)
        self.username = username
        self.draft = draft
        self.readonly = readonly
        self.actor = actor
        self.panel_message = None
        if readonly:
            for child in list(self.children):
                if getattr(child, "label", None) != "Back":
                    self.remove_item(child)
            self._add_open_links()
            return
        glitch_on = bool(draft.get("glitch"))
        self.glitch_btn.label = "Disable Glitch" if glitch_on else "Enable Glitch"
        self.glitch_btn.style = discord.ButtonStyle.danger if glitch_on else discord.ButtonStyle.primary
        if actor is not None and is_staff_member(cfg, actor, store):
            staff_on = bool(draft.get("staff"))
            self.staff_btn.label = "Revoke Staff" if staff_on else "Grant Staff"
            self.staff_btn.style = discord.ButtonStyle.danger if staff_on else discord.ButtonStyle.success
        else:
            self.remove_item(self.staff_btn)
        if actor is not None and is_owner(cfg, actor, store):
            verified_on = bool(draft.get("verified_badge"))
            self.verified_btn.label = "Revoke Verified" if verified_on else "Grant Verified"
            self.verified_btn.style = discord.ButtonStyle.danger if verified_on else discord.ButtonStyle.success
        else:
            self.remove_item(self.verified_btn)
        self._add_open_links()

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        return await view_allows(interaction, self.cfg, self.store)

    def _add_open_links(self) -> None:
        bg_url = str(self.draft.get("bg_image_url") or "")
        icon_url = str(self.draft.get("icon_image_url") or "")
        if bg_url.startswith("http"):
            self.add_item(discord.ui.Button(style=discord.ButtonStyle.link, label="Open BG Image", url=bg_url, row=4))
        if icon_url.startswith("http"):
            self.add_item(discord.ui.Button(style=discord.ButtonStyle.link, label="Open Icon Image", url=icon_url, row=4))

    @discord.ui.button(label="Text & Colors", style=discord.ButtonStyle.primary, row=0)
    async def text_colors(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        await interaction.response.send_modal(TextColorModal(self))

    @discord.ui.button(label="Images", style=discord.ButtonStyle.primary, row=0)
    async def images(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        embed = customizing_embed(self.draft, self.username)
        embed.set_footer(text="Upload an icon or background, then Save.")
        await edit_panel(
            interaction,
            embed=embed,
            view=ImageActionView(self),
            file=preview_file(self.store, self.roblox_id, self.draft),
        )

    @discord.ui.button(label="Disable Glitch", style=discord.ButtonStyle.danger, row=1)
    async def glitch_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        self.draft["glitch"] = not bool(self.draft.get("glitch"))
        await show_customizing(interaction, self.bot, self.store, self.cfg, self.roblox_id, self.username, self.draft)

    @discord.ui.button(label="Grant Verified", style=discord.ButtonStyle.success, row=1)
    async def verified_btn(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        if not is_owner(self.cfg, interaction.user, self.store):
            await ephemeral_error(interaction, "Owner only. The verified badge is not a staff toggle.")
            return
        granted = not bool(self.draft.get("verified_badge"))
        tag = self.store.set_verified_badge(self.roblox_id, granted)
        self.draft["verified_badge"] = bool(tag.get("verified_badge"))
        await show_customizing(
            interaction, self.bot, self.store, self.cfg, self.roblox_id, self.username, self.draft
        )

    @discord.ui.button(label="Grant Staff", style=discord.ButtonStyle.success, row=0)
    async def staff_btn(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        if not is_staff_member(self.cfg, interaction.user, self.store):
            await ephemeral_error(interaction, "Staff only. Use `/staff panel` from Discord staff.")
            return
        granted = not bool(self.draft.get("staff"))
        tag = self.store.set_staff(self.roblox_id, granted)
        self.draft["staff"] = bool(tag.get("staff"))
        await show_customizing(
            interaction, self.bot, self.store, self.cfg, self.roblox_id, self.username, self.draft
        )

    @discord.ui.button(label="Select Shape", style=discord.ButtonStyle.primary, row=1)
    async def select_shape(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        embed = customizing_embed(self.draft, self.username)
        embed.set_footer(text="Pick Pill, Rounded, or Square.")
        await edit_panel(
            interaction,
            embed=embed,
            view=ShapeView(self),
            file=preview_file(self.store, self.roblox_id, self.draft),
        )

    @discord.ui.button(label="Save", style=discord.ButtonStyle.success, row=2)
    async def save(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        if not can_edit_tag(self.cfg, self.store, interaction.user, self.roblox_id):
            await ephemeral_error(interaction, "You can only save your own nametag.")
            return
        if self.draft.get("remove_icon") and not self.draft.get("pending_icon"):
            self.store.clear_image(self.roblox_id, "icon")
        elif self.draft.get("pending_icon") is not None:
            processed = self.draft["pending_icon"]
            processed.filename = str(self.draft.get("icon_name") or "")
            self.store.save_image(self.roblox_id, "icon", processed, self.cfg.public_base)
        if self.draft.get("remove_bg") and not self.draft.get("pending_bg"):
            self.store.clear_image(self.roblox_id, "bg")
        elif self.draft.get("pending_bg") is not None:
            processed = self.draft["pending_bg"]
            processed.filename = str(self.draft.get("bg_name") or "")
            self.store.save_image(self.roblox_id, "bg", processed, self.cfg.public_base)
        existing = self.store.get_tag(self.roblox_id) or {}
        staff_value = bool(self.draft.get("staff"))
        if not is_staff_member(self.cfg, interaction.user, self.store):
            staff_value = bool(existing.get("staff"))
        fields: dict[str, Any] = {
            "display_name": self.draft.get("display_name") or self.username,
            "roblox_username": self.username,
            "text_color": self.draft.get("text_color"),
            "outline_color": self.draft.get("outline_color"),
            "background_color": self.draft.get("background_color"),
            "font": self.draft.get("font"),
            "shape": self.draft.get("shape"),
            "glitch": self.draft.get("glitch"),
            "staff": staff_value,
        }
        if is_owner(self.cfg, interaction.user, self.store):
            fields["verified_badge"] = bool(self.draft.get("verified_badge"))
        tag = self.store.upsert_tag(self.roblox_id, **fields)
        draft = draft_from_tag(tag)
        await show_customizing(interaction, self.bot, self.store, self.cfg, self.roblox_id, self.username, draft)

    @discord.ui.button(label="Back", style=discord.ButtonStyle.secondary, row=2)
    async def back(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await show_management(interaction, self.bot, self.store, self.cfg)

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.danger, row=2)
    async def cancel(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await show_management(interaction, self.bot, self.store, self.cfg)

    @discord.ui.button(label="Remove BG", style=discord.ButtonStyle.danger, row=3)
    async def remove_bg(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        self.draft["remove_bg"] = True
        self.draft["pending_bg"] = None
        self.draft["bg_name"] = ""
        await show_customizing(interaction, self.bot, self.store, self.cfg, self.roblox_id, self.username, self.draft)

    @discord.ui.button(label="Remove Icon", style=discord.ButtonStyle.danger, row=3)
    async def remove_icon(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if self.readonly:
            await ephemeral_error(interaction, "This is view only. Use **Edit** to change it.")
            return
        self.draft["remove_icon"] = True
        self.draft["pending_icon"] = None
        self.draft["icon_name"] = ""
        await show_customizing(interaction, self.bot, self.store, self.cfg, self.roblox_id, self.username, self.draft)


class ManagementView(discord.ui.View):
    def __init__(self, bot: Any, store: Store, cfg: Config):
        super().__init__(timeout=PANEL_TIMEOUT)
        self.bot = bot
        self.store = store
        self.cfg = cfg

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        return await view_allows(interaction, self.cfg, self.store)

    @discord.ui.button(label="Create", style=discord.ButtonStyle.success, row=0)
    async def create(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await interaction.response.send_modal(UsernameModal(self.bot, self.store, self.cfg, "create"))

    @discord.ui.button(label="View", style=discord.ButtonStyle.primary, row=0)
    async def view(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await interaction.response.send_modal(UsernameModal(self.bot, self.store, self.cfg, "view"))

    @discord.ui.button(label="Edit", style=discord.ButtonStyle.primary, row=0)
    async def edit(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await interaction.response.send_modal(UsernameModal(self.bot, self.store, self.cfg, "edit"))

    @discord.ui.button(label="Delete", style=discord.ButtonStyle.danger, row=0)
    async def delete(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await interaction.response.send_modal(UsernameModal(self.bot, self.store, self.cfg, "delete"))

    @discord.ui.button(label="Transfer", style=discord.ButtonStyle.primary, row=1)
    async def transfer(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        if not is_staff_member(self.cfg, interaction.user, self.store):
            await ephemeral_error(interaction, "Staff only.")
            return
        await interaction.response.send_modal(TransferModal(self.bot, self.store, self.cfg))

    @discord.ui.button(label="Search", style=discord.ButtonStyle.secondary, row=1)
    async def search(self, interaction: discord.Interaction, _button: discord.ui.Button) -> None:
        await interaction.response.send_modal(SearchModal(self.bot, self.store, self.cfg))


async def send_management(destination: Any, bot: Any, store: Store, cfg: Config, *, ephemeral: bool = False) -> None:
    kwargs = {"embed": management_embed(), "view": ManagementView(bot, store, cfg)}
    if hasattr(destination, "response"):
        await destination.response.send_message(**kwargs, ephemeral=ephemeral)
    else:
        await destination.send(**kwargs)


async def handle_nametag_upload(bot: Any, message: discord.Message) -> bool:
    pending = bot.pending_uploads.get(message.author.id)
    if not pending or not message.attachments:
        return False
    if not can_use_bot(bot.cfg, message.author, bot.store):
        return False
    kind = str(pending.get("kind") or "icon")
    owner: CustomizingView | None = pending.get("view")
    if owner is None:
        return False
    attachment = message.attachments[0]
    try:
        data = await attachment.read()
        processed = process_upload(data, kind)
        processed.filename = attachment.filename
    except ImageError as exc:
        await message.reply(str(exc))
        return True
    if kind == "icon":
        owner.draft["pending_icon"] = processed
        owner.draft["remove_icon"] = False
        owner.draft["icon_name"] = attachment.filename
        owner.draft["icon_png"] = processed.static_png
    else:
        owner.draft["pending_bg"] = processed
        owner.draft["remove_bg"] = False
        owner.draft["bg_name"] = attachment.filename
        owner.draft["bg_png"] = processed.static_png
    bot.pending_uploads.pop(message.author.id, None)
    await message.reply(f"{kind.title()} staged. Click **Save** on the panel to apply it in-game.")
    panel = owner.panel_message
    if panel is not None:
        view = CustomizingView(
            bot,
            owner.store,
            owner.cfg,
            owner.roblox_id,
            owner.username,
            owner.draft,
            actor=message.author,
        )
        view.panel_message = panel
        file = preview_file(owner.store, owner.roblox_id, owner.draft)
        await panel.edit(embed=customizing_embed(owner.draft, owner.username), view=view, attachments=[file])
    return True
