# Cryax nametag host

Self-host the nametag API that `cryax src.lua` already talks to, plus a Discord bot that edits those tags (`.nametagpanel` / `/nametag`).

**Yes, you can run the API on your computer.** The Python process binds to `0.0.0.0:8787`. That is enough for the executor on the **same PC** (`http://127.0.0.1:8787`). Other people need a public URL to *your* machine (Cloudflare Tunnel or ngrok).

## Loadstring

GitHub raw **cannot** serve this client while the repo is private (`404`). Use a **Cloudflare Worker** for a permanent public line (this is the `xyro-api.workers.dev/loader` pattern), or HttpGet your PC.

### Permanent line (no domain)

`*.workers.dev` is a free Cloudflare hostname. It does not change when you restart the PC.

```powershell
cd $HOME\cryax
git pull
cd host\worker
.\deploy.ps1
```

If you connected **GitHub → Cloudflare** so it runs `npx wrangler deploy` on push, leave the **root directory empty** (repo root). Do not create a static-assets / Pages project. This repo’s root `wrangler.toml` is a Worker (`main = host/worker/src/worker.js`). After you pull this commit, push again and the build should succeed.

That logs into Cloudflare in the browser (local deploy only), uploads `cryax src.lua`, and prints a URL. Paste:

```lua
loadstring(game:HttpGet("https://cryax-api.YOURSUBDOMAIN.workers.dev/loader"))()
```

`/loader` is a tiny plain-Lua bootstrap. It HttpGets `/script.lua` and compiles with `loadstring or load`.

**If that line errors**, `https://cryax-api.cryaxontop.workers.dev/script.lua` is still client **3.3**. Lua 5.1 dies at line 276 (`ambiguous syntax near '('` from `(env ).CryaxClientEpoch = …`). `/loader` itself is fine. Fix: `git pull` then `.\host\worker\deploy.ps1` (Cloudflare login for the **cryaxontop** account). Until that deploy lands, CONTROL’s trycloudflare `/script.lua` or `https://cryax.cryaxontop.workers.dev/loader` (Git worker, 3.7+) will run.

Put the exact URL from wrangler into `.env` as `WORKER_BASE_URL=https://cryax-api.YOURSUBDOMAIN.workers.dev` so CONTROL copies it. Keep `.\start.ps1 -Hidden` running so Discord Save can **sync nametags to the Worker**. The loadstring then talks to `workers.dev` for both the script and the nametag API. Re-run `.\deploy.ps1` (or retry the Git deploy) after you change the Lua — the URL stays the same.

### Same PC only

```lua
loadstring(game:HttpGet("http://127.0.0.1:8787/script.lua"))()
```

Or paste **`loadstring.txt`** if HttpGet needs `request` / `syn.request`.

Friends who must hit **your** nametag API still need a domain + named tunnel (`https://api.yourname.com`). The worker loadstring can stay `workers.dev`; only `CryaxApiHost.txt` changes for them.

## 1. Run the host

`host` is a folder **inside this GitHub repo**, not on `C:\WINDOWS\system32`. Clone the repo first, then enter that folder.

### Windows (PowerShell)

Do **not** start in `C:\WINDOWS\system32`. Paste this from any PowerShell window:

```powershell
cd $HOME
git clone https://github.com/x9ksa/cryax.git
cd "$HOME\cryax\host"
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy ..\.env.example ..\.env
py -3 main.py
```

Then open **http://127.0.0.1:8787** in your browser. That is the Cryax **CONTROL** dashboard (API / Discord / tunnel cards, logs, start/stop). Roblox still uses the same port for nametags.

Or after the clone:

```powershell
cd "$HOME\cryax\host"
.\start.ps1 -Hidden
```

That starts CONTROL with **no command prompt**. Open **http://127.0.0.1:8787** and tick **Start with Windows** so API + Discord + tunnel come back after reboot.

If you want the console for logs instead:

```powershell
cd "$HOME\cryax\host"
.\start.ps1
```

If you see `Errno 10048` / port 8787 already in use, a leftover host is still running. Open **http://127.0.0.1:8787** — CONTROL may already be up. To kill it and start fresh:

```powershell
cd "$HOME\cryax\host"
.\start.ps1 -Restart
```

If `Activate.ps1` is blocked, run this once, then retry the activate line:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

If `git` is missing, install [Git for Windows](https://git-scm.com/download/win) or download the ZIP from https://github.com/x9ksa/cryax and unzip it, then:

```powershell
cd "$HOME\Downloads\cryax-main\host"
```

(The unzipped folder name may be `cryax-main`.)

You need [Python 3](https://www.python.org/downloads/) with **Add python.exe to PATH** checked.

### macOS / Linux

```bash
cd host
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example ../.env
python main.py
# or: python -m cryax_host
```

Open **http://127.0.0.1:8787** for the Cryax CONTROL dashboard.

Check it:

```bash
curl http://127.0.0.1:8787/health
curl -H "x-api-secret: bloodontop" "http://127.0.0.1:8787/nametags?secret=bloodontop"
```

Data is stored in `data/` as JSON + PNG frames.

## 2. Point Cryax at your API

On the same PC as your executor, create a file named **`CryaxApiHost.txt`** in the executor workspace:

```
http://127.0.0.1:8787
bloodontop
```

First non-comment line is the host URL (no trailing slash). Optional second line is `API_SECRET` if you changed it. Re-run `cryax src.lua`. If that file is missing, the script uses `http://127.0.0.1:8787`.

`host/CryaxApiHost.txt.example` is a copy-paste template.

For friends, put your tunnel URL in *their* `CryaxApiHost.txt`, for example:

```
https://api.YOURNAME.com
bloodontop
```

Also set `PUBLIC_BASE_URL` in `.env` to that same public URL so Discord previews and image links match.

## 3. Bring the Discord bot online

The bot is started by CONTROL together with the API. It stays **OFFLINE** until a token is in **`.env`** at the repo root (that file is gitignored). Do not put the token in `.env.example`.

### One-time Discord setup

1. Open [Discord Developer Portal](https://discord.com/developers/applications) → New Application → Bot → Add Bot.
2. Reset / copy the **token**. Paste it only in `.env` as `DISCORD_TOKEN=...`
3. Bot → Privileged Gateway Intents → enable **Message Content Intent** (needed for `.nametagpanel` and image uploads). Save changes.
4. OAuth2 → URL Generator → scopes `bot` + `applications.commands`.
   Bot permissions: Send Messages, Attach Files, Embed Links, Use Slash Commands. Open the URL and invite the bot into your server.
5. Copy Application ID into `DISCORD_CLIENT_ID`.
6. Server settings → Widget (or right-click the server in Discord) → copy Server ID into `DISCORD_GUILD_ID` so slash commands show up immediately.
7. Discord User Settings → Advanced → Developer Mode, then right-click yourself → Copy User ID into `DISCORD_OWNER_ID`.

If `.env` does not exist yet:

```powershell
copy "$HOME\cryax\.env.example" "$HOME\cryax\.env"
notepad "$HOME\cryax\.env"
```

Paste the token on the `DISCORD_TOKEN=` line. Keep `AUTO_START_DISCORD=1`.

### Start it

```powershell
cd "$HOME\cryax\host"
.\start.ps1
```

Open **http://127.0.0.1:8787**. The **Discord bot** card should say **ONLINE**. If it says OFFLINE, click **Start** on that card.

In CONTROL logs (Discord tab) you want:

`[cryax-host] Discord connected as YourBot`

In your Discord server the bot goes green. Then:

1. `.link <your Roblox user id>` or `/link`
2. `.nametagpanel` or `/nametag` — **Nametag Management** with Create / View / Edit / Delete / Transfer / Search
3. **Create** or **Edit**, type a Roblox username, then **Save**

Save writes the style `cryax src.lua` polls at `GET /nametags` (also `GET /cryax/v1/nametags`). In-game tags are the message-15 Kryptex pill: Discord display name, `@username`, icon, colors, shape, glitch, and `utf8.char(0xE000)` on the name when you grant the verified badge. The executor must be talking to **this** host (`CryaxApiHost.txt` or `http://127.0.0.1:8787`), not bloodapi.cc.

If CONTROL shows `Set DISCORD_TOKEN in .env` or `DISCORD_TOKEN is empty`, the host is reading `.env.example` or an empty token. Edit `.env`, then click **Restart** on the Discord card.

If the bot is online in CONTROL but still offline in Discord: Message Content Intent is off, the invite URL was never opened, or you need a **new token** (reset it in the Developer Portal if the old one was committed to GitHub).

Commands:

| Command | What it does |
| --- | --- |
| `/link <roblox_id>` or `.link <id>` | Bind Discord → Roblox |
| `.loadstring` / `/loadstring` | Posts the executor one-liner |
| `/nametag` / `/nametagpanel` or `.nametagpanel` | Nametag Management: Create, View, Edit, Delete, Transfer, Search |
| **Create / Edit** | Look up a Roblox username, then Save text, colors, shape, glitch, and images |
| Send a PNG/JPG/GIF after **Images** | Stages an icon or background; click **Save** (GIFs become PNG frames) |
| `/staff whitelist add\|remove <id>` | Used when `ACCESS_MODE=whitelist` |
| `/staff key create\|revoke` | Used when `ACCESS_MODE=key` |
| `/staff flag` / `/staff panel` / `.staffpanel` | **Discord staff.** Open or close the in-game Staff button for a Roblox id. Stored on this host. |
| `/staff list` or `.staffpanel list` | **Discord staff.** Who currently has the in-game Staff panel |
| `/staff blacklist` | Block an account from the script |
| `/verified grant\|revoke <id>` or `.verified <id> on\|off` | **Owner only.** Put the Roblox verified checkmark (`utf8.char(0xE000)`) on that nametag. Stored on this host. Staff cannot grant it. |
| `/verified list` or `.verified list` | **Owner only.** Who currently has the badge |

Default `ACCESS_MODE=open` so anyone running the script can connect.

### Staff panel and verified checkmark

These are **two different grants**. Discord staff can hand out the in-game Staff panel. Only you (`DISCORD_OWNER_ID`) can hand out the verified checkmark.

**1. Who may run Discord `/staff` commands**

- You: set `DISCORD_OWNER_ID` to your Discord user id (Developer Mode → Copy User ID).
- Extra Discord accounts: `STAFF_DISCORD_IDS=id1,id2` in `.env`.
- Restart the host after editing `.env`.

**2. Who sees the in-game Staff button**

Always-on Roblox ids (also baked as `STAFF_IDS` in `cryax src.lua`): `STAFF_ROBLOX_IDS` in `.env`.

Anyone else — from Discord, as a Discord staff member:

```
/staff panel roblox_id: 123456789 granted: True
```

Same effect: `/staff flag`, `.staffpanel 123456789 on`, or **Grant Staff** on `.nametagpanel` → Edit. List with `/staff list`. Revoke with `granted: False`.

The host writes `staff: true` on `nametags/{roblox_id}` and a matching `staff/{roblox_id}` document (`granted` + `panel`). The Roblox client polls `GET /nametags` and shows Staff when that flag is true for the local user.

**3. Verified checkmark (`utf8.char(0xE000)`)**

Owner only:

```
/verified grant 123456789
```

Same effect: `.verified 123456789 on` or **Grant Verified** on `.nametagpanel`. List with `/verified list`. Revoke with `/verified revoke`.

The host writes `verified_badge: true` on `nametags/{roblox_id}` and `verified_badges/{roblox_id}` (`glyph` is U+E000). The client appends the glyph to the display name. Staff ids do **not** get this automatically.

Grants are stored on this host, so they survive restarts. After changing the client, `git pull` and redeploy the worker (`host\worker\deploy.ps1`) so `cryax-api…/script.lua` is 3.9+.

## 4. Keep it online (no command prompt, same loadstring)

Closing a `python` / `cloudflared` window kills the API and issues a **new** `trycloudflare.com` URL. Do this instead.

### Hidden host

```powershell
cd "$HOME\cryax\host"
.\start.ps1 -Hidden
```

Open **http://127.0.0.1:8787** → tick **Start with Windows**. That writes a Startup shortcut that launches `pythonw` (no console).

### Permanent public link (named Cloudflare tunnel)

`trycloudflare.com` is temporary. Cloudflare does **not** give a free forever URL. A link that never changes needs **a domain you buy**, then a named tunnel hostname on that domain.

Do **not** open `www.cryax` — that is not a website.

1. Buy a cheap domain (Cloudflare Registrar, Porkbun, Namecheap). Example: `yourname.com`.
2. Add it to [Cloudflare](https://dash.cloudflare.com/) and finish nameserver setup (wait until the domain is **Active**).
3. [Zero Trust → Networks → Tunnels](https://one.dash.cloudflare.com/) → your tunnel (or **Create** → Cloudflared).
4. **Public hostname** / **Add published application**:
   - Subdomain: `api`
   - Domain: `yourname.com` (from the dropdown — if the list is empty, step 2 is not done)
   - Service type: HTTP
   - URL: `http://127.0.0.1:8787`
5. Install the Windows service in **Administrator** PowerShell (a normal window says Access denied):

```powershell
cloudflared.exe service install PASTE_TOKEN_HERE
```

Or from the repo: `cd $HOME\cryax\host ; .\install-tunnel.ps1`

6. Wait a minute, then open **https://api.yourname.com** — you should see CONTROL. If DNS still fails, the domain is not on Cloudflare yet.
7. In `.env`:

```
PUBLIC_BASE_URL=https://api.yourname.com
AUTO_START_TUNNEL=0
```

8. `cd $HOME\cryax\host ; .\start.ps1 -Hidden` and tick **Start with Windows**.

The loadstring stays:

```lua
loadstring(game:HttpGet("https://api.yourname.com/script.lua"))()
```

Put that same URL in each friend’s `CryaxApiHost.txt`. You already have the tunnel connector; the missing piece is the domain + public hostname. Keep `AUTO_START_TUNNEL=0` so CONTROL does not start a second cloudflared. Do not paste the token into Discord, GitHub, or chat.

If you cannot use Administrator, put `CLOUDFLARE_TUNNEL_TOKEN` in `.env`, set `AUTO_START_TUNNEL=1`, and let hidden CONTROL run `cloudflared tunnel run --token`.

**ngrok** reserved domains work the same way: set `TUNNEL_COMMAND` and `PUBLIC_BASE_URL` to that hostname.

Keep the host process running while people are in game. Heartbeats expire after `PRESENCE_TTL_SECONDS` (default 15).

## API the client already expects

| Path | Use |
| --- | --- |
| `GET /script.lua` | Full client (`cryax src.lua`) for the loadstring |
| `GET /loadstring` | One-liner that HttpGets this host’s `/script.lua` |
| `GET /nametags` | All styles |
| `GET /nametags/revision` | Cheap poll |
| `GET /images/nametag/{id}/icon\|bg/b64` | PNG frames as base64 |
| `POST /cryax/v1/heartbeat` | Mark a script user online |
| `GET /cryax/v1/online` | Who should show tags |
| `GET /cryax/v1/access` | Host-side gate only (the client no longer asks for a key) |
| `POST /cryax/v1/session` | Session open |
| `GET/POST /cryax/v1/commands` | Command queue (disabled on this host) |

Send `x-api-secret` and/or `?secret=` matching `API_SECRET`.
