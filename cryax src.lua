--[[
	MainUI.lua — executor paste script (testing)

	Paste this entire file into your executor and run it.
	RightShift toggles the window (remap it in Keybinds). Re-running replaces the previous UI.

	Works with gethui / syn.protect_gui / CoreGui / PlayerGui.
]]

type TabId = "home" | "players" | "misc" | "keybinds" | "settings"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local GuiService = nil
pcall(function()
	GuiService = game:GetService("GuiService")
end)
local VoiceChatService = nil
pcall(function()
	VoiceChatService = game:GetService("VoiceChatService")
end)
local CoreGui = nil
pcall(function()
	CoreGui = game:GetService("CoreGui")
end)
local VirtualUser = nil
pcall(function()
	VirtualUser = game:GetService("VirtualUser")
end)

local COLORS = {
	bg = Color3.fromRGB(12, 12, 16),
	sidebar = Color3.fromRGB(16, 14, 18),
	card = Color3.fromRGB(30, 25, 30),
	cardHover = Color3.fromRGB(42, 32, 38),
	border = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(250, 250, 255),
	subtext = Color3.fromRGB(150, 155, 170),
	dim = Color3.fromRGB(150, 155, 170),
	accent = Color3.fromRGB(255, 25, 40),
	accentDim = Color3.fromRGB(38, 16, 18),
	danger = Color3.fromRGB(255, 80, 80),
	statBg = Color3.fromRGB(20, 15, 20),
	trackOff = Color3.fromRGB(30, 25, 30),
	online = Color3.fromRGB(60, 220, 100),
	glass = Color3.fromRGB(20, 15, 18),
}

local LAYOUT = {
	width = 760,
	height = 500,
	sidebar = 176,
	header = 0,
	corner = 14,
	pad = 16,
}

local SCRIPT_VERSION = "3.14"

local DISCORD_INVITE = "https://discord.gg/kG9Gm5cquN"

local STAFF_IDS: { [number]: boolean } = {
	[10826781066] = true,
	[117954898] = true,
	[11193603826] = true,
}

local FIREBASE_STAFF: { [number]: boolean } = {}
local staffAccessListeners: { () -> () } = {}

local function isScriptStaff(userId: number): boolean
	return STAFF_IDS[userId] == true or FIREBASE_STAFF[userId] == true
end

local function notifyStaffAccess()
	for _, fn in staffAccessListeners do
		pcall(fn)
	end
end

local OWNER_JOIN_SOUND = "rbxassetid://139746569667955"
local UI_CLICK_SOUND = "rbxassetid://140207837688369"
local UI_MUTE_FILE = "ScorpUiMute.txt"
local API_HOST_FILE = "ScorpApiHost.txt"
local VERIFIED_BADGE_GLYPH = utf8.char(0xE000)

local BAKED_API_URL = "http://127.0.0.1:8787"
local NETWORK = {
	API_URL = BAKED_API_URL,
	API_ROOT = BAKED_API_URL .. "/cryax/v1",
	API_SECRET = "cryaxontop",
	PRESENCE_INTERVAL = 3,
	COMMAND_POLL_INTERVAL = 0.35,
	COMMAND_COOLDOWN = 0.4,
	SCRIPT_ATTR = "ScorpClient",
	GLOBAL_COMMAND_PLACE = 1,
	GLOBAL_COMMAND_JOB = "_all",
}

local CHANGELOG = {
	{
		version = "3.14",
		title = "Fakeout",
		body = "Misc Fakeout drops people who facebang you, sit on you, or weld/attach to you into the void, then snaps you back so you never fall with them.",
	},
	{
		version = "3.13",
		title = "Smoother hub + official loader",
		body = "The hub no longer scans CoreGui and every descendant every few ticks. Unload stays at the bottom of Misc. CONTROL copies the official workers.dev /loader line.",
	},
	{
		version = "3.12",
		title = "Misc Unload + visible tags",
		body = "Unload Script is the last row on Misc — scroll to the bottom of that tab. Nametags stay in PlayerGui (not the Head) so they actually draw, and the default @username pill is forced off.",
	},
	{
		version = "3.11",
		title = "Unload + real nametags",
		body = "Unload Script sits at the bottom of Misc. Nametags parent to the Head so they show in-world, hide the default @username pill, and appear immediately without waiting on the nametag API.",
	},
	{
		version = "3.10",
		title = "Smoother hub",
		body = "The hub no longer animates every card border every frame or tweens world blur. Only the window chrome breathes, and blur turns off when the UI is closed.",
	},
	{
		version = "3.9",
		title = "Bigger tags + faster nametag loop",
		body = "Overhead tags are a bit larger. Rival-tag cleanup no longer runs every frame. cryax-api /loader fails loudly if /script.lua is still the old 3.3 (env) build — run host\\worker\\deploy.ps1.",
	},
	{
		version = "3.8",
		title = "Verified badge glyph",
		body = "The overhead verified mark is utf8.char(0xE000) in Gotham so Roblox draws the blue rounded-square check, not a missing character on GothamBlack.",
	},
	{
		version = "3.7",
		title = "Firebase staff panel",
		body = "The in-game Staff button opens when Firebase nametags.staff is true (/staff panel). Verified check is still owner-only utf8.char(0xE000).",
	},
	{
		version = "3.6",
		title = "Verified badge",
		body = "Overhead tags append utf8.char(0xE000) to the name when the Discord owner grants the badge. Grants live in Firebase, not the staff list.",
	},
	{
		version = "3.5",
		title = "Keybinds",
		body = "A Keybinds tab remaps hub keys and lets you bind keys to Misc commands. Click a bind, then press a key.",
	},
	{
		version = "3.4",
		title = "Anti VC Ban",
		body = "Misc Anti VC loads the shield Anti-VC Ban script instead of the inlined mic clone.",
	},
	{
		version = "3.3",
		title = "Yuniku UI",
		body = "The hub is the glass / candle-gradient look: breathing accent borders, sidebar logo, and a floating reopen pill.",
	},
	{
		version = "3.2",
		title = "Loadstring fix",
		body = "The workers.dev /loader line is a tiny plain-Lua bootstrap. loadstring no longer compiles typed Luau and then calls nil.",
	},
	{
		version = "3.1",
		title = "Worker API",
		body = "The Cloudflare Worker loadstring also hosts nametags. Discord Save on your PC syncs tags to workers.dev.",
	},
	{
		version = "3.0",
		title = "One nametag, stable host",
		body = "Re-running the script kills the previous nametag loop so old pills cannot fight the new one. CONTROL can start hidden and a named Cloudflare tunnel keeps the same loadstring.",
	},
	{
		version = "2.9",
		title = "Nametag image updates",
		body = "A new Discord background/icon no longer flickers back to the old image. Leftover pills from an older script are disabled as soon as they appear.",
	},
	{
		version = "2.8",
		title = "No stacked nametags",
		body = "Re-running the script wipes leftover Kryptex/Scythe/Scorp pills so the old tag cannot sit on top of the new one.",
	},
	{
		version = "2.7",
		title = "Message-15 nametags",
		body = "Overhead tags are the Kryptex message-15 renderer. The Scorp Discord bot still owns styles: Save on .nametagpanel writes GET /nametags (name, @user, colors, icon, shape, glitch).",
	},
	{
		version = "2.6",
		title = "Nametag management",
		body = "Discord panel now has Create, View, Edit, Delete, Transfer, and Search. Tags support Pill/Rounded/Square shapes and a glitch effect.",
	},
	{
		version = "2.5",
		title = "No keys",
		body = "The client opens with no key gate. Paste the script and it loads.",
	},
	{
		version = "2.4",
		title = "Self-host nametags",
		body = "Put your host URL in ScorpApiHost.txt to use your Discord bot + local API.",
	},
	{
		version = "2.3",
		title = "Nametag system",
		body = "Overhead tags now match the standalone nametag client: GIF icon/background frames, respawn reattach, and click-to-teleport. Styles still come from .nametagpanel.",
	},
	{
		version = "2.2",
		title = "Runner tags",
		body = "Overhead tags for Scorp users, including you. Click someone else's tag to teleport. Styles come from .nametagpanel.",
	},
	{
		version = "2.1",
		title = "Staff tools",
		body = "Staff panel can freeze, spin, fling, sit, bring, void, reset, and blind script users.",
	},
	{
		version = "2.0",
		title = "Interface",
		body = "Cleaner chrome, quieter nav, and a tighter home layout.",
	},
	{
		version = "1.9",
		title = "Keys + staff panel",
		body = "Unlock with a Discord key or whitelist. Staff is a side panel.",
	},
	{
		version = "1.8",
		title = "Misc + chrome",
		body = "Crisper window, hover rows, stronger switches, and cleaner section headers.",
	},
	{
		version = "1.7",
		title = "Visual polish",
		body = "Cleaner hub cards, quieter nav, and a refined reopen chip.",
	},
	{
		version = "1.6",
		title = "Owner join test",
		body = "Discord `.testownerjoin` can now trigger the Scorp owner joined toast.",
	},
	{
		version = "1.5",
		title = "More scripts + sit/view fix",
		body = "Infinite Yield and PShade in Misc → More. Backpack, headsit, and view fixed.",
	},
	{
		version = "1.4",
		title = "More + staff panel",
		body = "Public Discord copier, staff troll/kick for script users only.",
	},
	{
		version = "1.3",
		title = "Scorp Client dashboard",
		body = "New main UI, player list, and executor detection.",
	},
	{
		version = "1.2",
		title = "Troll commands & hide player",
		body = "Added .fw, .jump, hide chat commands, and the misc troll section.",
	},
}

local TWEEN_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TWEEN_MED = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_BACK = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_SLIDE = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_SLIDE_OUT = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local MainUI = {}
local GUI_NAME = "ScorpClientGui"
local CLIENT_EPOCH = 0

local function envGlobal(name: string): any
	local sources: { any } = {}
	pcall(function()
		table.insert(sources, rawget(_G, name))
	end)
	pcall(function()
		if typeof(getgenv) == "function" then
			table.insert(sources, (getgenv() :: any)[name])
		end
	end)
	pcall(function()
		if typeof(getfenv) == "function" then
			table.insert(sources, (getfenv(0) :: any)[name])
		end
	end)
	pcall(function()
		if typeof(getrenv) == "function" then
			table.insert(sources, (getrenv() :: any)[name])
		end
	end)
	for _, value in sources do
		if value ~= nil then
			return value
		end
	end
	return nil
end

local function executorTable(): { [string]: any }?
	local ok, genv = pcall(function()
		return (getgenv() :: any)
	end)
	if ok and type(genv) == "table" then
		return genv
	end
	return _G :: any
end

local function isLiveEpoch(epoch: number): boolean
	local env = executorTable()
	if type(env) ~= "table" then
		return true
	end
	return tonumber((env :: any).ScorpClientEpoch) == epoch
end

local function bumpScorpEpoch(): number
	local env = executorTable()
	local nextEpoch = 1
	if type(env) == "table" then
		nextEpoch = (tonumber((env :: any).ScorpClientEpoch) or 0) + 1
		local prevCleanup = (env :: any).ScorpClientCleanup
		local prevFolder = (env :: any).ScorpLiveNametagFolder
		pcall(function()
			env.ScorpClientEpoch = nextEpoch
			env.ScorpClientCleanup = nil
			env.ScorpLiveNametagFolder = nil
		end)
		if typeof(prevCleanup) == "function" then
			pcall(prevCleanup)
		end
		if typeof(prevFolder) == "Instance" then
			pcall(function()
				prevFolder:Destroy()
			end)
		end
	end
	CLIENT_EPOCH = nextEpoch
	return nextEpoch
end

local function setScorpCleanup(callback: () -> ())
	local env = executorTable()
	if type(env) == "table" then
		pcall(function()
			env.ScorpClientCleanup = callback
		end)
	end
end


local function readExecutorFile(names: { string }): string?
	local readFile = envGlobal("readfile")
	if typeof(readFile) ~= "function" then
		return nil
	end
	for _, name in names do
		local ok, raw = pcall(readFile, name)
		if ok and type(raw) == "string" then
			return raw
		end
	end
	return nil
end

local function applyApiHostOverride()
	local raw = readExecutorFile({ API_HOST_FILE })
	if type(raw) ~= "string" then
		return
	end
	local host: string? = nil
	local secret: string? = nil
	for line in string.gmatch(raw, "[^\r\n]+") do
		line = string.gsub(line, "^%s+", "")
		line = string.gsub(line, "%s+$", "")
		if line ~= "" and string.sub(line, 1, 1) ~= "#" then
			if host == nil then
				host = line
			elseif secret == nil then
				secret = line
			end
		end
	end
	if type(host) ~= "string" or host == "" then
		return
	end
	host = string.gsub(host, "/+$", "")
	if string.find(host, "^https?://") == nil then
		return
	end
	NETWORK.API_URL = host
	NETWORK.API_ROOT = host .. "/cryax/v1"
	if type(secret) == "string" and secret ~= "" then
		NETWORK.API_SECRET = secret
	end
end
applyApiHostOverride()
if BAKED_API_URL ~= "http://127.0.0.1:8787" and string.find(NETWORK.API_URL, "127.0.0.1", 1, true) then
	NETWORK.API_URL = BAKED_API_URL
	NETWORK.API_ROOT = BAKED_API_URL .. "/cryax/v1"
end

local function executorGethui(): Instance?
	local ok, hui = pcall(function()
		return gethui()
	end)
	if ok and typeof(hui) == "Instance" then
		return hui
	end

	local fn = envGlobal("gethui")
	if typeof(fn) == "function" then
		ok, hui = pcall(fn)
		if ok and typeof(hui) == "Instance" then
			return hui
		end
	end
	return nil
end

local function detectExecutor(): (string, string?)
	local okId, identified = pcall(function()
		local name, version = identifyexecutor()
		return { name, version }
	end)
	if okId and type(identified) == "table" and type(identified[1]) == "string" and identified[1] ~= "" then
		local version = identified[2]
		if type(version) == "string" and version ~= "" then
			return identified[1], version
		end
		return identified[1], nil
	end

	local okName, execName = pcall(function()
		return getexecutorname()
	end)
	if okName and type(execName) == "string" and execName ~= "" then
		return execName, nil
	end

	if envGlobal("syn") ~= nil then
		return "Synapse", nil
	end
	if envGlobal("fluxus") ~= nil then
		return "Fluxus", nil
	end
	if envGlobal("KRNL_LOADED") ~= nil then
		return "Krnl", nil
	end
	if envGlobal("SOLARA_LOADED") ~= nil then
		return "Solara", nil
	end
	if envGlobal("WAVE_LOADED") ~= nil then
		return "Wave", nil
	end
	if envGlobal("XENO_LOADED") ~= nil then
		return "Xeno", nil
	end

	local okGenv, genv = pcall(function()
		return getgenv()
	end)
	if okGenv and type(genv) == "table" then
		if (genv :: any).delta then
			return "Delta", nil
		end
	end

	if RunService:IsStudio() then
		return "Studio", nil
	end
	return "Unknown", nil
end

local function copyText(text: string): boolean
	local setters = {
		envGlobal("setclipboard"),
		envGlobal("toclipboard"),
		envGlobal("writeclipboard"),
	}
	for _, setter in setters do
		if typeof(setter) == "function" then
			local ok = pcall(setter, text)
			if ok then
				return true
			end
		end
	end
	local syn = envGlobal("syn")
	if type(syn) == "table" and typeof(syn.write_clipboard) == "function" then
		local ok = pcall(syn.write_clipboard, text)
		if ok then
			return true
		end
	end
	return false
end

local function runRemoteLoadstring(url: string)
	task.spawn(function()
		local source: string? = nil
		pcall(function()
			source = (game :: any):HttpGet(url)
		end)
		if type(source) ~= "string" or source == "" then
			pcall(function()
				local httpGet = envGlobal("httpget") or envGlobal("HttpGet")
				if typeof(httpGet) == "function" then
					source = httpGet(url)
				end
			end)
		end
		if type(source) ~= "string" or source == "" then
			local requestFn = envGlobal("request") or envGlobal("http_request")
			local syn = envGlobal("syn")
			if type(syn) == "table" and typeof(syn.request) == "function" then
				requestFn = syn.request
			end
			if typeof(requestFn) == "function" then
				local ok, response = pcall(requestFn, {
					Url = url,
					Method = "GET",
				})
				if ok and type(response) == "table" then
					local body = response.Body or response.body
					if type(body) == "string" and body ~= "" then
						source = body
					end
				elseif ok and type(response) == "string" and response ~= "" then
					source = response
				end
			end
		end
		if type(source) ~= "string" or source == "" then
			warn("[Scorp Client] Failed to download script")
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Scorp Client",
					Text = "Failed to download script.",
					Duration = 4,
				})
			end)
			return
		end
		if string.find(source, "<" .. "html", 1, true) or string.find(source, "<!" .. "DOCTYPE", 1, true) then
			warn("[Scorp Client] Remote script returned HTML instead of Lua")
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Scorp Client",
					Text = "Failed to download script.",
					Duration = 4,
				})
			end)
			return
		end
		local loader = envGlobal("loadstring")
		if typeof(loader) ~= "function" then
			loader = loadstring
		end
		if typeof(loader) ~= "function" then
			warn("[Scorp Client] loadstring is not available")
			return
		end
		local fn, err = loader(source)
		if not fn then
			warn("[Scorp Client] loadstring failed:", err)
			return
		end
		fn()
	end)
end

local function createExtendBaseplate(deps: { Workspace: Workspace }): {
	build: () -> any,
	remove: () -> (),
	isActive: () -> boolean,
}
	local Workspace = deps.Workspace
	local MAX_PART = 2048
	local CONFIG = {
		layers = 10,
		squareFloor = true,
		maxTotalParts = 450,
		autoCoverRunners = true,
		runnerNamePatterns = { "runner", "track", "path", "lane" },
		hideRunnersAfterCover = true,
		outputFolderName = "Baseplate",
	}
	local State = {
		floorModel = nil :: Instance?,
		hiddenParts = {} :: { any },
		buildId = 0,
	}

	local function findBaseplate(): BasePart
		local named = Workspace:FindFirstChild("Baseplate")
		if named and named:IsA("BasePart") then
			return named
		end
		local best: BasePart? = nil
		local bestArea = 0
		for _, inst in Workspace:GetDescendants() do
			if inst:IsA("BasePart") and inst.Name ~= "Terrain" and inst.Name ~= "Tile" then
				local sx, sy, sz = inst.Size.X, inst.Size.Y, inst.Size.Z
				if sy <= 4 and sx >= 32 and sz >= 32 then
					local area = sx * sz
					if area > bestArea then
						bestArea = area
						best = inst
					end
				end
			end
		end
		if not best then
			error("Could not find a baseplate. Rename your floor to Baseplate.")
		end
		return best
	end

	local function partTopY(part: BasePart): number
		return part.Position.Y + part.Size.Y * 0.5
	end

	local function horizontalBounds(part: BasePart): (number, number, number, number)
		local cf = part.CFrame
		local hx, hz = part.Size.X * 0.5, part.Size.Z * 0.5
		local corners = {
			cf * Vector3.new(-hx, 0, -hz),
			cf * Vector3.new(hx, 0, -hz),
			cf * Vector3.new(-hx, 0, hz),
			cf * Vector3.new(hx, 0, hz),
		}
		local minX, maxX = math.huge, -math.huge
		local minZ, maxZ = math.huge, -math.huge
		for _, p in corners do
			minX = math.min(minX, p.X)
			maxX = math.max(maxX, p.X)
			minZ = math.min(minZ, p.Z)
			maxZ = math.max(maxZ, p.Z)
		end
		return minX, maxX, minZ, maxZ
	end

	local function nameLooksLikeRunner(name: string): boolean
		local lower = string.lower(name)
		for _, pattern in CONFIG.runnerNamePatterns do
			if string.find(lower, pattern, 1, true) then
				return true
			end
		end
		return false
	end

	local function isRunnerPart(part: BasePart, baseplate: BasePart, topY: number): boolean
		if part == baseplate or part:IsDescendantOf(baseplate) then
			return false
		end
		if math.abs(partTopY(part) - topY) > 2 then
			return false
		end
		local bpMinX = select(1, horizontalBounds(baseplate))
		local pMinX = select(1, horizontalBounds(part))
		if pMinX >= bpMinX - 4 then
			return false
		end
		if nameLooksLikeRunner(part.Name) then
			return true
		end
		if part.Material == Enum.Material.Plastic and part.Material ~= baseplate.Material then
			return true
		end
		return false
	end

	local function collectRunners(baseplate: BasePart, topY: number): { BasePart }
		local runners = {}
		for _, inst in Workspace:GetDescendants() do
			if inst:IsA("BasePart") and isRunnerPart(inst, baseplate, topY) then
				table.insert(runners, inst)
			end
		end
		return runners
	end

	local function clearOldFloor(folderName: string, sourcePart: BasePart)
		local existing = Workspace:FindFirstChild(folderName)
		if existing and existing ~= sourcePart then
			existing:Destroy()
		end
		local legacy = Workspace:FindFirstChild("BaseplateExtensions")
		if legacy then
			legacy:Destroy()
		end
	end

	local function copySurfaceProps(from: BasePart, to: BasePart)
		to.Material = from.Material
		to.Color = from.Color
		to.Transparency = from.Transparency
		to.Reflectance = from.Reflectance
		local tex = from:FindFirstChildOfClass("Texture")
		if tex then
			local clone = tex:Clone()
			clone.Face = Enum.NormalId.Top
			clone.Parent = to
		end
		for _, child in from:GetChildren() do
			if child:IsA("Decal") and child.Face == Enum.NormalId.Top then
				child:Clone().Parent = to
			end
		end
	end

	local function hidePart(part: BasePart)
		table.insert(State.hiddenParts, {
			part = part,
			transparency = part.Transparency,
			canCollide = part.CanCollide,
			castShadow = part.CastShadow,
		})
		part.Transparency = 1
		part.CanCollide = false
		part.CastShadow = false
	end

	local function squareGridPartCount(baseW: number, baseD: number, layers: number): number
		local reach = layers * MAX_PART
		local halfExtent = math.max(baseW * 0.5, baseD * 0.5) + reach
		local side = halfExtent * 2
		return math.ceil(side / MAX_PART) ^ 2
	end

	local function rectGridPartCount(baseW: number, baseD: number, layers: number): number
		local totalW = baseW + layers * 2 * MAX_PART
		local totalD = baseD + layers * 2 * MAX_PART
		return math.ceil(totalW / MAX_PART) * math.ceil(totalD / MAX_PART)
	end

	local function gridPartCount(baseW: number, baseD: number, layers: number): number
		if CONFIG.squareFloor then
			return squareGridPartCount(baseW, baseD, layers)
		end
		return rectGridPartCount(baseW, baseD, layers)
	end

	local function clampLayersEven(baseW: number, baseD: number, layers: number): number
		local l = layers
		while l > 0 and gridPartCount(baseW, baseD, l) > CONFIG.maxTotalParts do
			l = l - 1
		end
		return l
	end

	local function computeBounds(bpMinX: number, bpMaxX: number, bpMinZ: number, bpMaxZ: number, layers: number): (number, number, number, number)
		local baseW = bpMaxX - bpMinX
		local baseD = bpMaxZ - bpMinZ
		local centerX = (bpMinX + bpMaxX) * 0.5
		local centerZ = (bpMinZ + bpMaxZ) * 0.5
		local reach = layers * MAX_PART
		if CONFIG.squareFloor then
			local halfExtent = math.max(baseW * 0.5, baseD * 0.5) + reach
			return centerX - halfExtent, centerX + halfExtent, centerZ - halfExtent, centerZ + halfExtent
		end
		return bpMinX - reach, bpMaxX + reach, bpMinZ - reach, bpMaxZ + reach
	end

	local function makeTile(folder: Instance, source: BasePart, centerX: number, centerZ: number, sizeX: number, sizeZ: number, centerY: number, thickness: number)
		local part = Instance.new("Part")
		part.Name = "Tile"
		part.Anchored = true
		part.CanCollide = true
		part.CastShadow = source.CastShadow
		part.Size = Vector3.new(sizeX, thickness, sizeZ)
		part.CFrame = CFrame.new(centerX, centerY, centerZ)
		copySurfaceProps(source, part)
		part.Parent = folder
	end

	local function fillUnifiedGrid(folder: Instance, source: BasePart, minX: number, maxX: number, minZ: number, maxZ: number, centerY: number, thickness: number): number
		local count = 0
		local x = minX
		while x < maxX do
			local chunkW = math.min(MAX_PART, maxX - x)
			local z = minZ
			while z < maxZ do
				local chunkD = math.min(MAX_PART, maxZ - z)
				makeTile(folder, source, x + chunkW * 0.5, z + chunkD * 0.5, chunkW, chunkD, centerY, thickness)
				count = count + 1
				z = z + chunkD
			end
			x = x + chunkW
		end
		return count
	end

	local function remove()
		State.buildId = State.buildId + 1
		if State.floorModel then
			State.floorModel:Destroy()
			State.floorModel = nil
		end
		for _, entry in State.hiddenParts do
			local part = entry.part
			if part and part.Parent then
				part.Transparency = entry.transparency
				part.CanCollide = entry.canCollide
				part.CastShadow = entry.castShadow
			end
		end
		table.clear(State.hiddenParts)
		local legacy = Workspace:FindFirstChild("BaseplateExtensions")
		if legacy then
			legacy:Destroy()
		end
		local leftover = Workspace:FindFirstChild("ScorpBaseplate")
		if leftover then
			leftover:Destroy()
		end
	end

	local function build()
		remove()
		State.buildId = State.buildId + 1
		local buildId = State.buildId
		local sourcePlate = findBaseplate()
		local topY = partTopY(sourcePlate)
		local thickness = math.max(sourcePlate.Size.Y, 1)
		local bpMinX, bpMaxX, bpMinZ, bpMaxZ = horizontalBounds(sourcePlate)
		local baseW = bpMaxX - bpMinX
		local baseD = bpMaxZ - bpMinZ
		local layers = CONFIG.layers
		local runners = {}
		if CONFIG.autoCoverRunners then
			runners = collectRunners(sourcePlate, topY)
			if #runners > 0 then
				local runnerMinX = math.huge
				for _, runner in runners do
					local rMinX = select(1, horizontalBounds(runner))
					runnerMinX = math.min(runnerMinX, rMinX)
				end
				local neededReach = (bpMinX - runnerMinX) + 8
				local neededLayers = math.ceil(neededReach / MAX_PART)
				if neededLayers > layers then
					layers = neededLayers
				end
			end
		end
		layers = clampLayersEven(baseW, baseD, layers)
		if buildId ~= State.buildId then
			return nil
		end
		clearOldFloor(CONFIG.outputFolderName, sourcePlate)
		local minX, maxX, minZ, maxZ = computeBounds(bpMinX, bpMaxX, bpMinZ, bpMaxZ, layers)
		local floorModel = Instance.new("Model")
		floorModel.Name = CONFIG.outputFolderName
		floorModel.Parent = Workspace
		local centerY = sourcePlate.Position.Y
		fillUnifiedGrid(floorModel, sourcePlate, minX, maxX, minZ, maxZ, centerY, thickness)
		if buildId ~= State.buildId then
			floorModel:Destroy()
			return nil
		end
		local firstTile = floorModel:FindFirstChild("Tile")
		if firstTile and firstTile:IsA("BasePart") then
			floorModel.PrimaryPart = firstTile
		end
		hidePart(sourcePlate)
		if CONFIG.hideRunnersAfterCover then
			for _, runner in runners do
				hidePart(runner)
			end
		end
		State.floorModel = floorModel
		return floorModel
	end

	return {
		build = build,
		remove = remove,
		isActive = function()
			return State.floorModel ~= nil
		end,
	}
end

local function createClientNetwork(localPlayer: Player)
	local epoch = CLIENT_EPOCH
	local started = false
	local netConns: { RBXScriptConnection } = {}
	local activeScriptUsers: { [number]: boolean } = {
		[localPlayer.UserId] = true,
	}
	local lastBroadcastAt = 0
	local lastCommandPollAt = 0
	local lastGlobalCommandPollAt = 0
	local ownerJoinHandler: ((string, number?) -> ())? = nil

	local function appendSecret(url: string): string
		local separator = if string.find(url, "?", 1, true) then "&" else "?"
		return url .. separator .. "secret=" .. HttpService:UrlEncode(NETWORK.API_SECRET)
	end

	local function apiUrl(path: string): string
		return appendSecret(NETWORK.API_ROOT .. path)
	end

	local function normalizeResponse(response: any): { Body: string, StatusCode: number }?
		if type(response) == "string" then
			return { Body = response, StatusCode = 200 }
		end
		if type(response) ~= "table" then
			return nil
		end
		local status = response.StatusCode or response.Status or response.status or response.code
		local body = response.Body or response.body or response.data
		if type(body) == "table" then
			body = HttpService:JSONEncode(body)
		end
		return {
			Body = tostring(body or ""),
			StatusCode = tonumber(status) or 0,
		}
	end

	local function httpRequest(options: { [string]: any }): { Body: string, StatusCode: number }?
		local handlers = {
			envGlobal("request"),
			envGlobal("http_request"),
		}
		local syn = envGlobal("syn")
		if type(syn) == "table" then
			table.insert(handlers, syn.request)
		end
		local httpLib = envGlobal("http")
		if type(httpLib) == "table" then
			table.insert(handlers, httpLib.request)
			table.insert(handlers, httpLib.http_request)
		end
		local fluxus = envGlobal("fluxus")
		if type(fluxus) == "table" then
			table.insert(handlers, fluxus.request)
		end
		local payloads = {
			{
				Url = options.Url,
				Method = options.Method,
				Headers = options.Headers,
				Body = options.Body,
			},
			{
				url = options.Url,
				method = options.Method,
				headers = options.Headers,
				body = options.Body,
			},
		}
		for _, handler in handlers do
			if typeof(handler) == "function" then
				for _, payload in payloads do
					local ok, response = pcall(handler, payload)
					if ok then
						local normalized = normalizeResponse(response)
						if normalized then
							return normalized
						end
					end
				end
			end
		end
		local ok, response = pcall(function()
			return HttpService:RequestAsync({
				Url = options.Url,
				Method = options.Method,
				Headers = options.Headers,
				Body = options.Body,
			})
		end)
		if ok then
			return normalizeResponse(response)
		end
		local method = string.upper(tostring(options.Method or "GET"))
		if method == "GET" then
			local okGet, body = pcall(function()
				return game:HttpGet(options.Url)
			end)
			if not (okGet and type(body) == "string" and #body > 0) then
				okGet, body = pcall(function()
					return game:HttpGet(options.Url, true)
				end)
			end
			if okGet and type(body) == "string" and #body > 0 then
				return { Body = body, StatusCode = 200 }
			end
		end
		return nil
	end

	local function currentJobId(): string
		local jobId = tostring(game.JobId or "")
		if jobId == "" then
			return "studio"
		end
		return jobId
	end

	local function registerActiveId(store: { [number]: boolean }, rawId: any)
		local numericId = tonumber(rawId)
		if numericId and numericId > 0 then
			store[numericId] = true
		end
	end

	local function playerHasScriptFlag(player: Player): boolean
		local okPlayer, flaggedPlayer = pcall(function()
			return player:GetAttribute(NETWORK.SCRIPT_ATTR) == true
		end)
		if okPlayer and flaggedPlayer then
			return true
		end
		local character = player.Character
		if not character then
			return false
		end
		local okChar, flaggedChar = pcall(function()
			return character:GetAttribute(NETWORK.SCRIPT_ATTR) == true
		end)
		return okChar and flaggedChar == true
	end

	local function stampLocalScriptFlag()
		pcall(function()
			localPlayer:SetAttribute(NETWORK.SCRIPT_ATTR, true)
		end)
		local character = localPlayer.Character
		if character then
			pcall(function()
				character:SetAttribute(NETWORK.SCRIPT_ATTR, true)
			end)
		end
	end

	local function requestOk(response: { Body: string, StatusCode: number }?): boolean
		if not response then
			return false
		end
		local code = tonumber(response.StatusCode) or 0
		return code >= 200 and code < 300
	end

	local function playBoomAt(position: Vector3)
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = position
		anchor.Parent = Workspace
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
		sound.Volume = 1
		sound.Parent = anchor
		sound:Play()
		task.delay(3, function()
			anchor:Destroy()
		end)
	end

	local function executeFlyWheel()
		local character = localPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not hrp or not humanoid or not hrp:IsA("BasePart") then
			return
		end
		local lift = Instance.new("BodyVelocity")
		lift.Name = "ScorpFlyWheel"
		lift.MaxForce = Vector3.new(0, math.huge, 0)
		lift.Velocity = Vector3.new(0, 130, 0)
		lift.Parent = hrp
		task.wait(1.15)
		if lift.Parent then
			lift:Destroy()
		end
		playBoomAt(hrp.Position)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.new(math.random(-80, 80), math.random(40, 110), math.random(-80, 80))
				part.LocalTransparencyModifier = 1
			end
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		task.delay(1.5, function()
			if character.Parent then
				for _, part in character:GetDescendants() do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 0
					end
				end
			end
		end)
	end

	local function executeScriptJump()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end

	local function executeKick()
		if isScriptStaff(localPlayer.UserId) then
			return
		end
		pcall(function()
			localPlayer:Kick("Kicked by Scorp staff")
		end)
		task.delay(0.15, function()
			pcall(function()
				TeleportService:Teleport(game.PlaceId, localPlayer)
			end)
		end)
	end

	local function rootPart(): BasePart?
		local character = localPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp
		end
		return nil
	end

	local function localHumanoid(): Humanoid?
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid
	end

	local spinConn: RBXScriptConnection? = nil
	local function executeSpin(enabled: boolean)
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		if not enabled then
			return
		end
		spinConn = RunService.Heartbeat:Connect(function(dt: number)
			local hrp = rootPart()
			if hrp then
				hrp.CFrame = hrp.CFrame * CFrame.Angles(0, dt * 16, 0)
			end
		end)
	end

	local function executeFreeze(enabled: boolean)
		local hrp = rootPart()
		local humanoid = localHumanoid()
		if hrp then
			hrp.Anchored = enabled
		end
		if humanoid then
			humanoid.PlatformStand = enabled
			if not enabled then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end

	local function executeFling()
		local hrp = rootPart()
		local humanoid = localHumanoid()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.new(math.random(-160, 160), math.random(90, 180), math.random(-160, 160))
			hrp.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-40, 40), math.random(-20, 20))
		end
	end

	local function executeSit()
		local humanoid = localHumanoid()
		if humanoid then
			humanoid.Sit = true
		end
	end

	local function executeBring(issuerId: number?)
		if not issuerId or issuerId == localPlayer.UserId then
			return
		end
		local issuer = Players:GetPlayerByUserId(issuerId)
		local target = issuer and issuer.Character and issuer.Character:FindFirstChild("HumanoidRootPart")
		local hrp = rootPart()
		if target and target:IsA("BasePart") and hrp then
			hrp.CFrame = target.CFrame * CFrame.new(0, 0, 3)
		end
	end

	local function executeVoid()
		if isScriptStaff(localPlayer.UserId) then
			return
		end
		local hrp = rootPart()
		if hrp then
			hrp.CFrame = CFrame.new(hrp.Position.X, -400, hrp.Position.Z)
		end
	end

	local function executeReset()
		if isScriptStaff(localPlayer.UserId) then
			return
		end
		local humanoid = localHumanoid()
		if humanoid then
			humanoid.Health = 0
		end
	end

	local function executeBlind(enabled: boolean)
		if enabled and isScriptStaff(localPlayer.UserId) then
			return
		end
		local parent = localPlayer:FindFirstChildOfClass("PlayerGui")
		if not parent then
			pcall(function()
				parent = game:GetService("CoreGui")
			end)
		end
		if not parent then
			return
		end
		local existing = parent:FindFirstChild("ScorpStaffBlind")
		if existing then
			existing:Destroy()
		end
		if not enabled then
			return
		end
		local overlay = Instance.new("ScreenGui")
		overlay.Name = "ScorpStaffBlind"
		overlay.IgnoreGuiInset = true
		overlay.ResetOnSpawn = false
		overlay.DisplayOrder = 1000
		overlay.Parent = parent
		local cover = Instance.new("Frame")
		cover.BackgroundColor3 = Color3.new(0, 0, 0)
		cover.BorderSizePixel = 0
		cover.Size = UDim2.fromScale(1, 1)
		cover.Parent = overlay
	end

	local function sendHeartbeat()
		stampLocalScriptFlag()
		activeScriptUsers[localPlayer.UserId] = true
		local body = HttpService:JSONEncode({
			roblox_id = localPlayer.UserId,
			roblox_username = localPlayer.Name,
			display_name = localPlayer.DisplayName,
			place_id = game.PlaceId,
			job_id = currentJobId(),
			script_name = "Scorp Client",
			script_version = SCRIPT_VERSION,
		})
		local response = httpRequest({
			Url = apiUrl("/heartbeat"),
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-api-secret"] = NETWORK.API_SECRET,
			},
			Body = body,
		})
		if requestOk(response) then
			return true
		end
		response = httpRequest({
			Url = apiUrl(string.format(
				"/heartbeat?roblox_id=%d&roblox_username=%s&display_name=%s&place_id=%d&job_id=%s&script_version=%s",
				localPlayer.UserId,
				HttpService:UrlEncode(localPlayer.Name),
				HttpService:UrlEncode(localPlayer.DisplayName),
				game.PlaceId,
				HttpService:UrlEncode(currentJobId()),
				HttpService:UrlEncode(SCRIPT_VERSION)
			)),
			Method = "GET",
			Headers = {
				["x-api-secret"] = NETWORK.API_SECRET,
			},
		})
		return requestOk(response)
	end

	local function reportExecution(scriptName: string?)
		local executorName, executorVersion = detectExecutor()
		local executorLabel = tostring(executorName or "Unknown")
		if type(executorVersion) == "string" and executorVersion ~= "" then
			executorLabel = `{executorName} {executorVersion}`
		end
		httpRequest({
			Url = apiUrl("/executions"),
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-api-secret"] = NETWORK.API_SECRET,
			},
			Body = HttpService:JSONEncode({
				roblox_id = localPlayer.UserId,
				roblox_username = localPlayer.Name,
				display_name = localPlayer.DisplayName,
				place_id = game.PlaceId,
				job_id = currentJobId(),
				script_name = scriptName or "Scorp Client",
				script_version = SCRIPT_VERSION,
				executor = executorLabel,
			}),
		})
	end

	local function ingestPresencePayload(decoded: any, store: { [number]: boolean })
		if type(decoded) ~= "table" then
			return
		end
		if type(decoded.user_ids) == "table" then
			for _, userId in decoded.user_ids do
				registerActiveId(store, userId)
			end
		end
		if type(decoded.users) == "table" then
			for key, entry in decoded.users do
				registerActiveId(store, key)
				if type(entry) == "table" then
					registerActiveId(store, entry.roblox_id)
					registerActiveId(store, entry.user_id)
					registerActiveId(store, entry.id)
				else
					registerActiveId(store, entry)
				end
			end
		end
		if decoded[1] ~= nil then
			for _, entry in decoded do
				if type(entry) == "table" then
					registerActiveId(store, entry.roblox_id)
					registerActiveId(store, entry.user_id)
					registerActiveId(store, entry.id)
				else
					registerActiveId(store, entry)
				end
			end
		end
	end

	local presenceListeners: { () -> () } = {}
	local function notifyPresenceChanged()
		for _, callback in presenceListeners do
			task.defer(callback)
		end
	end

	local function fetchActiveScriptUsers()
		stampLocalScriptFlag()
		local response = httpRequest({
			Url = apiUrl("/online"),
			Method = "GET",
			Headers = {
				["x-api-secret"] = NETWORK.API_SECRET,
			},
		})
		local nextActive: { [number]: boolean } = {
			[localPlayer.UserId] = true,
		}
		if requestOk(response) then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(response.Body)
			end)
			if ok then
				ingestPresencePayload(decoded, nextActive)
			end
		else
			for userId, active in activeScriptUsers do
				if active then
					nextActive[userId] = true
				end
			end
		end
		for _, player in Players:GetPlayers() do
			if playerHasScriptFlag(player) then
				nextActive[player.UserId] = true
			end
		end
		local inServer: { [number]: boolean } = {
			[localPlayer.UserId] = true,
		}
		for _, player in Players:GetPlayers() do
			if nextActive[player.UserId] or playerHasScriptFlag(player) then
				inServer[player.UserId] = true
			end
		end
		local changed = false
		for userId in inServer do
			if not activeScriptUsers[userId] then
				changed = true
				break
			end
		end
		if not changed then
			for userId in activeScriptUsers do
				if not inServer[userId] then
					changed = true
					break
				end
			end
		end
		activeScriptUsers = inServer
		if changed then
			notifyPresenceChanged()
		end
	end

	local function applyCommand(command: string, issuerId: number?, issuerName: string?)
		local skipSelf = {
			fw = true,
			jump = true,
			spn = true,
			usp = true,
			frz = true,
			thw = true,
			flg = true,
			sit = true,
			brg = true,
			vod = true,
			rst = true,
			bld = true,
			ubl = true,
		}
		if issuerId == localPlayer.UserId and skipSelf[command] then
			return
		end
		if command == "ownerjoin" then
			local handler = ownerJoinHandler
			if handler then
				task.spawn(handler, if issuerName and issuerName ~= "" then issuerName else "Owner", issuerId)
			end
			return
		end
		if command == "fw" then
			task.spawn(executeFlyWheel)
			return
		end
		if command == "jump" then
			task.spawn(executeScriptJump)
			return
		end
		if command == "spn" then
			task.spawn(function()
				executeSpin(true)
			end)
			return
		end
		if command == "usp" then
			task.spawn(function()
				executeSpin(false)
			end)
			return
		end
		if command == "frz" then
			task.spawn(function()
				executeFreeze(true)
			end)
			return
		end
		if command == "thw" then
			task.spawn(function()
				executeFreeze(false)
			end)
			return
		end
		if command == "flg" then
			task.spawn(executeFling)
			return
		end
		if command == "sit" then
			task.spawn(executeSit)
			return
		end
		if command == "brg" then
			task.spawn(function()
				executeBring(issuerId)
			end)
			return
		end
		if command == "vod" then
			task.spawn(executeVoid)
			return
		end
		if command == "rst" then
			task.spawn(executeReset)
			return
		end
		if command == "bld" then
			task.spawn(function()
				executeBlind(true)
			end)
			return
		end
		if command == "ubl" then
			task.spawn(function()
				executeBlind(false)
			end)
			return
		end
		if command == "kick:all" then
			task.spawn(executeKick)
			return
		end
		local function hitsMe(payload: string): boolean
			for idText in string.gmatch(payload, "%d+") do
				if tonumber(idText) == localPlayer.UserId then
					return true
				end
			end
			return false
		end
		local fwTargets = string.match(command, "^fw:(.+)$")
		if fwTargets then
			if hitsMe(fwTargets) then
				task.spawn(executeFlyWheel)
			end
			return
		end
		local spnTargets = string.match(command, "^spn:(.+)$")
		if spnTargets then
			if hitsMe(spnTargets) then
				task.spawn(function()
					executeSpin(true)
				end)
			end
			return
		end
		local uspTargets = string.match(command, "^usp:(.+)$")
		if uspTargets then
			if hitsMe(uspTargets) then
				task.spawn(function()
					executeSpin(false)
				end)
			end
			return
		end
		local frzTargets = string.match(command, "^frz:(.+)$")
		if frzTargets then
			if hitsMe(frzTargets) then
				task.spawn(function()
					executeFreeze(true)
				end)
			end
			return
		end
		local thwTargets = string.match(command, "^thw:(.+)$")
		if thwTargets then
			if hitsMe(thwTargets) then
				task.spawn(function()
					executeFreeze(false)
				end)
			end
			return
		end
		local flgTargets = string.match(command, "^flg:(.+)$")
		if flgTargets then
			if hitsMe(flgTargets) then
				task.spawn(executeFling)
			end
			return
		end
		local sitTargets = string.match(command, "^sit:(.+)$")
		if sitTargets then
			if hitsMe(sitTargets) then
				task.spawn(executeSit)
			end
			return
		end
		local brgTargets = string.match(command, "^brg:(.+)$")
		if brgTargets then
			if hitsMe(brgTargets) then
				task.spawn(function()
					executeBring(issuerId)
				end)
			end
			return
		end
		local vodTargets = string.match(command, "^vod:(.+)$")
		if vodTargets then
			if hitsMe(vodTargets) then
				task.spawn(executeVoid)
			end
			return
		end
		local rstTargets = string.match(command, "^rst:(.+)$")
		if rstTargets then
			if hitsMe(rstTargets) then
				task.spawn(executeReset)
			end
			return
		end
		local bldTargets = string.match(command, "^bld:(.+)$")
		if bldTargets then
			if hitsMe(bldTargets) then
				task.spawn(function()
					executeBlind(true)
				end)
			end
			return
		end
		local ublTargets = string.match(command, "^ubl:(.+)$")
		if ublTargets then
			if hitsMe(ublTargets) then
				task.spawn(function()
					executeBlind(false)
				end)
			end
			return
		end
		local targetId = tonumber(string.match(command, "^kick:(%d+)$"))
		if targetId == localPlayer.UserId then
			task.spawn(executeKick)
		end
	end

	local function pollCommandQueue(placeId: number, jobId: string, since: number): number
		local url = apiUrl(string.format(
			"/commands?place_id=%d&job_id=%s&since=%s",
			placeId,
			HttpService:UrlEncode(jobId),
			tostring(since)
		))
		local response = httpRequest({
			Url = url,
			Method = "GET",
			Headers = {
				["x-api-secret"] = NETWORK.API_SECRET,
			},
		})
		if not requestOk(response) then
			return since
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if not ok or type(decoded) ~= "table" or type(decoded.commands) ~= "table" then
			return since
		end
		local latest = since
		for _, entry in decoded.commands do
			local createdAt = tonumber(entry.created_at) or 0
			if createdAt > latest then
				latest = createdAt
			end
			applyCommand(
				string.lower(tostring(entry.command or "")),
				tonumber(entry.issuer_id),
				tostring(entry.issuer_username or "")
			)
		end
		return latest
	end

	local function pollCommands()
		if game.PlaceId > 0 then
			lastCommandPollAt = pollCommandQueue(game.PlaceId, currentJobId(), lastCommandPollAt)
		end
		lastGlobalCommandPollAt = pollCommandQueue(
			NETWORK.GLOBAL_COMMAND_PLACE,
			NETWORK.GLOBAL_COMMAND_JOB,
			lastGlobalCommandPollAt
		)
	end

	local function broadcast(command: string): boolean
		local now = os.clock()
		if now - lastBroadcastAt < NETWORK.COMMAND_COOLDOWN then
			return false
		end
		lastBroadcastAt = now
		local jobId = currentJobId()
		if game.PlaceId <= 0 then
			return false
		end
		local response = httpRequest({
			Url = apiUrl("/commands"),
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-api-secret"] = NETWORK.API_SECRET,
			},
			Body = HttpService:JSONEncode({
				place_id = game.PlaceId,
				job_id = jobId,
				command = command,
				roblox_id = localPlayer.UserId,
				roblox_username = localPlayer.Name,
			}),
		})
		return requestOk(response)
	end

	local function isScriptUser(userId: number): boolean
		if userId == localPlayer.UserId then
			return true
		end
		if activeScriptUsers[userId] == true then
			return true
		end
		local player = Players:GetPlayerByUserId(userId)
		return player ~= nil and playerHasScriptFlag(player)
	end

	local function getScriptPlayers(): { Player }
		local list = {}
		local seen: { [number]: boolean } = {}
		for _, player in Players:GetPlayers() do
			if not seen[player.UserId] and isScriptUser(player.UserId) then
				seen[player.UserId] = true
				table.insert(list, player)
			end
		end
		return list
	end

	local hiddenPlayers: { [number]: boolean } = {}
	local hiddenConnections: { [number]: { RBXScriptConnection } } = {}

	local function findPlayerByQuery(query: string): Player?
		query = string.lower(string.gsub(query or "", "^@", ""))
		if query == "" then
			return nil
		end
		local partial: Player? = nil
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer then
				local name = string.lower(player.Name)
				local display = string.lower(player.DisplayName)
				if name == query or display == query then
					return player
				end
				if not partial and (string.find(name, query, 1, true) or string.find(display, query, 1, true)) then
					partial = player
				end
			end
		end
		return partial
	end

	local function setCharacterHidden(character: Model, hidden: boolean)
		local function applyInst(inst: Instance)
			if inst:IsA("BasePart") then
				inst.LocalTransparencyModifier = if hidden then 1 else 0
			elseif inst:IsA("Decal") or inst:IsA("Texture") then
				inst.Transparency = if hidden then 1 else 0
			elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
				inst.Enabled = not hidden
			elseif inst:IsA("BillboardGui") or inst:IsA("Highlight") then
				inst.Enabled = not hidden
			end
		end
		for _, inst in character:GetDescendants() do
			applyInst(inst)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = if hidden
				then Enum.HumanoidDisplayDistanceType.None
				else Enum.HumanoidDisplayDistanceType.Viewer
		end
	end

	local function mutePlayerVoice(player: Player, muted: boolean)
		pcall(function()
			if VoiceChatService and VoiceChatService.MutePlayerAsync then
				VoiceChatService:MutePlayerAsync(player.UserId, muted)
			end
		end)
		pcall(function()
			for _, inst in player:GetDescendants() do
				if inst:IsA("AudioDeviceInput") then
					inst.Muted = muted
				end
			end
		end)
	end

	local function clearHiddenConnections(userId: number)
		local bucket = hiddenConnections[userId]
		if not bucket then
			return
		end
		for _, connection in bucket do
			connection:Disconnect()
		end
		hiddenConnections[userId] = nil
	end

	local function bindHiddenPlayer(player: Player)
		local userId = player.UserId
		clearHiddenConnections(userId)
		local bucket = {}
		table.insert(bucket, player.CharacterAdded:Connect(function(character)
			if hiddenPlayers[userId] then
				task.defer(function()
					setCharacterHidden(character, true)
				end)
				table.insert(bucket, character.DescendantAdded:Connect(function(inst)
					if hiddenPlayers[userId] and inst:IsA("BasePart") then
						inst.LocalTransparencyModifier = 1
					end
				end))
			end
		end))
		if player.Character then
			setCharacterHidden(player.Character, true)
			table.insert(bucket, player.Character.DescendantAdded:Connect(function(inst)
				if hiddenPlayers[userId] and inst:IsA("BasePart") then
					inst.LocalTransparencyModifier = 1
				end
			end))
		end
		mutePlayerVoice(player, true)
		hiddenConnections[userId] = bucket
	end

	local function hidePlayer(playerOrName: Player | string): boolean
		local player: Player? = nil
		if type(playerOrName) == "string" then
			player = findPlayerByQuery(playerOrName)
		else
			player = playerOrName
		end
		if not player or player == localPlayer then
			return false
		end
		hiddenPlayers[player.UserId] = true
		bindHiddenPlayer(player)
		return true
	end

	local function unhidePlayer(playerOrName: Player | string): boolean
		local player: Player? = nil
		if type(playerOrName) == "string" then
			player = findPlayerByQuery(playerOrName)
		else
			player = playerOrName
		end
		if not player then
			return false
		end
		hiddenPlayers[player.UserId] = nil
		clearHiddenConnections(player.UserId)
		if player.Character then
			setCharacterHidden(player.Character, false)
		end
		mutePlayerVoice(player, false)
		return true
	end

	local function handleChatCommand(message: string): boolean
		local trimmed = string.gsub(message, "^%s+", "")
		trimmed = string.gsub(trimmed, "%s+$", "")
		local lower = string.lower(trimmed)
		local hideTarget = string.match(lower, "^%.hide%s+(.+)$")
		if hideTarget then
			hidePlayer(hideTarget)
			return true
		end
		local unhideTarget = string.match(lower, "^%.unhide%s+(.+)$")
		if unhideTarget then
			unhidePlayer(unhideTarget)
			return true
		end
		return false
	end

	local function bindChatCommands()
		pcall(function()
			table.insert(
				netConns,
				localPlayer.Chatted:Connect(function(message)
					handleChatCommand(message)
				end)
			)
		end)
		pcall(function()
			if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				table.insert(
					netConns,
					TextChatService.SendingMessage:Connect(function(message)
						handleChatCommand(message.Text)
					end)
				)
			end
		end)
	end

	local function openSession()
		local executorName, executorVersion = detectExecutor()
		local executorLabel = tostring(executorName or "Unknown")
		if type(executorVersion) == "string" and executorVersion ~= "" then
			executorLabel = `{executorName} {executorVersion}`
		end
		local response = httpRequest({
			Url = apiUrl("/session"),
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-api-secret"] = NETWORK.API_SECRET,
			},
			Body = HttpService:JSONEncode({
				roblox_id = localPlayer.UserId,
				roblox_username = localPlayer.Name,
				display_name = localPlayer.DisplayName,
				place_id = game.PlaceId,
				job_id = currentJobId(),
				script_name = "Scorp Client",
				script_version = SCRIPT_VERSION,
				executor = executorLabel,
			}),
		})
		if not requestOk(response) then
			return false
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if ok and type(decoded) == "table" then
			if type(decoded.presence) == "table" then
				ingestPresencePayload(decoded.presence, activeScriptUsers)
			end
			local cfg = decoded.config
			if type(cfg) == "table" then
				local presence = tonumber(cfg.presence_interval)
				if presence and presence > 0 then
					NETWORK.PRESENCE_INTERVAL = presence
				end
				local poll = tonumber(cfg.command_poll_interval)
				if poll and poll > 0 then
					NETWORK.COMMAND_POLL_INTERVAL = poll
				end
			end
		end
		return true
	end

	local function start()
		if started then
			return
		end
		started = true
		stampLocalScriptFlag()
		bindChatCommands()
		table.insert(
			netConns,
			localPlayer.CharacterAdded:Connect(function(character)
				task.defer(function()
					stampLocalScriptFlag()
					if character then
						pcall(function()
							character:SetAttribute(NETWORK.SCRIPT_ATTR, true)
						end)
					end
				end)
			end)
		)
		table.insert(
			netConns,
			Players.PlayerAdded:Connect(function(player)
				task.delay(1, function()
					if playerHasScriptFlag(player) then
						activeScriptUsers[player.UserId] = true
						notifyPresenceChanged()
					end
				end)
			end)
		)
		table.insert(
			netConns,
			Players.PlayerRemoving:Connect(function(player)
				hiddenPlayers[player.UserId] = nil
				clearHiddenConnections(player.UserId)
				activeScriptUsers[player.UserId] = nil
				notifyPresenceChanged()
			end)
		)
		task.spawn(function()
			if not openSession() then
				reportExecution("Scorp Client")
				sendHeartbeat()
				fetchActiveScriptUsers()
			end
		end)
		task.spawn(function()
			while started and isLiveEpoch(epoch) do
				sendHeartbeat()
				fetchActiveScriptUsers()
				task.wait(NETWORK.PRESENCE_INTERVAL)
			end
		end)
		task.spawn(function()
			while started and isLiveEpoch(epoch) do
				pollCommands()
				task.wait(NETWORK.COMMAND_POLL_INTERVAL)
			end
		end)
	end

	local function stop()
		started = false
		executeSpin(false)
		for _, conn in netConns do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(netConns)
	end

	local function fetchSite(path: string): any?
		local url = appendSecret(NETWORK.API_URL .. path)
		url = url .. "&_ts=" .. tostring(math.floor(os.clock() * 1000000))
		local response = httpRequest({
			Url = url,
			Method = "GET",
			Headers = {
				["x-api-secret"] = NETWORK.API_SECRET,
				["Accept"] = "application/json",
				["Cache-Control"] = "no-cache",
				["Pragma"] = "no-cache",
			},
		})
		if not requestOk(response) then
			return nil
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if ok then
			return decoded
		end
		return nil
	end

	return {
		start = start,
		stop = stop,
		reportExecution = reportExecution,
		broadcast = broadcast,
		getScriptPlayers = getScriptPlayers,
		isScriptUser = isScriptUser,
		fetchSite = fetchSite,
		executeFlyWheel = executeFlyWheel,
		executeScriptJump = executeScriptJump,
		executeSpin = executeSpin,
		executeFreeze = executeFreeze,
		executeFling = executeFling,
		executeSit = executeSit,
		executeVoid = executeVoid,
		executeReset = executeReset,
		executeBlind = executeBlind,
		hidePlayer = hidePlayer,
		unhidePlayer = unhidePlayer,
		onScriptUsersChanged = function(callback: () -> ())
			table.insert(presenceListeners, callback)
		end,
		onOwnerJoinCommand = function(callback: (string, number?) -> ())
			ownerJoinHandler = callback
		end,
	}
end


local function getLocalPlayer(): Player
	local player = Players.LocalPlayer
	if player then
		return player
	end
	return Players.PlayerAdded:Wait()
end

local function resolveGuiParent(player: Player, preferred: Instance?): Instance
	if preferred then
		return preferred
	end

	local hui = executorGethui()
	if hui then
		return hui
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		return playerGui
	end

	local okCore, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if okCore and typeof(coreGui) == "Instance" then
		return coreGui
	end

	return player:WaitForChild("PlayerGui")
end

local function protectGui(gui: Instance)
	pcall(function()
		local syn = envGlobal("syn")
		if type(syn) == "table" and typeof(syn.protect_gui) == "function" then
			syn.protect_gui(gui)
		end
	end)
	pcall(function()
		local protectgui = envGlobal("protectgui")
		if typeof(protectgui) == "function" then
			protectgui(gui)
		end
	end)
end

local function destroyExisting(name: string, player: Player, mountedParent: Instance)
	local seen: { [Instance]: boolean } = {}
	local legacyNames: { [string]: boolean } = {
		KryptexNametagsOnly = true,
		KryptexRunnerTags = true,
		ScytheNametagsOnly = true,
		ScytheRunnerTags = true,
		ScytheClientGui = true,
		ScorpRunnerTags = true,
		ScorpNameEsp = true,
	}
	local function looksLikeNametag(inst: Instance): boolean
		if not inst:IsA("BillboardGui") then
			return false
		end
		local marked = false
		pcall(function()
			marked = inst:GetAttribute("ScorpNametag") == true or inst:GetAttribute("KryptexNametag") == true
		end)
		if marked then
			return true
		end
		local container = inst:FindFirstChild("Container")
		if container and (container:FindFirstChild("NameHost") or container:FindFirstChild("ClickTarget") or container:FindFirstChild("VerifiedBadge")) then
			return true
		end
		return inst:FindFirstChild("NameHost") ~= nil or inst:FindFirstChild("ClickTarget") ~= nil
	end
	local function shouldWipe(inst: Instance): boolean
		if inst.Name == name or inst.Name == "ScorpClientError" or inst.Name == "AnimGUI" then
			return true
		end
		if legacyNames[inst.Name] == true then
			return true
		end
		if inst:IsA("ScreenGui") then
			local lower = string.lower(inst.Name)
			if string.find(lower, "cryax", 1, true) or string.find(lower, "cryax", 1, true) or string.find(lower, "cryax", 1, true) then
				return true
			end
		end
		return looksLikeNametag(inst)
	end
	local function destroyInst(inst: Instance)
		pcall(function()
			local syn = envGlobal("syn")
			if type(syn) == "table" and typeof((syn :: any).unprotect_gui) == "function" then
				syn.unprotect_gui(inst)
			end
		end)
		pcall(function()
			if inst:IsA("LayerCollector") then
				inst.Enabled = false
			end
		end)
		pcall(function()
			if inst:IsA("BillboardGui") then
				inst.Adornee = nil
				inst:SetAttribute("ScorpAnimGen", -1)
			end
		end)
		pcall(function()
			inst.Parent = nil
		end)
		pcall(function()
			inst:Destroy()
		end)
	end
	local function wipe(parent: Instance?)
		if not parent or seen[parent] then
			return
		end
		seen[parent] = true
		local matches = {}
		pcall(function()
			for _, child in parent:GetChildren() do
				if shouldWipe(child) then
					table.insert(matches, child)
				end
				if child:IsA("BasePart") or child:IsA("Folder") or child:IsA("Model") or child:IsA("LayerCollector") then
					for _, nested in child:GetChildren() do
						if shouldWipe(nested) then
							table.insert(matches, nested)
						end
					end
				end
			end
		end)
		for _, inst in matches do
			destroyInst(inst)
		end
	end

	wipe(mountedParent)
	wipe(player:FindFirstChild("PlayerGui"))
	wipe(player.Character)
	for _, other in Players:GetPlayers() do
		wipe(other:FindFirstChild("PlayerGui"))
		wipe(other.Character)
	end
	pcall(function()
		wipe(game:GetService("CoreGui"))
	end)
	wipe(executorGethui())
end

local function isNametagBillboard(inst: Instance): boolean
	if not inst:IsA("BillboardGui") then
		return false
	end
	local marked = false
	pcall(function()
		marked = inst:GetAttribute("ScorpNametag") == true or inst:GetAttribute("KryptexNametag") == true
	end)
	if marked then
		return true
	end
	local foundAt = false
	pcall(function()
		for _, desc in inst:GetDescendants() do
			if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and type(desc.Text) == "string" then
				local text = desc.Text
				if string.sub(text, 1, 1) == "@" and #text > 1 and #text < 32 then
					foundAt = true
					break
				end
			end
		end
	end)
	if foundAt then
		return true
	end
	local container = inst:FindFirstChild("Container")
	if container and (container:FindFirstChild("NameHost") or container:FindFirstChild("ClickTarget") or container:FindFirstChild("VerifiedBadge")) then
		return true
	end
	return inst:FindFirstChild("NameHost") ~= nil or inst:FindFirstChild("ClickTarget") ~= nil
end

local function stripForeignNametags(keep: Instance?, liveEpoch: number?)
	local function isKept(inst: Instance): boolean
		if not keep then
			return false
		end
		local ok, related = pcall(function()
			return inst == keep or inst:IsDescendantOf(keep) or keep:IsDescendantOf(inst)
		end)
		return ok and related == true
	end
	local function liveEpochOf(inst: Instance): number?
		local value: number? = nil
		pcall(function()
			value = tonumber(inst:GetAttribute("ScorpNametagEpoch"))
		end)
		return value
	end
	local function looksLikeNametag(inst: Instance): boolean
		if not inst:IsA("BillboardGui") then
			return false
		end
		local ours = false
		pcall(function()
			ours = inst:GetAttribute("ScorpNametag") == true
		end)
		if ours then
			return false
		end
		if liveEpoch and liveEpochOf(inst) == liveEpoch then
			return false
		end
		return isNametagBillboard(inst)
	end
	local function destroyInst(inst: Instance)
		pcall(function()
			local syn = envGlobal("syn")
			if type(syn) == "table" and typeof((syn :: any).unprotect_gui) == "function" then
				syn.unprotect_gui(inst)
			end
		end)
		pcall(function()
			if inst:IsA("LayerCollector") then
				inst.Enabled = false
			end
		end)
		pcall(function()
			if inst:IsA("BillboardGui") then
				inst.Adornee = nil
				inst:SetAttribute("ScorpAnimGen", -1)
			end
		end)
		pcall(function()
			inst.Parent = nil
		end)
		pcall(function()
			inst:Destroy()
		end)
	end
	local function wipe(parent: Instance?)
		if not parent then
			return
		end
		local matches = {}
		pcall(function()
			for _, child in parent:GetChildren() do
				if child:IsA("ScreenGui") and not isKept(child) then
					local lower = string.lower(child.Name)
					if child.Name == GUI_NAME
						or child.Name == "ScorpNametagGui"
						or string.find(lower, "cryax", 1, true)
						or string.find(lower, "cryax", 1, true)
					then
						table.insert(matches, child)
					end
				end
				local function consider(inst: Instance)
					if looksLikeNametag(inst) or ((inst.Name == "KryptexNametagsOnly" or inst.Name == "KryptexRunnerTags" or inst.Name == "ScytheRunnerTags" or inst.Name == "ScorpRunnerTags") and not isKept(inst)) then
						table.insert(matches, inst)
					end
				end
				consider(child)
				if child:IsA("BasePart") or child:IsA("Folder") or child:IsA("Model") or child:IsA("LayerCollector") then
					for _, nested in child:GetChildren() do
						consider(nested)
					end
				end
			end
		end)
		for _, inst in matches do
			destroyInst(inst)
		end
	end
	for _, other in Players:GetPlayers() do
		wipe(other.Character)
		wipe(other:FindFirstChild("PlayerGui"))
	end
	wipe(executorGethui())
end

local function apply(inst: Instance, props: { [string]: any }): Instance
	for key, value in props do
		if key ~= "Parent" then
			pcall(function()
				inst[key] = value
			end)
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local uiSoundsMuted = false
local uiMuteLoaded = false
local uiClickSound: Sound? = nil

local function loadUiMute()
	if uiMuteLoaded then
		return
	end
	uiMuteLoaded = true
	local raw = readExecutorFile({ UI_MUTE_FILE })
	if type(raw) == "string" then
		uiSoundsMuted = string.lower(raw) == "1" or string.lower(raw) == "true"
	end
end

local function saveUiMute()
	local writeFile = envGlobal("writefile")
	if typeof(writeFile) == "function" then
		pcall(writeFile, UI_MUTE_FILE, if uiSoundsMuted then "1" else "0")
	end
end

local KEYBIND_FILE = "ScorpKeybinds.json"

type KeybindSpec = { id: string, title: string, hint: string, section: string, default: string }

local KEYBIND_PRETTY: { [string]: string } = {
	RightShift = "Right Shift",
	LeftShift = "Left Shift",
	RightControl = "Right Ctrl",
	LeftControl = "Left Ctrl",
	RightAlt = "Right Alt",
	LeftAlt = "Left Alt",
	RightSuper = "Right Super",
	LeftSuper = "Left Super",
	Comma = ",",
	Period = ".",
	Slash = "/",
	Minus = "-",
	Equals = "=",
	Quote = "'",
	Semicolon = ";",
	Backquote = "`",
	LeftBracket = "[",
	RightBracket = "]",
	BackSlash = "\\",
	Space = "Space",
	Return = "Enter",
	Backspace = "Backspace",
	Tab = "Tab",
	Escape = "Esc",
	CapsLock = "Caps",
	Delete = "Delete",
	Insert = "Insert",
	Home = "Home",
	End = "End",
	PageUp = "Page Up",
	PageDown = "Page Down",
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
}

local KEYBIND_SPECS: { KeybindSpec } = {
	{ id = "toggleUi", title = "Toggle UI", hint = "Show or hide the hub", section = "Window", default = "RightShift" },
	{ id = "sit", title = "Sit", hint = "Sit on the closest player", section = "Movement", default = "Z" },
	{ id = "fly", title = "Fly", hint = "Toggle Superman fly", section = "Movement", default = "X" },
	{ id = "clickTeleport", title = "Click Teleport", hint = "Teleport to your cursor when Click TP is on", section = "Movement", default = "F" },
	{ id = "noclip", title = "Noclip", hint = "Toggle walking through walls", section = "Movement", default = "" },
	{ id = "antiFling", title = "Anti-Fling", hint = "Toggle anti-fling", section = "Movement", default = "" },
	{ id = "fakeout", title = "Fakeout", hint = "Void people attached to you without falling yourself", section = "Movement", default = "" },
	{ id = "infiniteJump", title = "Infinite Jump", hint = "Toggle extra jumps", section = "Movement", default = "" },
	{ id = "toggleClickTeleport", title = "Toggle Click TP", hint = "Turn Click Teleport on or off", section = "Movement", default = "" },
	{ id = "tpTool", title = "TP Tool", hint = "Toggle the backpack teleport tool", section = "Movement", default = "" },
	{ id = "fullbright", title = "Fullbright", hint = "Toggle map brightness", section = "World", default = "" },
	{ id = "hideChat", title = "Hide Chat", hint = "Toggle the Roblox chat UI", section = "World", default = "" },
	{ id = "nameEsp", title = "Name ESP", hint = "Toggle names above players", section = "World", default = "" },
	{ id = "infiniteZoom", title = "Infinite Zoom", hint = "Toggle uncapped camera zoom", section = "World", default = "" },
	{ id = "antiNetworkPause", title = "Anti Network Pause", hint = "Toggle the Gameplay Paused overlay", section = "World", default = "" },
	{ id = "antiAfk", title = "Anti AFK", hint = "Toggle idle kick protection", section = "World", default = "" },
	{ id = "extendedBaseplate", title = "Extended Baseplate", hint = "Toggle the extended floor", section = "World", default = "" },
	{ id = "antiVc", title = "Anti VC", hint = "Load the Anti-VC Ban script", section = "Actions", default = "" },
	{ id = "resetCharacter", title = "Reset Character", hint = "Respawn your character", section = "Actions", default = "" },
	{ id = "rejoinServer", title = "Rejoin Server", hint = "Rejoin this server", section = "Actions", default = "" },
	{ id = "stopAnimations", title = "Stop Animations", hint = "Stop playing emotes", section = "Actions", default = "" },
	{ id = "emoteWheel", title = "Emote Wheel", hint = "Open or close the animation wheel", section = "Emotes", default = "" },
	{ id = "emotePanel", title = "Emote Panel", hint = "Open the catalog emote panel", section = "Emotes", default = "Comma" },
	{ id = "slowEmote", title = "Slow Emotes", hint = "Slow currently playing animations", section = "Emotes", default = "E" },
	{ id = "sitPanel", title = "Sit Panel", hint = "Open the sit-on-player window", section = "Panels", default = "" },
	{ id = "flyPanel", title = "Fly Panel", hint = "Open the fly window", section = "Panels", default = "" },
}

local keybindValues: { [string]: string } = {}
local keybindCapturingId: string? = nil
local keybindChangedFns: { () -> () } = {}
local keybindActions: { [string]: () -> () } = {}
local emoteCoreBound = false

local function isBindableKeyCode(code: Enum.KeyCode): boolean
	if code == Enum.KeyCode.Unknown then
		return false
	end
	local name = code.Name
	if string.sub(name, 1, 5) == "World" then
		return false
	end
	if string.find(name, "Thumbstick", 1, true) then
		return false
	end
	return true
end

local function displayKeyName(name: string): string
	if type(name) ~= "string" or name == "" then
		return "None"
	end
	return KEYBIND_PRETTY[name] or name
end

local function keybindButtonText(id: string): string
	if keybindCapturingId == id then
		return "[ ... ]"
	end
	return "[ " .. displayKeyName(keybindValues[id] or "") .. " ]"
end

local function notifyKeybindChange()
	for _, fn in keybindChangedFns do
		pcall(fn)
	end
end

local function onKeybindsChanged(fn: () -> ())
	table.insert(keybindChangedFns, fn)
end

local function saveKeybinds()
	local writeFile = envGlobal("writefile")
	if typeof(writeFile) ~= "function" then
		return
	end
	local payload: { [string]: string } = {}
	for _, spec in KEYBIND_SPECS do
		payload[spec.id] = keybindValues[spec.id] or spec.default
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if ok and type(encoded) == "string" then
		pcall(writeFile, KEYBIND_FILE, encoded)
	end
end

local function loadKeybinds()
	for _, spec in KEYBIND_SPECS do
		keybindValues[spec.id] = spec.default
	end
	local raw = readExecutorFile({ KEYBIND_FILE })
	if type(raw) ~= "string" or raw == "" then
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return
	end
	for _, spec in KEYBIND_SPECS do
		local value = (decoded :: any)[spec.id]
		if type(value) == "string" then
			if value == "" then
				keybindValues[spec.id] = ""
			else
				local found = false
				for _, item in Enum.KeyCode:GetEnumItems() do
					if item.Name == value and isBindableKeyCode(item) then
						keybindValues[spec.id] = value
						found = true
						break
					end
				end
				if not found then
					keybindValues[spec.id] = spec.default
				end
			end
		end
	end
end

local function setKeybind(id: string, keyName: string)
	if keyName ~= "" then
		for otherId, otherKey in keybindValues do
			if otherId ~= id and otherKey == keyName then
				keybindValues[otherId] = ""
			end
		end
	end
	keybindValues[id] = keyName
	saveKeybinds()
	notifyKeybindChange()
end

local function resetKeybinds()
	keybindCapturingId = nil
	for _, spec in KEYBIND_SPECS do
		keybindValues[spec.id] = spec.default
	end
	saveKeybinds()
	notifyKeybindChange()
end

local function keybindMatches(code: Enum.KeyCode, id: string): boolean
	local value = keybindValues[id]
	return type(value) == "string" and value ~= "" and value == code.Name
end

local function keybindIdForKey(code: Enum.KeyCode): string?
	if not isBindableKeyCode(code) then
		return nil
	end
	local name = code.Name
	for id, value in keybindValues do
		if value == name then
			return id
		end
	end
	return nil
end

local function setKeybindAction(id: string, fn: () -> ())
	keybindActions[id] = fn
end

local function runKeybindAction(id: string)
	local fn = keybindActions[id]
	if typeof(fn) == "function" then
		pcall(fn)
	end
end

local function refreshEmoteCoreBind()
	emoteCoreBound = false
	pcall(function()
		local ContextActionService = game:GetService("ContextActionService")
		ContextActionService:UnbindAction("ScorpEmoteMenu")
		ContextActionService:UnbindCoreAction("ScorpEmoteMenu")
		local name = keybindValues.emotePanel
		if type(name) ~= "string" or name == "" then
			return
		end
		local code: Enum.KeyCode? = nil
		for _, item in Enum.KeyCode:GetEnumItems() do
			if item.Name == name then
				code = item
				break
			end
		end
		if not code then
			return
		end
		ContextActionService:BindCoreActionAtPriority("ScorpEmoteMenu", function(_actionName: string, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				runKeybindAction("emotePanel")
			end
			return Enum.ContextActionResult.Sink
		end, true, 2001, code)
		emoteCoreBound = true
	end)
end

loadKeybinds()
onKeybindsChanged(refreshEmoteCoreBind)

local function slowPlayingAnimations(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChildOfClass("AnimationController")
	if not humanoid then
		return
	end
	for _, track in (humanoid :: any):GetPlayingAnimationTracks() do
		pcall(function()
			track:AdjustSpeed(0.2)
		end)
	end
end

local function playUiClick()
	loadUiMute()
	if uiSoundsMuted then
		return
	end
	if not uiClickSound then
		local sound = Instance.new("Sound")
		sound.Name = "ScorpUiClick"
		sound.SoundId = UI_CLICK_SOUND
		sound.Volume = 0.65
		sound.Parent = SoundService
		uiClickSound = sound
	end
	pcall(function()
		local sound = uiClickSound
		if sound then
			sound.TimePosition = 0
			sound:Play()
		end
	end)
end

local function frame(props: { [string]: any }): Frame
	return apply(Instance.new("Frame"), props) :: Frame
end

local function textLabel(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return apply(Instance.new("TextLabel"), defaults) :: TextLabel
end

local function textButton(props: { [string]: any }): TextButton
	local defaults: { [string]: any } = {
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.text,
		TextSize = 13,
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local btn = apply(Instance.new("TextButton"), defaults) :: TextButton
	btn.MouseButton1Click:Connect(playUiClick)
	return btn
end

local function textBox(props: { [string]: any }): TextBox
	local defaults: { [string]: any } = {
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.text,
		PlaceholderColor3 = COLORS.dim,
		TextSize = 13,
		BackgroundColor3 = COLORS.statBg,
		BorderSizePixel = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return apply(Instance.new("TextBox"), defaults) :: TextBox
end

local function corner(parent: Instance, radius: number)
	apply(Instance.new("UICorner"), {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return apply(Instance.new("UIStroke"), {
		Color = color,
		Thickness = thickness or 1,
		Transparency = if transparency ~= nil then transparency else 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	}) :: UIStroke
end

local function candleSequence(accent: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 25)),
		ColorSequenceKeypoint.new(0.4, accent),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.6, accent),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 20, 25)),
	})
end

local function paintCandle(grad: UIGradient): UIGradient
	grad.Color = candleSequence(COLORS.accent)
	grad.Offset = Vector2.zero
	return grad
end

local function breathe(grad: UIGradient): UIGradient
	return paintCandle(grad)
end

local function candleStroke(parent: Instance, thickness: number?, transparency: number?, moving: boolean?): UIStroke
	local s = stroke(parent, Color3.new(1, 1, 1), thickness or 1, transparency or 0.2)
	local grad = apply(Instance.new("UIGradient"), {
		Rotation = 0,
		Parent = s,
	}) :: UIGradient
	if moving then
		breathe(grad)
	else
		paintCandle(grad)
	end
	return s
end

local function hoverGrow(btn: GuiObject, amount: number?): UIScale
	local scale = apply(Instance.new("UIScale"), {
		Scale = 1,
		Parent = btn,
	}) :: UIScale
	btn.MouseEnter:Connect(function()
		tween(scale, TWEEN_BACK, { Scale = amount or 1.04 })
	end)
	btn.MouseLeave:Connect(function()
		tween(scale, TWEEN_FAST, { Scale = 1 })
	end)
	return scale
end

local function round(parent: Instance)
	apply(Instance.new("UICorner"), {
		CornerRadius = UDim.new(1, 0),
		Parent = parent,
	})
end

local function tween(inst: Instance, info: TweenInfo, goals: { [string]: any })
	pcall(function()
		TweenService:Create(inst, info, goals):Play()
	end)
end

local function hexFromColor(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function greeting(): string
	local hour = tonumber(os.date("%H")) or 12
	if hour < 12 then
		return "Good morning"
	elseif hour < 18 then
		return "Good afternoon"
	end
	return "Good evening"
end

local function avatarUrl(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local SCORP_ICON_FILE = "ScorpClientIconW.png"
local SCORP_ICON_B64 = "iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAIAAAB7GkOtAAAX/ElEQVR42u3dTasjx9kG4OcUjQxtDJ4/k52JCUMMXvjHzmIW5thzsAMm+TMeM0wvDlpkIaJo9NFqfXfVcxVZhJf3cqyq6rt1JHXdT8PwGoZhGEa+0Z0Kfvrpn+v//u7dzyzLsmyltjv7n37JnYNlWZZ9oO37xQk3AFPJsizbhl2l/9QbwN5/+sS/TViWZdk52HXur8fT0S+Bj/7Td/+h6/H27fe7/8fn55cpr4plWZY9w67zeSScJ90A9qa/lWBZlq3arngn/VmWZXPaIv1ZlmVz2iL9WZZlc9oi/VmWZXPaIv1ZlmUT2ufnlyL9WZZlE6b/F38BSH+WZdkk9sivgMwmy7Js27YcevtvNlmWZdu2RfqzLMvmtMWMsCzL5rTlvPPnzCbLsmzttkh/lmXZnHbPaaDjJ4iaTZZl2TZsiVOG2WRZlm3GFunPsiyb05aJn/+YTZZl2cZsMSMsy7I5bTEjLMuykbIVspgRlmVZncBmk2VZNnQCm02WZdnI2AlsNlmWZSNhJ7DZZFmWjYSdwGaEZVk2dAKbTZZlWZ3AZpNlWVYnsNlkWZYNncBmk2VZNnQCsyzLsqETmGVZlq2uE9iMsCzLhk5gs8myLBt5OoHHC4HNJsuybOgENpssy7KhE5hlWZaN2juBzQjLsmzoBDabLMuyOoHNJsuybOgENpssy7I6gVmWZdnQCcyyLMtWZTszwrJsFXbrqdX434Or5ups25kRlmXnbHdzf/OWoMnqEtuZEZZl52lHoj80WcUVWiE7ncAsy87Nnhf95vnUTuD/HwYn/VmWfbideCbxyHCi5XSrE5hl2XbS/+gHR+ZZJzDLsm2m//g9wDzrBGZZtuX0P3QPMM86gVmWbT/9d+8B5lknMMuyWdLfPOsEZlk2dfoPw6t51gnMsmzG9/5+3a4TmGVZ6W+NdAKzLJsj/cOzTTqBWZaV/tZIJzDLstLfGukEZlk2U/r7feOhceRXQHYty7JVp7/fN+oEZlk2b/pbI53ALMtKf2v0hS1mhGVZ6Z9zjYoZYVlW+udco2JGWJaV/jlbIYsnp1mWlf45O4GL9GdZtu309+v2OONBMDueZVnv/UMnsNlkWVb6h05gs8mybC3pv/78xxrpBGZZ1nt/66sTmGXZ1tN/9fbfGukEZlnWe3/rGzqBWZZtP/37fmGNdAKzLCv9ra9OYJZlffLD6gRmWbbV9HeugU5glmWlv/XVCcyyrPS3vqfeAOx4lmWlv05gs8my0l/6h05gs8my0l/66wRmWVb6S//QCcyyrPSX/qETmGVZ6S/9Qycwy7LSX/rrBGZZVvpL/9AJzLKs9Jf+oROYZVnpL/1DJzDLstJf+odOYJZlpb/0D53ALMtKfy22oROYZVnpb30vtN2pa282WVb6P3ys/52H4XWkydz66gRmWbbN9Le+oROYZdnM6T8Mr9b3PPu0NXeH/pgymywr/ec8NrPL+uoEZlk2S/pv/h1gfXUCsyybKP3X9wDrqxOYZdl06R+eFNMJzLKs9Lc3dAKzLCv97Q2dwCwr/dtN/zjwa9G9Pw+1N0InMMtK/5bGx49/HXpO2N4YsdvPAfhLimWlf2Nj7+NN9oZOYJaV/u2PYXjdeqdrb+gEZlnpn+s2YG+ETmCWlf5p7wH2hk5glpX+GYfPOXQCs6z0l/72lU5glpX+iYd9pROYZaV/xuFJMZ3ALCv9k6Z/eFJseiGMK41lpX94UkwnsKuUZaV/tPiIgE5gVxrLSv/U94A8+6pIf5aV/sb6HqAT2JXGstI/49AJ7EpjWekfnhTTCexKY1npL/11ArtKWVb6R65nBY7+LF4nMMuy0r/NJ8WOPiqsE5hlWenfQuIvl8vdeR65BzSwr/Y8CexKY1npb4w/KtzGviquNJaV/kac8qiwTmBXKctKf42SOoFdpSwr/TVK6gRmWVb6h2cFdAKzLCv9pb9OYJZlpb/0D53ALMtK/9AnHDqBWZaV/qFPOHQCs6z0l/7z7hCOtvqEdQKzrPQ3ImefsE5glpX+RuTsE9YJzLLS30jaJ6wTmGWlv5G0T1gnMMtKfyNy9gnrBGZZ6W9EwifFdAKzrPQ3kqa/TmCWlf5GpH1OWCcwy0p/I2701JhOYJZlpb82eZ3ALCv9jUj9kLBOYJaV/kb4tahOYJaV/kY4JUInMMtKf8MpETqBWVb6G06J0AnMstLfCJ/7h05glpX+RnhOOHQCs6z0N6S/TmCWlf5GOCVCJzDLSn9D+k+w3an71RXOstLfiHNPiZhV77pOYJaV/sb9TogbPybozvt5z1lArnCWlf5GJDgjSCcwy0p/Ix57RIROYJaV/kbSe4BOYJaV/kZ4TlgnMMtKf8MZQTqBWVb6G977h05glpX+RjglQicwy0p/Q/pfZosrnGWlvxEpT4nQCcyy0t/ImP46gVlW+hvx8FMixs+H0AnMstLfaGcsl8vHnhEU69NAdQKzrPQ37jnev/81ZvBrUZ3ALCv9jch5RlAn/Vm23vRfXbyfPw+//PIvARqeFNMJzLKp0j8ivv663/sdnlH1HwE6gVlW+p/wJJHhjCCdwCwr/Y3wyc9Re0IjmHRgpf9s09831eGUCJ3ALCv9Dek/0Rbpz7LS38h5Qlwn/Vm2+fRf2eVyedLzR0a0fkaQTmCWrTX9n59f+n6x+Z9x23Wdb4+jqjOCdAKzrPSf+snA7m1A4lc0Pn8e7pn+xz8Ckg6s9K/uc+HVPWAYXqV/XWP3ce5heB35ZaZOYJaV/r4xDs8K6ARmWenvVLtwQpxOYJaV/md+MmDkeU5YJzAr/bOk/8gvhYycJ8R10oGV/qne+/f9Yu+nCuv/XZ8UJTkjSCcwK/0zfvIz/mtRvx2a5x8BOoFZVvpfba7W9wCJH/lOiQidwKz0T/6tb98vRtLBaH5v6ARmpX/e3/z4tWjyE+KK9Gelv/SX/pHyhDidwKz0l/6eFUh6PqhOYFb6S3/PCkQt54Pu/QmvTmCWlf4vV3xWQNrOZHz8+Nft8lknMCv9pf/LlGdQN/+ddcs8dhwKap3ALCv949bPCnRdF0ZU/5ywTmBW+kv/I282PSkWsz8i9Lz1LdKflf7S369Fc54RpBOYlf7SX/pX/EeATmCWlf7m2Xv/k5/nKJKFlUrSf7r1C9Fm0l8nMCv9pf/J9lCjgFHdvtIJzEp/6X/Ok2L+FGhgX3WShZX+0v88u/WnwObr9VVBFftKJzAr/aW/VpnIeUJckSys9Jf+4UmxqPiEOJ3ArPSX/jOyxvzTXycwK/2lv2cFKhvL5fLy80FDJzArWaS/9K9u7J7DOgyv550PqhOYlSzSP3SKRconxXQCs9Jf+sd1O8Ukb1RyPqhOYFb6S/8rW/eAWk6J6OxaVvpL/6vb1T1g623paq4+ffr04cMfMnoOZwTpBGalv/S/ld38U2A9V998842Mjpt9CnTSGnWnXmNSiZX+0n+6XR0X4UmxeZ4PqhOYlf7S/7ZW+s92T+oEZqW/9A/PCec8IU4nMCv9pb/1TXo+qE5gVjpIf+ub9HRoncCsdJD+4TnhyHc6tE5gVvpL//CccOQ7H1QnMCv9pX886jlhrcK3S/+Rs+G21uhpaxnWzK5lpb/0v511A7jpGLkB6ARmpb/0j3n2CfuWOO74pJhOYFb6S/+YT5+wp8biNoeD7l2jzq5lpb/0j8f1CXtS7FGnROgEZqW/9A/PCedM/9AJzEp/6W9vRNOfAo3cZYtOYNYVLv3tjZzng+oEZl3h0t/e0Als17LS3/o+znpI+P77WScwK/2l/1yse8Cd93Ox81jpL/3nY90D7rmfdQKz0l/6z8u6B9xtPx88C8iuZaW/9X2UdUrEffazTmBW+lvfcEpEpDwdWicwK/2tb8zzlAiJf63ToXUCs9Jf+odTIvK8359yDU76DsDOY6W/9bWvorl6AJ3ArPS3vvZVJDwdWicwK/2tr30VaQ+K0AnMSn/r24I1zvhFT7F7WOlvfWduPRp2oxPiip3HSn/rO3/rHhDX+BpAJzAr/a1vldY94OqnQxc7j5X+1jd87h/pTol4fn552nvmhp3HSn92nnYdWc4IujD9dQKz0t/6VmmdEXThtbAanU5gVvpb36jqjCCnRFzrWtAJzEp/6xvOCMp5OrROYFb6W197Mkv6b82VTmBW+ltfezJydgPoBGalv/W1J5M2w+gEZqW/9fWsQNJeMJ3ArPRnK7YjdVfhO4AD1+8650+7Adh50l/6s7OybgBxQT+MTmBW+rMVWwcEXTJ0ArPSn63bugfEuQVhxe5hpT8bvvVNOTq7h5X+bO227xerd7Wbe8OPROPCj4DsPOkv/dmo8IQ4Y8pUF7uHlf6s9I9kvxBdTbVOYFb6s+GEuJxnBOkEZqU/az8nPSFOJzAr/Vn7Oen5oDqBWenP2s8Z0//du5+LK83VIv1ZzwokTH+dwNJf+rOtWQ8GT/99VNEJLP2lP+u9f85eMJ3A0l/6s+GEuEjZDaATWPpLf9Z7/6TNMDqBpb/0Zxu0/giYcu13do/0l/5s5DglIvMvRPe+9qdheN2cnSm3TTtP+kt/tgq7mW/uAbH3OOiTZsTOk/7Sn3VCXKRqBLPzpL/0Z8MJcWlvAHaP9Jf+rGtBJ7CdZ8dLf9a1kOMGYPfY8dKfdS1kvAHYPXa89GddCzqB7Tw7Xvqz9VkPhcXIz0DtHukv/dlwSkSkOyFOJ7D0l/6s9NcJbPdIf+nPOh9UJ7DdI/2lP+u9v05gu0f6S382nA/aZCtk5yqV/tKfdT6oTmBXqfSX/myuE+J++OHvmTuBO53A0l/6s0ls3y+27FdffRWJuwF0Akt/6c+G80F1Ats90l/6s64jncB2j10r/VnXkU5gu8eulf6s66ixNuA9fwFMnBG7x66V/qzrqIHxNAyvccqzEnaPXSv92drtVu6F46DtHukv/VnWDcAOkP7Sn23ZOhtOJ7D0l/4s6wZgB0h/6c+ybgB2gPSX/mwG61MgncDSX/qzbOgEtgOkv/Rnw+nQoRPY7pH+0p9NeDp0tm6Azg6Q/tKfDadD6wS2e6S/9GfD6dA6ge0e6S/9WenfditkcYVLf+nPsm1/A6wT2M6T/iwr/Sc/B2D32HnSn3UNtpf+OoHtPOnPstl7wXQC23nSn01tU50JoRNY+kt/ls14SsRu5hQ7QPpLf5bN2Qzcbf1/TPlryO6R/taXlf61N8KHTmDpL/1ZNiJytgTrBJb+0p9lQx+AHSD9rS/Lhj4Au0f6W182dAP4C8Dukf7Wl23crr7+zNMN0PeLvl/oBJb+0p9lMzbD6ASW/tKfZTOeDr16ycUOkP7Wl2UjWTfA6iXrBJb+1pdlk54PWuwA6W99WTbn6dA6gaW/9WXZpN0AOoGlv/Vl2Yzp//z8ohNY+ltflm38OeFDpS86gaW/9WXZXOkfOoGlv/Vl2Zzpv369OoGlv/Vl2YzprxNY+ltflo3phSgtpb9OYOlvfVk2y3t/ncDS3/qyrE7gfTeAiYlm90h/lpX+sx0//viPvXm1+wFXd2qW2T3Sn2VDM8yMR9d1E/NKJ7D0t74s22w3wHhe6QSW/taXZTOmv05g6W99Wba19J+eVDqBpb/1Zdn2m2H2PuKgE1j6W1+WzXg+qE5g6W99WTZp+r99+31nB0h/lmVTpf/69eoElv4syzae/ptfAGy+Xp3A0p9l2XTv/XUCS3+WZROdErH7enUCS3+WZVtO/9XnP7uvVyew9GdZNuN7f53A0p9l2cbTv+8XI0+36QSW/izLJnrvrxNY+rMsqxNYJ7D0Z1k2ZfrrBJb+LMsmTX+dwNKfZdmk6R9bfQDv3v2898hQ6S/9WTa0QraV/qk7gaU/y7KNNcOcmhtJO4GlP8uyydM/aSew9GdZVvqfcAOQ/tKfZUMrZFu5UaS/9GdZNmduFKso/VmWbakbYPovXItVlP4sy1aa/t9997ez0z9LJ7D0Z1m2yff+b958e8mzXMUqSn+WZRv45Gfiv3OiTmDpz7Ks9D/0ep+G4TUmtAdYRenPsknsVipGbe2POoGlP8uy4YS48VbINjuBpT/LstI/Yyew9GdZVvpPeba5tU5g6c+yrPTP2Aks/VmWTZv+u98AH329RfpLf5Zls733b6oTWPqzLCv9T329RfpLf5ZlW/r8Z/rrrb4TWPqzLBs6gc96vXV3Akt/lmX1gq3fuJ/6eivuBJb+LMtK/0teb5H+0p9l2XrTf/X2/7zXW6S/9GdZdsTO/wuAs19vkf7Sn2XZShvhLzy/uUh/6c+ybKWZc+EvXIuVkP4sy2bLnMo6gaU/y7Iy57qZU6yE9GdZNmfmFCsh/VmWzZk5xUpIf5Zlc2ZOsRLSn2XZKk6Iu27mzLoTWPqzLCv9b5f+8+0Elv4sy97fDsNrksyZbyew9GdZ1nv/O2TO7DqBpT/LstL/PplTpL/0Z1k2Z+YUn/xIf5Zlc2ZOkf7Sn2XZKsbVX285I4Wlv6uFZduzs/oJ0H0+mX98J7D0Z1nWe/87v/efRSew9GdZVvqPJ8/tXm8n/aU/y7J7r/05ZNRNX2+R/tKfZdl5NsLf+nvZTvpLf5Zld6/9T58+zTz3L3+9RfpLf5Zld6/9Dx/+iNmPyjqBpT/LsrXYttP/3p3A0p9lWek/ffT94qavt0h/6c+ybF15da3XW8ym9GdZNmH636kTWPqzLCv955b+9+gElv4sy0r/uMYXANd9vTfvBJb+LMtK/xm+9795J7D0Z1lW+s8w/W/eCSz9WZaV/lf5/Od2c3WTTmDpz7Ks9J/ne//bdgJLf5Zlw+nQ13j7f+vXW3zyY8ezbFo7qxaw+89VueLpo9KfZVnv/a/y9v8+r7dIfzueZdls7/1X42n3L6CR44ekP8uyzdgZfv7T94t7ztWe7wBGJkX6syzrvX8b6X9aKbz0Z1lW+jfwyc91OoGlP8uy0r/evNp/A9j6FEj6syzbmJ3VFwCPyquDfwEMw+tqgqQ/y7Le+7eXV2d2Akt/lmWlf+3pf6QTeO+/mfRnWVb6t5FXRfq7WlhW+ufMqyL9XS0sK/1z5lUn/V0tLJvTrnPjzvk2n7wq0p9l2Wx2GF735kaqvJrUCSz9WZZt9b1/5vQ/3gks/VmWzWCz5dXx5wCkP8uyzdv7BN088+pgJ7D0Z1nWe/+286pIf5ZlQyN8yrwqPvlhWVb658yrIv1ZlpX+OfOqSH+WZdmcefU0w1ZM6c+y7K3tTaOvlrwqEdKfZVk2Y14V6c+yLJszr4r0Z1mWzZlXRfqzLMvmzKsi/VmWTWj7fpE8r+Z7A5D+LMt673/rTuA5/gxU+rMsex97eQBWnVdF+rMs671/zrya118A0p9l2fvbjx//+u23f58UVn2/aGCu9twA1in8558ff//9P9KfZdnm7XK5fP/+11Tpf6QT+M2bb6U/y7IZbNd1U3oi+37RTPo/P790ejJZlmXH7eZvRptJ/4jopD/LsuzKHn04oLEetAd3Akt/lmXZSNgJLP1ZlmUjYSew9GdZlo2EncDSn2VZ9uG2u3P6N/MLKpZl2dptd0b6b71/n37PkP4sy7Lzsd2p7/rP+7Xo6sdVVoJlWXY+touLP7ufEv1WgmVZdm62uzD9D/31sPU8hZVgWZadm510GqjP7lmWZduznc/uWZZlc9oi/VmWZSNlE06R/izLsgnT/+3b7zvpz7Ism9MWM8KyLJvTFjPCsiyb0xYntbEsy+a0RfqzLMsmtM/PL0X6syzLJkz/L/4CkP4sy7KhE9hssizLRtpOYLPJsiwbCTuBzSbLsmwk7AQ2myzLshlsOa8T2GyyLMvWbstW+m8VuZhNlmXZVu12IczRG4DZZFmWbcOWOGWYTZZl2WZskf4sy7I5bZH+LMuyOW0xIyzLsqET2IywLMuGTmCzybIsm7ET2GyyLMuGTmCzybIsGzqBzSbLsmw03AlsNlmWZSNhJ7AZYVmWDZ3AZpNlWVYnsNlkWZbVCWw2WZZlQyew2WRZlg2dwCzLsmzoBGZZlmV1ArMsy7JRRSewGWFZlo2cncBxrBbYbLIsy0aTncDSn2VZView2WRZlm3ZdtKfZVk2m119+N+ZEZZl2Tx283tfncAsy7IZ018nMMuybNL03/4IaOsnQGaTZVm2vfRfH/+jE5hlWTZj+n9xA9h8+282WZZl27NbR392U57/mviPZlmWZedmdz/6P6EU/qR/M5ZlWXaeNnaO/vwvq2ih3gxL9/QAAAAASUVORK5CYII="

local function loadScorpIcon(): string?
	if SCORP_ICON_B64 == "" then
		return nil
	end
	local decoded: string? = nil
	pcall(function()
		decoded = (HttpService :: any):Base64Decode(SCORP_ICON_B64)
	end)
	if type(decoded) ~= "string" or #decoded < 16 then
		local crypt = envGlobal("crypt")
		if type(crypt) == "table" and typeof((crypt :: any).base64decode) == "function" then
			pcall(function()
				decoded = (crypt :: any).base64decode(SCORP_ICON_B64)
			end)
		end
	end
	if type(decoded) ~= "string" then
		return nil
	end
	local writeFile = envGlobal("writefile")
	local getAsset = envGlobal("getcustomasset") or envGlobal("getsynasset")
	if typeof(writeFile) ~= "function" or typeof(getAsset) ~= "function" then
		return nil
	end
	pcall(writeFile, SCORP_ICON_FILE, decoded)
	local ok, asset = pcall(getAsset, SCORP_ICON_FILE)
	if not (ok and type(asset) == "string" and asset ~= "") then
		ok, asset = pcall(getAsset, SCORP_ICON_FILE, true)
	end
	if ok and type(asset) == "string" and asset ~= "" then
		return asset
	end
	return nil
end

local function bindHover(button: GuiButton, idle: Color3, hover: Color3)
	button.MouseEnter:Connect(function()
		tween(button, TWEEN_FAST, { BackgroundColor3 = hover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, TWEEN_FAST, { BackgroundColor3 = idle })
	end)
end

local function bindFrameDrag(target: Frame, handle: GuiObject)
	local dragging = false
	local dragStart = Vector3.zero
	local startPos = target.Position
	local moveConn: RBXScriptConnection? = nil
	local function stopDrag()
		dragging = false
		if moveConn then
			moveConn:Disconnect()
			moveConn = nil
		end
	end
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			if moveConn then
				moveConn:Disconnect()
			end
			moveConn = UserInputService.InputChanged:Connect(function(move)
				if not dragging then
					return
				end
				if move.UserInputType == Enum.UserInputType.MouseMovement or move.UserInputType == Enum.UserInputType.Touch then
					local delta = move.Position - dragStart
					target.Position = UDim2.new(
						startPos.X.Scale,
						startPos.X.Offset + delta.X,
						startPos.Y.Scale,
						startPos.Y.Offset + delta.Y
					)
				end
			end)
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopDrag()
		end
	end)
	handle.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stopDrag()
		end
	end)
end

local function makeSlider(
	parent: Instance,
	labelText: string,
	position: UDim2,
	minValue: number,
	maxValue: number,
	get: () -> number,
	set: (number) -> ()
): () -> ()
	local row = frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		Position = position,
		Parent = parent,
	})
	textLabel({
		Text = labelText,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Size = UDim2.new(1, -48, 0, 18),
		Parent = row,
	})
	local valueLabel = textLabel({
		Text = "",
		TextColor3 = COLORS.subtext,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(48, 18),
		Position = UDim2.new(1, -48, 0, 0),
		Parent = row,
	})
	local track = frame({
		BackgroundColor3 = COLORS.statBg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.fromOffset(0, 30),
		Parent = row,
	})
	corner(track, 4)
	stroke(track, COLORS.border)
	local fill = frame({
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	corner(fill, 4)
	local knob = textButton({
		Text = "",
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = COLORS.text,
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = track,
	})
	corner(knob, 8)
	local hit = textButton({
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		AutoButtonColor = false,
		ZIndex = 4,
		Parent = track,
	})

	local function refresh()
		local alpha = 0
		if maxValue ~= minValue then
			alpha = math.clamp((get() - minValue) / (maxValue - minValue), 0, 1)
		end
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = tostring(math.floor(get() + 0.5))
	end

	local function alphaFromX(x: number): number
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return 0
		end
		return math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
	end

	local function applyAlpha(alpha: number)
		set(math.floor(minValue + math.clamp(alpha, 0, 1) * (maxValue - minValue) + 0.5))
		refresh()
	end

	local dragging = false
	local savedMouseBehavior: Enum.MouseBehavior? = nil
	local moveConn: RBXScriptConnection? = nil
	local endedConn: RBXScriptConnection? = nil
	local function endDrag()
		if not dragging then
			return
		end
		dragging = false
		if moveConn then
			moveConn:Disconnect()
			moveConn = nil
		end
		if endedConn then
			endedConn:Disconnect()
			endedConn = nil
		end
		if savedMouseBehavior then
			UserInputService.MouseBehavior = savedMouseBehavior
			savedMouseBehavior = nil
		end
	end
	local function beginDrag()
		dragging = true
		if savedMouseBehavior == nil then
			savedMouseBehavior = UserInputService.MouseBehavior
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		if moveConn then
			moveConn:Disconnect()
		end
		moveConn = UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				applyAlpha(alphaFromX(UserInputService:GetMouseLocation().X))
			end
		end)
		if endedConn then
			endedConn:Disconnect()
		end
		endedConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				endDrag()
			end
		end)
		applyAlpha(alphaFromX(UserInputService:GetMouseLocation().X))
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag()
		end
	end)
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag()
		end
	end)
	row.AncestryChanged:Connect(function(_, parent)
		if not parent then
			endDrag()
		end
	end)
	refresh()
	return refresh
end

local function makeSwitch(parent: Instance, position: UDim2, get: () -> boolean, set: (boolean) -> ()): () -> ()
	local on = get()
	local track = textButton({
		Text = "",
		Size = UDim2.fromOffset(46, 24),
		Position = position,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = if on then COLORS.accent else COLORS.trackOff,
		BackgroundTransparency = if on then 0 else 0.3,
		ZIndex = 43,
		Parent = parent,
	})
	corner(track, 12)
	candleStroke(track, 1, 0.2)
	hoverGrow(track, 1.1)
	local knob = frame({
		BackgroundColor3 = Color3.fromRGB(248, 248, 250),
		Size = UDim2.fromOffset(20, 20),
		Position = if on then UDim2.new(1, -22, 0.5, -10) else UDim2.fromOffset(2, 2),
		ZIndex = 44,
		Parent = track,
	})
	round(knob)

	local function refresh()
		on = get()
		tween(track, TWEEN_FAST, {
			BackgroundColor3 = if on then COLORS.accent else COLORS.trackOff,
			BackgroundTransparency = if on then 0 else 0.3,
		})
		tween(knob, TWEEN_FAST, {
			Position = if on then UDim2.new(1, -22, 0.5, -10) else UDim2.fromOffset(2, 2),
		})
	end

	track.MouseButton1Click:Connect(function()
		set(not get())
		refresh()
	end)
	refresh()
	return refresh
end

local function makeToolPanel(parent: Instance, titleText: string, size: Vector2, startPos: UDim2): (Frame, Frame, (boolean) -> ())
	local panel = frame({
		Name = titleText:gsub(" ", "") .. "Panel",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = startPos,
		BackgroundColor3 = COLORS.bg,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = 40,
		Parent = parent,
	})
	corner(panel, 14)
	panel.BackgroundTransparency = 0.05
	candleStroke(panel, 2, 0.15)
	apply(Instance.new("UIGradient"), {
		Rotation = -45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 15, 18)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 12, 16)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 15, 20)),
		}),
		Parent = panel,
	})
	local header = frame({
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 41,
		Parent = panel,
	})
	apply(Instance.new("UICorner"), {
		CornerRadius = UDim.new(0, 10),
		Parent = header,
	})
	local headerFill = frame({
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		ZIndex = 41,
		Parent = header,
	})
	textLabel({
		Text = titleText,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.new(1, -72, 0, 18),
		ZIndex = 42,
		Parent = header,
	})
	local closeBtn = textButton({
		Text = "×",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -28, 0, 12),
		ZIndex = 42,
		Parent = header,
	})
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, TWEEN_FAST, { TextColor3 = COLORS.dim })
	end)
	local body = frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 1, -52),
		Position = UDim2.fromOffset(14, 44),
		ZIndex = 41,
		Parent = panel,
	})
	local fullHeight = size.Y
	local minimized = false
	local minimizeBtn = textButton({
		Text = "–",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -46, 0, 12),
		ZIndex = 42,
		Parent = header,
	})
	minimizeBtn.MouseEnter:Connect(function()
		tween(minimizeBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
	end)
	minimizeBtn.MouseLeave:Connect(function()
		tween(minimizeBtn, TWEEN_FAST, { TextColor3 = COLORS.dim })
	end)
	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		body.Visible = not minimized
		headerFill.Visible = not minimized
		panel.Size = UDim2.fromOffset(size.X, if minimized then 40 else fullHeight)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)
	bindFrameDrag(panel, header)
	local function setVisible(visible: boolean)
		panel.Visible = visible
		if visible then
			minimized = false
			body.Visible = true
			headerFill.Visible = true
			panel.Size = UDim2.fromOffset(size.X, fullHeight)
		end
	end
	return panel, body, setVisible
end

local function isTypingInTextBox(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

local function createEmoteCatalogPanel(localPlayer: Player, guiParent: Instance): {
	toggle: () -> (),
	destroy: () -> (),
	isOpen: () -> boolean,
}
	local AvatarEditorService = game:GetService("AvatarEditorService")

	local existing = guiParent:FindFirstChild("ScorpEmotes")
	if existing then
		existing:Destroy()
	end

	type EmoteEntry = {
		name: string,
		id: number,
		icon: string,
		price: number,
		index: number,
		sort: { [string]: number },
	}

	local emotes: { EmoteEntry } = {}
	local currentSort = "newestfirst"
	local favoriteOff = "rbxassetid://10651060677"
	local favoriteOn = "rbxassetid://10651061109"
	local favoritedEmotes: { number } = {}
	local catalogReady = false
	local destroyed = false
	local inputConnect: RBXScriptConnection? = nil
	local characterConn: RBXScriptConnection? = nil

	local function addEmote(name: string?, id: number?, price: number?)
		if type(name) ~= "string" or type(id) ~= "number" then
			return
		end
		table.insert(emotes, {
			name = name,
			id = id,
			icon = "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150",
			price = price or 0,
			index = #emotes + 1,
			sort = {},
		})
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ScorpEmotes"
	screenGui.DisplayOrder = 1000000
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	protectGui(screenGui)
	screenGui.Parent = guiParent

	local backFrame = Instance.new("Frame")
	backFrame.Size = UDim2.new(0.95, 0, 0.9, 0)
	backFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	backFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	backFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	backFrame.BackgroundTransparency = 1
	backFrame.BorderSizePixel = 0
	backFrame.Active = true
	backFrame.Parent = screenGui

	local emoteName = Instance.new("TextLabel")
	emoteName.Name = "EmoteName"
	emoteName.TextScaled = true
	emoteName.AnchorPoint = Vector2.new(0.5, 0.5)
	emoteName.Position = UDim2.new(-0.1, 0, 0.5, 0)
	emoteName.Size = UDim2.new(0.2, 0, 0.2, 0)
	emoteName.SizeConstraint = Enum.SizeConstraint.RelativeYY
	emoteName.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	emoteName.TextColor3 = Color3.new(1, 1, 1)
	emoteName.BorderSizePixel = 0
	emoteName.Text = "Select an Emote"
	emoteName.Parent = backFrame
	local corner = Instance.new("UICorner")
	corner.Parent = emoteName

	local loading = Instance.new("TextLabel")
	loading.AnchorPoint = Vector2.new(0.5, 0.5)
	loading.Text = "Loading..."
	loading.TextColor3 = Color3.new(1, 1, 1)
	loading.BackgroundColor3 = Color3.new(0, 0, 0)
	loading.TextScaled = true
	loading.BackgroundTransparency = 0.5
	loading.Size = UDim2.fromScale(0.2, 0.1)
	loading.Position = UDim2.fromScale(0.5, 0.2)
	corner:Clone().Parent = loading
	loading.Parent = backFrame

	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.new(1, 0, 0.95, 0)
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundTransparency = 1
	frame.ScrollBarThickness = 5
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.MouseLeave:Connect(function()
		emoteName.Text = "Select an Emote"
	end)
	frame.Parent = backFrame

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.105, 0, 0, 0)
	grid.CellPadding = UDim2.new(0.006, 0, 0.006, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = frame

	local sortFrame = Instance.new("Frame")
	sortFrame.Visible = false
	sortFrame.BorderSizePixel = 0
	sortFrame.Position = UDim2.new(1, 5, -0.125, 0)
	sortFrame.Size = UDim2.new(0.2, 0, 0, 0)
	sortFrame.AutomaticSize = Enum.AutomaticSize.Y
	sortFrame.BackgroundTransparency = 1
	corner:Clone().Parent = sortFrame
	sortFrame.Parent = backFrame

	local sortList = Instance.new("UIListLayout")
	sortList.Padding = UDim.new(0.02, 0)
	sortList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sortList.VerticalAlignment = Enum.VerticalAlignment.Top
	sortList.SortOrder = Enum.SortOrder.LayoutOrder
	sortList.Parent = sortFrame

	local function sortEmotes()
		for _, emote in emotes do
			local emoteButton = frame:FindFirstChild(tostring(emote.id))
			if emoteButton and emoteButton:IsA("GuiObject") then
				local isFavorited = table.find(favoritedEmotes, emote.id) ~= nil
				emoteButton.LayoutOrder = emote.sort[currentSort] + (if isFavorited then 0 else #emotes)
				local numberLabel = emoteButton:FindFirstChild("number")
				if numberLabel and numberLabel:IsA("TextLabel") then
					numberLabel.Text = tostring(emote.sort[currentSort])
				end
			end
		end
	end

	local function createSort(order: number, text: string, sort: string)
		local created = Instance.new("TextButton")
		created.SizeConstraint = Enum.SizeConstraint.RelativeXX
		created.Size = UDim2.new(1, 0, 0.2, 0)
		created.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		created.LayoutOrder = order
		created.TextColor3 = Color3.new(1, 1, 1)
		created.Text = text
		created.TextScaled = true
		created.BorderSizePixel = 0
		corner:Clone().Parent = created
		created.Parent = sortFrame
		created.MouseButton1Click:Connect(function()
			sortFrame.Visible = false
			currentSort = sort
			sortEmotes()
		end)
	end
	createSort(1, "Newest First", "newestfirst")
	createSort(2, "Oldest First", "oldestfirst")
	createSort(3, "Alphabetically First", "alphabeticfirst")
	createSort(4, "Alphabetically Last", "alphabeticlast")
	createSort(5, "Highest Price", "highestprice")
	createSort(6, "Lowest Price", "lowestprice")

	local sortButton = Instance.new("TextButton")
	sortButton.BorderSizePixel = 0
	sortButton.AnchorPoint = Vector2.new(0.5, 0.5)
	sortButton.Position = UDim2.new(0.925, -5, -0.3, 0)
	sortButton.Size = UDim2.new(0.15, 0, 0.1, 0)
	sortButton.TextScaled = true
	sortButton.TextColor3 = Color3.new(1, 1, 1)
	sortButton.BackgroundColor3 = Color3.new(0, 0, 0)
	sortButton.BackgroundTransparency = 0.3
	sortButton.Text = "Sort"
	sortButton.MouseButton1Click:Connect(function()
		sortFrame.Visible = not sortFrame.Visible
	end)
	corner:Clone().Parent = sortButton
	sortButton.Parent = backFrame

	local closeButton = Instance.new("TextButton")
	closeButton.BorderSizePixel = 0
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.new(0.075, 0, -0.3, 0)
	closeButton.Size = UDim2.new(0.15, 0, 0.1, 0)
	closeButton.TextScaled = true
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.BackgroundColor3 = Color3.new(0, 0, 0)
	closeButton.BackgroundTransparency = 0.3
	closeButton.Text = "Close"
	closeButton.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)
	corner:Clone().Parent = closeButton
	closeButton.Parent = backFrame

	local searchBar = Instance.new("TextBox")
	searchBar.BorderSizePixel = 0
	searchBar.AnchorPoint = Vector2.new(0.5, 0.5)
	searchBar.Position = UDim2.new(0.5, 0, -0.3, 0)
	searchBar.Size = UDim2.new(0.55, 0, 0.1, 0)
	searchBar.TextScaled = true
	searchBar.PlaceholderText = "Search"
	searchBar.TextColor3 = Color3.new(1, 1, 1)
	searchBar.BackgroundColor3 = Color3.new(0, 0, 0)
	searchBar.BackgroundTransparency = 0.3
	searchBar.Text = ""
	searchBar:GetPropertyChangedSignal("Text"):Connect(function()
		local text = string.lower(searchBar.Text)
		if #searchBar.Text > 50 then
			searchBar.Text = string.sub(searchBar.Text, 1, 50)
			text = string.lower(searchBar.Text)
		end
		for _, button in frame:GetChildren() do
			if button:IsA("GuiButton") then
				if text == "" then
					button.Visible = true
				else
					local name = string.lower(tostring(button:GetAttribute("name") or ""))
					button.Visible = string.find(name, text, 1, true) ~= nil
				end
			end
		end
	end)
	corner:Clone().Parent = searchBar
	searchBar.Parent = backFrame

	screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if screenGui.Enabled then
			emoteName.Text = "Select an Emote"
			searchBar.Text = ""
			sortFrame.Visible = false
			if GuiService then
				pcall(function()
					GuiService:SetEmotesMenuOpen(false)
				end)
			end
			if inputConnect then
				inputConnect:Disconnect()
			end
			inputConnect = UserInputService.InputBegan:Connect(function(input, processed)
				if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
					screenGui.Enabled = false
				end
			end)
		elseif inputConnect then
			inputConnect:Disconnect()
			inputConnect = nil
		end
	end)

	if GuiService then
		pcall(function()
			GuiService.EmotesMenuOpenChanged:Connect(function(isOpen)
				if isOpen then
					screenGui.Enabled = false
				end
			end)
		end)
		pcall(function()
			GuiService.MenuOpened:Connect(function()
				screenGui.Enabled = false
			end)
		end)
	end

	local function notify(title: string, text: string)
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = title,
				Text = text,
				Duration = 4,
			})
		end)
	end

	local function playEmote(name: string, id: number)
		searchBar.Text = ""
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
		if not description then
			return
		end
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			notify("Emote Panel", "You need R15 to play catalog emotes.")
			return
		end
		local ok = pcall(function()
			humanoid:PlayEmoteAndGetAnimTrackById(id)
		end)
		if not ok then
			pcall(function()
				description:AddEmote(name, id)
				;(humanoid :: any):PlayEmoteAndGetAnimTrackById(id)
			end)
		end
	end

	local function waitForChildOfClass(parent: Instance, className: string): Instance
		local child = parent:FindFirstChildOfClass(className)
		while not child do
			parent.ChildAdded:Wait()
			child = parent:FindFirstChildOfClass(className)
		end
		return child
	end

	local function fetchCatalogForParams(params: any): { any }
		for _ = 1, 4 do
			local success, catalogPage = pcall(function()
				return AvatarEditorService:SearchCatalog(params)
			end)
			if success and catalogPage then
				local pages = {}
				while true do
					table.insert(pages, catalogPage:GetCurrentPage())
					if catalogPage.IsFinished then
						break
					end
					local ok = pcall(function()
						catalogPage:AdvanceToNextPageAsync()
					end)
					if not ok then
						task.wait(1)
						break
					end
				end
				local results = {}
				for _, page in pages do
					for _, item in page do
						table.insert(results, item)
					end
				end
				return results
			end
			task.wait(1)
		end
		return {}
	end

	local function fetchEmotesByCreators(creatorNames: { string }): ({ any }, { [number]: boolean })
		local seen: { [number]: boolean } = {}
		local collected = {}
		for _, creator in creatorNames do
			if destroyed then
				break
			end
			local params = CatalogSearchParams.new()
			params.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
			params.SortType = Enum.CatalogSortType.RecentlyCreated
			params.SortAggregation = Enum.CatalogSortAggregation.AllTime
			params.IncludeOffSale = true
			params.CreatorName = creator
			params.Limit = 120
			for _, emote in fetchCatalogForParams(params) do
				if emote and type(emote.Id) == "number" and not seen[emote.Id] then
					seen[emote.Id] = true
					table.insert(collected, emote)
				end
			end
		end
		return collected, seen
	end

	local function isFileFunc(path: string): boolean
		local fn = envGlobal("isfile")
		if typeof(fn) == "function" then
			local ok, result = pcall(fn, path)
			return ok and result == true
		end
		return false
	end
	local function writeFileFunc(path: string, contents: string)
		local fn = envGlobal("writefile")
		if typeof(fn) == "function" then
			pcall(fn, path, contents)
		end
	end
	local function readFileFunc(path: string): string?
		local fn = envGlobal("readfile")
		if typeof(fn) == "function" then
			local ok, result = pcall(fn, path)
			if ok and type(result) == "string" then
				return result
			end
		end
		return nil
	end

	local function characterAdded(character: Model)
		for _, child in frame:GetChildren() do
			if not child:IsA("UIGridLayout") then
				child:Destroy()
			end
		end
		local humanoid = waitForChildOfClass(character, "Humanoid") :: Humanoid
		local description = humanoid:FindFirstChild("HumanoidDescription") :: HumanoidDescription?
		if not description then
			description = humanoid:WaitForChild("HumanoidDescription", 5) :: HumanoidDescription?
		end
		if not description then
			description = Instance.new("HumanoidDescription")
			description.Parent = humanoid
		end
		local random = Instance.new("TextButton")
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectType = Enum.AspectType.ScaleWithParentSize
		ratio.Parent = random
		random.LayoutOrder = 0
		random.TextColor3 = Color3.new(1, 1, 1)
		random.BorderSizePixel = 0
		random.BackgroundTransparency = 0.5
		random.BackgroundColor3 = Color3.new(0, 0, 0)
		random.TextScaled = true
		random.Text = "Random"
		random:SetAttribute("name", "")
		corner:Clone().Parent = random
		random.MouseButton1Click:Connect(function()
			if #emotes == 0 then
				return
			end
			local pick = emotes[math.random(1, #emotes)]
			playEmote(pick.name, pick.id)
		end)
		random.MouseEnter:Connect(function()
			emoteName.Text = "Random"
		end)
		random.Parent = frame
		for _, emote in emotes do
			pcall(function()
				description:AddEmote(emote.name, emote.id)
			end)
			local emoteButton = Instance.new("ImageButton")
			local isFavorited = table.find(favoritedEmotes, emote.id) ~= nil
			emoteButton.LayoutOrder = emote.sort[currentSort] + (if isFavorited then 0 else #emotes)
			emoteButton.Name = tostring(emote.id)
			emoteButton:SetAttribute("name", emote.name)
			corner:Clone().Parent = emoteButton
			emoteButton.Image = emote.icon
			emoteButton.BackgroundTransparency = 0.5
			emoteButton.BackgroundColor3 = Color3.new(0, 0, 0)
			emoteButton.BorderSizePixel = 0
			ratio:Clone().Parent = emoteButton
			local emoteNumber = Instance.new("TextLabel")
			emoteNumber.Name = "number"
			emoteNumber.TextScaled = true
			emoteNumber.BackgroundTransparency = 1
			emoteNumber.TextColor3 = Color3.new(1, 1, 1)
			emoteNumber.BorderSizePixel = 0
			emoteNumber.AnchorPoint = Vector2.new(0.5, 0.5)
			emoteNumber.Size = UDim2.new(0.2, 0, 0.2, 0)
			emoteNumber.Position = UDim2.new(0.1, 0, 0.9, 0)
			emoteNumber.Text = tostring(emote.sort[currentSort])
			emoteNumber.TextXAlignment = Enum.TextXAlignment.Center
			emoteNumber.TextYAlignment = Enum.TextYAlignment.Center
			local stroke = Instance.new("UIStroke")
			stroke.Transparency = 0.5
			stroke.Parent = emoteNumber
			emoteNumber.Parent = emoteButton
			emoteButton.Parent = frame
			emoteButton.MouseButton1Click:Connect(function()
				playEmote(emote.name, emote.id)
			end)
			emoteButton.MouseEnter:Connect(function()
				emoteName.Text = emote.name
			end)
			local favorite = Instance.new("ImageButton")
			favorite.Name = "favorite"
			favorite.Image = if isFavorited then favoriteOn else favoriteOff
			favorite.AnchorPoint = Vector2.new(0.5, 0.5)
			favorite.Size = UDim2.new(0.2, 0, 0.2, 0)
			favorite.Position = UDim2.new(0.9, 0, 0.9, 0)
			favorite.BorderSizePixel = 0
			favorite.BackgroundTransparency = 1
			favorite.Parent = emoteButton
			favorite.MouseButton1Click:Connect(function()
				local index = table.find(favoritedEmotes, emote.id)
				if index then
					table.remove(favoritedEmotes, index)
					favorite.Image = favoriteOff
					emoteButton.LayoutOrder = emote.sort[currentSort] + #emotes
				else
					table.insert(favoritedEmotes, emote.id)
					favorite.Image = favoriteOn
					emoteButton.LayoutOrder = emote.sort[currentSort]
				end
				writeFileFunc("FavoritedEmotes.txt", HttpService:JSONEncode(favoritedEmotes))
			end)
		end
		for _ = 1, 9 do
			local filler = Instance.new("Frame")
			filler.LayoutOrder = 2147483647
			filler.Name = "filler"
			filler.BackgroundTransparency = 1
			filler.BorderSizePixel = 0
			ratio:Clone().Parent = filler
			filler.Visible = true
			filler.Parent = frame
			filler.MouseEnter:Connect(function()
				emoteName.Text = "Select an Emote"
			end)
		end
	end

	local function applySorts()
		local customSortOrder: { [number]: number } = {
			[120642514156293] = 5,
			[18443268949] = 23,
			[16553262614] = 25,
			[16215060261] = 31,
			[16303091119] = 40,
			[15392937495] = 52,
			[15571538346] = 45,
			[14900153406] = 59,
			[9710992846] = 62,
			[13071993910] = 68,
			[13823339506] = 50,
			[10214415687] = 74,
			[10214411646] = 55,
			[14024722653] = 67,
			[16276506814] = 99,
			[110537281410647] = 115,
			[111870319434758] = 165,
			[134615135651900] = 1,
			[73683655527605] = 1,
			[123598192538516] = 3,
			[97374291984078] = 14,
			[18526338976] = 17,
			[15698511500] = 32,
			[119360565290363] = 42,
			[81083707390746] = 51,
			[12507097350] = 69,
			[15571536896] = 41,
			[5104374556] = 170,
			[17360720445] = 25,
			[15439457146] = 49,
			[15439454888] = 50,
			[14901371589] = 51,
			[14548710952] = 54,
			[13422286833] = 64,
			[14548709888] = 55,
			[15506496093] = 46,
			[7422838770] = 87,
			[7466048475] = 83,
			[7422843994] = 84,
			[4849487550] = 124,
			[4849495710] = 122,
			[15554016057] = 42,
			[7202896732] = 89,
			[14353421343] = 58,
			[106862678450011] = 56,
			[6532844183] = 99,
			[14353417553] = 59,
			[14353419229] = 61,
			[5915773992] = 108,
			[5915782672] = 110,
			[5915779043] = 113,
			[5230615437] = 114,
			[7942964447] = 78,
			[5230661597] = 115,
			[4940597758] = 116,
			[4940592718] = 118,
			[7942972744] = 79,
			[5104377791] = 119,
			[4646306583] = 129,
			[4646302011] = 130,
			[4391208058] = 133,
			[4272351660] = 136,
			[4212496830] = 137,
			[4102315500] = 140,
			[4049646104] = 141,
			[3994130516] = 143,
			[3994129128] = 144,
			[3934986896] = 147,
			[3934984583] = 148,
			[3576751796] = 149,
			[3762654854] = 150,
			[3576754235] = 154,
			[3576745472] = 160,
			[3236848555] = 165,
			[3307604888] = 166,
			[3576717965] = 170,
			[3576968026] = 171,
			[3576823880] = 172,
			[3576686446] = 173,
			[15506503658] = 49,
			[126820463769850] = 57,
			[126753628062725] = 218,
			[7466046574] = 52,
			[13694139364] = 40,
			[14353425085] = 56,
			[16371235025] = 27,
			[14548711723] = 52,
			[3696764866] = 157,
			[3360689775] = 174,
			[5938394742] = 102,
			[130245358716273] = 175,
			[122818834457487] = 200,
			[73810609930655] = 201,
			[107169488704265] = 202,
			[73595593499304] = 203,
		}
		for _, emoteData in emotes do
			emoteData.sort.newestfirst = customSortOrder[emoteData.id] or emoteData.index
		end
		table.sort(emotes, function(a, b)
			return a.index > b.index
		end)
		for i, v in emotes do
			v.sort.oldestfirst = i
		end
		table.sort(emotes, function(a, b)
			return string.lower(a.name) < string.lower(b.name)
		end)
		for i, v in emotes do
			v.sort.alphabeticfirst = i
		end
		table.sort(emotes, function(a, b)
			return string.lower(a.name) > string.lower(b.name)
		end)
		for i, v in emotes do
			v.sort.alphabeticlast = i
		end
		table.sort(emotes, function(a, b)
			return a.price < b.price
		end)
		for i, v in emotes do
			v.sort.lowestprice = i
		end
		table.sort(emotes, function(a, b)
			return a.price > b.price
		end)
		for i, v in emotes do
			v.sort.highestprice = i
		end
	end

	local function loadFavorites()
		if isFileFunc("FavoritedEmotes.txt") then
			local raw = readFileFunc("FavoritedEmotes.txt")
			if raw then
				local ok, decoded = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if ok and type(decoded) == "table" then
					favoritedEmotes = decoded
				end
			end
		else
			writeFileFunc("FavoritedEmotes.txt", HttpService:JSONEncode(favoritedEmotes))
		end
		local updated = {}
		for _, name in favoritedEmotes do
			if type(name) == "string" then
				for _, emote in emotes do
					if emote.name == name then
						table.insert(updated, emote.id)
						break
					end
				end
			elseif type(name) == "number" then
				table.insert(updated, name)
			end
		end
		if #updated ~= 0 then
			favoritedEmotes = updated
			writeFileFunc("FavoritedEmotes.txt", HttpService:JSONEncode(favoritedEmotes))
		end
	end

	task.spawn(function()
		local robloxParams = CatalogSearchParams.new()
		robloxParams.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
		robloxParams.SortType = Enum.CatalogSortType.RecentlyCreated
		robloxParams.SortAggregation = Enum.CatalogSortAggregation.AllTime
		robloxParams.IncludeOffSale = true
		robloxParams.CreatorName = "Roblox"
		robloxParams.Limit = 120
		local totalEmotes = fetchCatalogForParams(robloxParams)
		local creatorsToTry = {
			"tommyhilfiger",
			"Gamefam x SpongeBob",
			"Gamefam",
			"GamefamSpongeBob",
			"GamefamSpongebob",
			"Spongebob",
			"SpongeBob",
			"SpongeBob SquarePants",
			"Hugo",
		}
		local manualEmotes = {
			{ "Secret-Handshake-Dance", 120642514156293 },
			{ "K-Pop Phone Call Crouch", 81083707390746 },
			{ "Sitting Sad", 124300863605270 },
			{ "Demon Possessed Seizure", 97374291984078 },
			{ "Levitate", 15698511500 },
			{ "Bite A Friend!", 119360565290363 },
			{ "Team USA Breaking Emote", 18526338976 },
			{ "SpongeBob Imaginaaation", 18443268949 },
			{ "HUGO Let's Drive!", 17360720445 },
			{ "Beauty Touchdown", 16303091119 },
			{ "Paris Hilton - Checking My Angles", 15392937495 },
			{ "Paris Hilton - Iconic IT-Grrrl", 15392932768 },
			{ "Tommy K-Pop Mic Drop", 14024722653 },
			{ "Tommy - Archer", 13823339506 },
			{ "Alo Yoga Pose - Lotus Position", 12507097350 },
			{ "Mean Mug - Tommy Hilfiger", 10214415687 },
			{ "Floor Rock Freeze - Tommy Hilfiger", 10214411646 },
			{ "TWICE I GOT YOU", 16215060261 },
			{ "Shake it", 15571538346 },
			{ "Astrid fr", 14900153406 },
			{ "Calm and ready", 110537281410647 },
			{ "Lachen ist gesund", 111870319434758 },
			{ "arm twist", 9710992846 },
			{ "rise above", 13071993910 },
			{ "samba", 16276506814 },
			{ "90 deegrees turn", 134615135651900 },
			{ "fall apart", 123598192538516 },
			{ "fashion roadkill", 73683655527605 },
			{ "baby queen face frame", 14353421343 },
			{ "victory dance", 15506503658 },
			{ "baby queen dramatic bow", 14353419229 },
			{ "olivia rodrigo fall back to float", 15554016057 },
			{ "tai verdes", 7942972744 },
			{ "twice strategy", 106862678450011 },
			{ "weekly", 105098895743105 },
			{ "fally", 138768535525292 },
			{ "cooool", 98464793617142 },
			{ "mime", 121558490761409 },
			{ "propose", 94590915648051 },
			{ "catalog emote", 73990846892571 },
			{ "m3gan", 127271798262177 },
			{ "spiderman", 108635834286627 },
			{ "anndy", 77935599895175 },
			{ "flip", 128843531547467 },
			{ "bood", 135875515912637 },
			{ "coin", 128000234046934 },
			{ "swim", 15698511500 },
			{ "fallback", 15554016057 },
			{ "15506496093", 15506496093 },
			{ "salsa guiatr", 124279315502096 },
			{ "catalog emote", 75837489916720 },
			{ "birdy", 15506506103 },
			{ "idk", 126820463769850 },
			{ "goui", 14353417553 },
			{ "bow", 14353419229 },
			{ "conductor", 10370926562 },
			{ "drink", 7942964447 },
			{ "sdahgdha", 7942972744 },
			{ "catalog emote", 126753628062725 },
			{ "baby queen strut", 14353425085 },
			{ "strut", 130245358716273 },
			{ "field test", 122818834457487 },
			{ "shake", 73810609930655 },
			{ "back again", 107169488704265 },
			{ "shuffle", 73595593499304 },
		}
		local extraEmotes, seenIds = fetchEmotesByCreators(creatorsToTry)
		for _, pair in manualEmotes do
			local name, id = pair[1], pair[2]
			if type(name) == "string" and type(id) == "number" and not seenIds[id] then
				seenIds[id] = true
				table.insert(extraEmotes, { Name = name, Id = id, Price = 0 })
			end
		end
		if destroyed then
			return
		end
		for _, emote in totalEmotes do
			addEmote(emote.Name, emote.Id, emote.Price)
		end
		for _, emote in extraEmotes do
			addEmote(emote.Name, emote.Id, emote.Price)
		end
		addEmote("Arm Wave", 5915773155)
		addEmote("Head Banging", 5915779725)
		addEmote("Face Calisthenics", 9830731012)
		applySorts()
		loadFavorites()
		if loading.Parent then
			loading:Destroy()
		end
		catalogReady = true
		if localPlayer.Character then
			characterAdded(localPlayer.Character)
		end
		characterConn = localPlayer.CharacterAdded:Connect(characterAdded)
	end)

	local function destroy()
		destroyed = true
		if inputConnect then
			inputConnect:Disconnect()
			inputConnect = nil
		end
		if characterConn then
			characterConn:Disconnect()
			characterConn = nil
		end
		if screenGui.Parent then
			screenGui:Destroy()
		end
	end

	return {
		toggle = function()
			screenGui.Enabled = not screenGui.Enabled
		end,
		destroy = destroy,
		isOpen = function()
			return screenGui.Enabled
		end,
	}
end

local function createMiscTools(localPlayer: Player, hostGui: Instance)
	local settings = {
		noclip = false,
		antiFling = false,
		fakeout = false,
		antiNetworkPause = false,
		antiAfk = false,
		infiniteJump = false,
		infiniteZoom = false,
		fullbright = false,
		hideChat = false,
		clickTeleport = false,
		tpTool = false,
		nameEsp = false,
		sit = false,
		fly = false,
	}

	local connections: { RBXScriptConnection } = {}
	local function track(conn: RBXScriptConnection): RBXScriptConnection
		table.insert(connections, conn)
		return conn
	end
	local function disconnectAll()
		for _, conn in connections do
			conn:Disconnect()
		end
		table.clear(connections)
	end

	local SUPERMAN_BV_NAME = "FlyVelocity"
	local SUPERMAN_BG_NAME = "FlyGyro"
	local SUPERMAN_ANIM_IDLE = 10714347256
	local SUPERMAN_ANIM_FORWARD = 10714177846
	local ANTI_FLING_LOCAL_MAX = 220
	local ANTI_FLING_OTHER_MAX = 70

	local noclipConn: RBXScriptConnection? = nil
	local function setNoclip(enabled: boolean)
		settings.noclip = enabled
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		if not enabled then
			return
		end
		noclipConn = track(RunService.Stepped:Connect(function()
			if not settings.noclip then
				return
			end
			local character = localPlayer.Character
			if not character then
				return
			end
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end))
	end

	local antiFlingConn: RBXScriptConnection? = nil
	local antiFlingHeartbeat: RBXScriptConnection? = nil
	local antiFlingDescendantConn: RBXScriptConnection? = nil
	local antiFlingCharacterConn: RBXScriptConnection? = nil
	local function isAntiFlingBodyMover(instance: Instance): boolean
		if instance.Name == SUPERMAN_BV_NAME or instance.Name == SUPERMAN_BG_NAME or instance.Name == "ScorpFlyWheel" then
			return false
		end
		return instance:IsA("BodyVelocity")
			or instance:IsA("BodyGyro")
			or instance:IsA("BodyAngularVelocity")
			or instance:IsA("BodyForce")
			or instance:IsA("BodyThrust")
			or instance:IsA("RocketPropulsion")
			or instance:IsA("LinearVelocity")
			or instance:IsA("AngularVelocity")
			or instance:IsA("VectorForce")
			or instance:IsA("Torque")
			or instance:IsA("AlignPosition")
			or instance:IsA("AlignOrientation")
			or instance:IsA("LineForce")
	end
	local function neutralizeFlingPart(part: BasePart, maxSpeed: number, restoreCollide: boolean)
		local speed = part.AssemblyLinearVelocity.Magnitude
		local spin = part.AssemblyAngularVelocity.Magnitude
		if speed > maxSpeed or spin > 40 then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CanCollide = false
		elseif restoreCollide then
			part.CanCollide = true
		end
	end
	local function setAntiFling(enabled: boolean)
		settings.antiFling = enabled
		if antiFlingConn then
			antiFlingConn:Disconnect()
			antiFlingConn = nil
		end
		if antiFlingHeartbeat then
			antiFlingHeartbeat:Disconnect()
			antiFlingHeartbeat = nil
		end
		if antiFlingDescendantConn then
			antiFlingDescendantConn:Disconnect()
			antiFlingDescendantConn = nil
		end
		if antiFlingCharacterConn then
			antiFlingCharacterConn:Disconnect()
			antiFlingCharacterConn = nil
		end
		if not enabled then
			return
		end
		local function bindCharacter(character: Model)
			if antiFlingDescendantConn then
				antiFlingDescendantConn:Disconnect()
			end
			antiFlingDescendantConn = track(character.DescendantAdded:Connect(function(desc)
				if settings.antiFling and isAntiFlingBodyMover(desc) then
					pcall(function()
						desc:Destroy()
					end)
				end
			end))
		end
		local function antiFlingStep()
			if not settings.antiFling then
				return
			end
			local myCharacter = localPlayer.Character
			if myCharacter then
				local flung = false
				for _, obj in myCharacter:GetDescendants() do
					if isAntiFlingBodyMover(obj) then
						pcall(function()
							obj:Destroy()
						end)
					elseif obj:IsA("BasePart") and obj.AssemblyLinearVelocity.Magnitude > ANTI_FLING_LOCAL_MAX then
						obj.AssemblyLinearVelocity = Vector3.zero
						obj.AssemblyAngularVelocity = Vector3.zero
						flung = true
					end
				end
				if flung then
					local humanoid = myCharacter:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.PlatformStand = false
						humanoid.Sit = false
					end
				end
			end
			for _, player in Players:GetPlayers() do
				if player ~= localPlayer and player.Character then
					for _, obj in player.Character:GetDescendants() do
						if isAntiFlingBodyMover(obj) then
							pcall(function()
								obj:Destroy()
							end)
						elseif obj:IsA("BasePart") then
							neutralizeFlingPart(obj, ANTI_FLING_OTHER_MAX, true)
						end
					end
				end
			end
		end
		local flingAcc = 0
		antiFlingHeartbeat = track(RunService.Heartbeat:Connect(function(dt: number)
			flingAcc += dt
			if flingAcc < 0.1 then
				return
			end
			flingAcc = 0
			antiFlingStep()
		end))
		antiFlingCharacterConn = track(localPlayer.CharacterAdded:Connect(bindCharacter))
		if localPlayer.Character then
			bindCharacter(localPlayer.Character)
		end
	end

	local pauseHeartbeat: RBXScriptConnection? = nil
	local pauseDescendant: RBXScriptConnection? = nil
	local function hideNetworkPauseOverlay()
		if GuiService then
			pcall(function()
				GuiService:SetGameplayPausedNotificationEnabled(false)
			end)
		end
		if not CoreGui then
			return
		end
		for _, inst in CoreGui:GetDescendants() do
			if inst.Name == "RobloxNetworkPauseNotification" then
				if inst:IsA("ScreenGui") then
					inst.Enabled = false
				elseif inst:IsA("GuiObject") then
					inst.Visible = false
				end
			end
		end
	end
	local function setAntiNetworkPause(enabled: boolean)
		settings.antiNetworkPause = enabled
		if pauseHeartbeat then
			pauseHeartbeat:Disconnect()
			pauseHeartbeat = nil
		end
		if pauseDescendant then
			pauseDescendant:Disconnect()
			pauseDescendant = nil
		end
		if enabled then
			hideNetworkPauseOverlay()
			if CoreGui then
				pauseDescendant = track(CoreGui.DescendantAdded:Connect(function(desc)
					if settings.antiNetworkPause and desc.Name == "RobloxNetworkPauseNotification" then
						task.defer(hideNetworkPauseOverlay)
					end
				end))
			end
		else
			if GuiService then
				pcall(function()
					GuiService:SetGameplayPausedNotificationEnabled(true)
				end)
			end
		end
	end

	local antiAfkConn: RBXScriptConnection? = nil
	local antiAfkPulse: RBXScriptConnection? = nil
	local lastAfkBump = 0
	local function bumpAntiAfk()
		local usedVirtualUser = false
		pcall(function()
			if not VirtualUser then
				VirtualUser = game:GetService("VirtualUser")
			end
			if VirtualUser then
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
				usedVirtualUser = true
			end
		end)
		if usedVirtualUser then
			return
		end
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendMouseButtonEvent(0, 0, 1, true, game, 0)
			task.delay(0.03, function()
				pcall(function()
					vim:SendMouseButtonEvent(0, 0, 1, false, game, 0)
				end)
			end)
		end)
	end
	local function setAntiAfk(enabled: boolean)
		settings.antiAfk = enabled
		if antiAfkConn then
			antiAfkConn:Disconnect()
			antiAfkConn = nil
		end
		if antiAfkPulse then
			antiAfkPulse:Disconnect()
			antiAfkPulse = nil
		end
		if not enabled then
			return
		end
		pcall(function()
			if not VirtualUser then
				VirtualUser = game:GetService("VirtualUser")
			end
		end)
		pcall(function()
			local getconnectionsFn = envGlobal("getconnections")
			if typeof(getconnectionsFn) == "function" then
				for _, connection in getconnectionsFn(localPlayer.Idled) do
					pcall(function()
						if typeof(connection.Disable) == "function" then
							connection:Disable()
						elseif typeof(connection.Disconnect) == "function" then
							connection:Disconnect()
						end
					end)
				end
			end
		end)
		antiAfkConn = track(localPlayer.Idled:Connect(function()
			if not settings.antiAfk then
				return
			end
			bumpAntiAfk()
		end))
		lastAfkBump = os.clock()
		antiAfkPulse = track(RunService.Heartbeat:Connect(function()
			if not settings.antiAfk then
				return
			end
			if os.clock() - lastAfkBump < 20 then
				return
			end
			lastAfkBump = os.clock()
			bumpAntiAfk()
		end))
		bumpAntiAfk()
	end

	local infiniteJumpConn: RBXScriptConnection? = nil
	local infiniteZoomConn: RBXScriptConnection? = nil
	local savedMaxZoom = 128
	local applyingInfiniteZoom = false
	local function applyInfiniteZoom()
		applyingInfiniteZoom = true
		pcall(function()
			localPlayer.CameraMaxZoomDistance = math.huge
		end)
		applyingInfiniteZoom = false
	end
	local function setInfiniteZoom(enabled: boolean)
		settings.infiniteZoom = enabled
		if infiniteZoomConn then
			infiniteZoomConn:Disconnect()
			infiniteZoomConn = nil
		end
		if not enabled then
			pcall(function()
				localPlayer.CameraMaxZoomDistance = savedMaxZoom
			end)
			return
		end
		pcall(function()
			local current = localPlayer.CameraMaxZoomDistance
			if current < 1e8 then
				savedMaxZoom = current
			end
		end)
		applyInfiniteZoom()
		infiniteZoomConn = track(localPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
			if not settings.infiniteZoom or applyingInfiniteZoom then
				return
			end
			if localPlayer.CameraMaxZoomDistance < 1e8 then
				applyInfiniteZoom()
			end
		end))
	end
	local function setInfiniteJump(enabled: boolean)
		settings.infiniteJump = enabled
		if infiniteJumpConn then
			infiniteJumpConn:Disconnect()
			infiniteJumpConn = nil
		end
		if not enabled then
			return
		end
		infiniteJumpConn = track(UserInputService.JumpRequest:Connect(function()
			if not settings.infiniteJump then
				return
			end
			local character = localPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end))
	end

	local savedLighting: { [string]: any }? = nil
	local function setFullbright(enabled: boolean)
		settings.fullbright = enabled
		if enabled then
			if not savedLighting then
				savedLighting = {
					Brightness = Lighting.Brightness,
					ClockTime = Lighting.ClockTime,
					FogEnd = Lighting.FogEnd,
					GlobalShadows = Lighting.GlobalShadows,
					OutdoorAmbient = Lighting.OutdoorAmbient,
					Ambient = Lighting.Ambient,
				}
			end
			Lighting.Brightness = 2
			Lighting.ClockTime = 12
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
			Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
			Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		elseif savedLighting then
			for key, value in savedLighting do
				Lighting[key] = value
			end
		end
	end

	local function setHideChat(enabled: boolean)
		settings.hideChat = enabled
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not enabled)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.BubbleChat, not enabled)
		end)
	end

	local clickTeleportConn: RBXScriptConnection? = nil
	local function setClickTeleport(enabled: boolean)
		settings.clickTeleport = enabled
		if clickTeleportConn then
			clickTeleportConn:Disconnect()
			clickTeleportConn = nil
		end
		if not enabled then
			return
		end
		clickTeleportConn = track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if keybindCapturingId or not settings.clickTeleport or gameProcessed or isTypingInTextBox() then
				return
			end
			if not keybindMatches(input.KeyCode, "clickTeleport") then
				return
			end
			local character = localPlayer.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local camera = Workspace.CurrentCamera
			if not hrp or not hrp:IsA("BasePart") or not camera then
				return
			end
			local mouse = localPlayer:GetMouse()
			local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			local result = Workspace:Raycast(ray.Origin, ray.Direction * 2048, params)
			if result then
				hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
			end
		end))
	end

	local TP_TOOL_NAME = "TP Tool"
	local tpTool: Tool? = nil
	local tpToolConns: { RBXScriptConnection } = {}
	local function clearTpToolConns()
		for _, conn in tpToolConns do
			conn:Disconnect()
		end
		table.clear(tpToolConns)
	end
	local function destroyTpTool()
		clearTpToolConns()
		if tpTool then
			tpTool:Destroy()
			tpTool = nil
		end
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		if backpack then
			local leftover = backpack:FindFirstChild(TP_TOOL_NAME)
			if leftover then
				leftover:Destroy()
			end
		end
		local character = localPlayer.Character
		if character then
			local equipped = character:FindFirstChild(TP_TOOL_NAME)
			if equipped then
				equipped:Destroy()
			end
		end
	end
	local function giveTpTool()
		destroyTpTool()
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		if not backpack then
			pcall(function()
				backpack = localPlayer:WaitForChild("Backpack", 5) :: Backpack
			end)
		end
		if not backpack then
			return
		end
		local tool = Instance.new("Tool")
		tool.RequiresHandle = false
		tool.CanBeDropped = false
		tool.Name = TP_TOOL_NAME
		tool:SetAttribute(NETWORK.SCRIPT_ATTR, true)
		local mouse = localPlayer:GetMouse()
		table.insert(
			tpToolConns,
			tool.Activated:Connect(function()
				local character = localPlayer.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if not hrp or not hrp:IsA("BasePart") then
					return
				end
				local hit = mouse.Hit
				hrp.CFrame = CFrame.new(hit.X, hit.Y + 2.5, hit.Z)
			end)
		)
		tool.Parent = backpack
		tpTool = tool
	end
	local function setTpTool(enabled: boolean)
		settings.tpTool = enabled
		if enabled then
			giveTpTool()
		else
			destroyTpTool()
		end
	end
	track(localPlayer.CharacterAdded:Connect(function()
		if not settings.tpTool then
			return
		end
		task.defer(function()
			if settings.tpTool then
				giveTpTool()
			end
		end)
	end))

	local nameEspFolder: Folder? = nil
	local nameEspConns: { RBXScriptConnection } = {}
	local function clearNameEsp()
		for _, conn in nameEspConns do
			conn:Disconnect()
		end
		table.clear(nameEspConns)
		if nameEspFolder then
			nameEspFolder:Destroy()
			nameEspFolder = nil
		end
	end
	local function setNameEsp(enabled: boolean)
		settings.nameEsp = enabled
		clearNameEsp()
		if not enabled then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "ScorpNameEsp"
		folder.Parent = hostGui
		nameEspFolder = folder
		local function removeTag(player: Player)
			local tag = folder:FindFirstChild(tostring(player.UserId))
			if tag then
				tag:Destroy()
			end
		end
		local function createTag(player: Player)
			if player == localPlayer then
				return
			end
			removeTag(player)
			local function attach(character: Model)
				local head = character:FindFirstChild("Head")
				if not head then
					return
				end
				local billboard = folder:FindFirstChild(tostring(player.UserId))
				if not billboard then
					billboard = Instance.new("BillboardGui")
					billboard.Name = tostring(player.UserId)
					billboard.AlwaysOnTop = true
					billboard.Size = UDim2.fromOffset(160, 36)
					billboard.StudsOffset = Vector3.new(0, 2.4, 0)
					billboard.Parent = folder
					local nameLabel = Instance.new("TextLabel")
					nameLabel.BackgroundTransparency = 1
					nameLabel.Size = UDim2.fromScale(1, 1)
					nameLabel.Font = Enum.Font.GothamBold
					nameLabel.TextSize = 14
					nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					nameLabel.TextStrokeTransparency = 0.4
					nameLabel.Text = player.DisplayName
					nameLabel.Parent = billboard
				end
				billboard.Adornee = head :: BasePart
			end
			if player.Character then
				attach(player.Character)
			end
			table.insert(nameEspConns, player.CharacterAdded:Connect(attach))
		end
		for _, player in Players:GetPlayers() do
			createTag(player)
		end
		table.insert(nameEspConns, Players.PlayerAdded:Connect(createTag))
		table.insert(nameEspConns, Players.PlayerRemoving:Connect(removeTag))
	end

	local sit = {
		enabled = false,
		target = nil :: Player?,
		mode = "back" :: string,
		connection = nil :: RBXScriptConnection?,
		animTrack = nil :: AnimationTrack?,
		phase = 0,
		torsoRelative = nil :: CFrame?,
		speed = 10,
		distance = 2,
	}
	local sitChanged: ((boolean) -> ())? = nil
	local function getCharacterTorso(character: Model?): BasePart?
		if not character then
			return nil
		end
		local lower = character:FindFirstChild("LowerTorso")
		if lower and lower:IsA("BasePart") then
			return lower
		end
		local torso = character:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			return torso
		end
		return nil
	end
	local function getCharacterRoot(character: Model?): BasePart?
		if not character then
			return nil
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end
		return getCharacterTorso(character)
	end
	local function getCharacterUpper(character: Model?): BasePart?
		if not character then
			return nil
		end
		local upper = character:FindFirstChild("UpperTorso")
		if upper and upper:IsA("BasePart") then
			return upper
		end
		return getCharacterTorso(character) or getCharacterRoot(character)
	end
	local function setLocalCanCollide(character: Model?, canCollide: boolean)
		if not character then
			return
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = canCollide
			end
		end
	end
	local function flattenLook(part: BasePart?): Vector3
		if not part then
			return Vector3.new(0, 0, -1)
		end
		local look = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
		if look.Magnitude < 0.05 then
			return Vector3.new(0, 0, -1)
		end
		return look.Unit
	end
	local function stopSitAnim()
		if sit.animTrack then
			pcall(function()
				sit.animTrack:Stop(0.08)
				sit.animTrack:Destroy()
			end)
			sit.animTrack = nil
		end
	end

	local function playSitAnim(humanoid: Humanoid)
		stopSitAnim()
		humanoid.PlatformStand = false
		humanoid.Sit = true
		humanoid.AutoRotate = false
		local ids = if humanoid.RigType == Enum.HumanoidRigType.R6
			then { "rbxassetid://178130996" }
			else { "rbxassetid://2506281703", "rbxassetid://507766388" }
		for _, animId in ids do
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local ok, track = pcall(function()
				return humanoid:LoadAnimation(anim)
			end)
			anim:Destroy()
			if ok and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Action4
				track:Play(0.12, 1, 1)
				sit.animTrack = track
				break
			end
		end
	end

	local function stopSit()
		sit.enabled = false
		sit.target = nil
		sit.phase = 0
		sit.torsoRelative = nil
		if sit.connection then
			sit.connection:Disconnect()
			sit.connection = nil
		end
		stopSitAnim()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
		end
		if character and not settings.noclip then
			setLocalCanCollide(character, true)
		end
		if sitChanged then
			sitChanged(false)
		end
	end
	local function findNearestPlayer(): Player?
		local myRoot = getCharacterRoot(localPlayer.Character)
		if not myRoot then
			return nil
		end
		local nearest: Player? = nil
		local nearestDist = math.huge
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer and player.Character then
				local targetRoot = getCharacterRoot(player.Character)
				if targetRoot then
					local dist = (myRoot.Position - targetRoot.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						nearest = player
					end
				end
			end
		end
		return nearest
	end
	local function startSit(targetPlayer: Player?, mode: string?): boolean
		local wantedMode = if mode == "head" then "head" elseif mode == "back" then "back" else sit.mode
		local myCharacter = localPlayer.Character
		local myHrp = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
		if not myCharacter or not myHrp or not myHrp:IsA("BasePart") then
			return false
		end
		local nearest: Player? = targetPlayer
		if nearest == localPlayer then
			return false
		end
		if not nearest then
			nearest = findNearestPlayer()
		end
		if not nearest or not nearest.Character then
			return false
		end
		local humanoid = myCharacter:FindFirstChildOfClass("Humanoid")
		local root = getCharacterRoot(myCharacter)
		if not humanoid or not root then
			return false
		end
		if wantedMode == "head" then
			local head = nearest.Character:FindFirstChild("Head")
			if not head or not head:IsA("BasePart") then
				return false
			end
		elseif not getCharacterRoot(nearest.Character) then
			return false
		end
		sit.enabled = true
		sit.target = nearest
		sit.mode = wantedMode
		sit.phase = 0
		sit.torsoRelative = nil
		playSitAnim(humanoid)
		if sit.connection then
			sit.connection:Disconnect()
		end
		sit.connection = track(RunService.RenderStepped:Connect(function()
			if not sit.enabled or not sit.target or not sit.target.Character then
				stopSit()
				return
			end
			local character = localPlayer.Character
			local myRoot = getCharacterRoot(character)
			local targetRoot = getCharacterRoot(sit.target.Character)
			local myHum = character and character:FindFirstChildOfClass("Humanoid")
			if not character or not myRoot or not targetRoot then
				stopSit()
				return
			end
			if myHum then
				myHum.Sit = true
				myHum.PlatformStand = false
				myHum.AutoRotate = false
			end
			if sit.animTrack and not sit.animTrack.IsPlaying then
				sit.animTrack:Play(0.05, 1, 1)
			end
			setLocalCanCollide(character, false)
			local extra = sit.distance * 0.28
			local goal: CFrame
			if sit.mode == "head" then
				local targetHead = sit.target.Character:FindFirstChild("Head")
				if not targetHead or not targetHead:IsA("BasePart") then
					stopSit()
					return
				end
				local _, yaw, _ = targetHead.CFrame:ToEulerAnglesYXZ()
				local sitPos = targetHead.Position + Vector3.new(0, targetHead.Size.Y * 0.5 + 1.05 + extra, 0)
				goal = CFrame.new(sitPos) * CFrame.Angles(0, yaw, 0)
			else
				goal = targetRoot.CFrame * CFrame.new(0, 0.05, 0.82 + extra) * CFrame.Angles(0, math.pi, 0)
			end
			myRoot.CFrame = goal
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end))
		if sitChanged then
			sitChanged(true)
		end
		return true
	end
	local function setSitEnabled(enabled: boolean)
		if enabled then
			if not sit.enabled and not startSit() then
				stopSit()
			end
			return
		end
		if sit.enabled then
			stopSit()
		end
	end
	local function setSitSpeed(value: number)
		sit.speed = math.clamp(math.floor(value + 0.5), 1, 30)
	end
	local function setSitDistance(value: number)
		sit.distance = math.clamp(math.floor(value + 0.5), 0, 10)
	end
	local function setSitMode(mode: string)
		sit.mode = if mode == "head" then "head" else "back"
		if sit.enabled and sit.target then
			startSit(sit.target, sit.mode)
		end
	end
	local function sitOnPlayer(target: Player, mode: string)
		if sit.enabled and sit.target == target and sit.mode == mode then
			stopSit()
			return
		end
		if sit.enabled then
			stopSit()
		end
		if not startSit(target, mode) then
			stopSit()
		end
	end
	local function teleportToPlayer(target: Player)
		if target == localPlayer then
			return
		end
		if sit.enabled then
			stopSit()
		end
		local myRoot = getCharacterRoot(localPlayer.Character)
		local theirRoot = getCharacterRoot(target.Character)
		if myRoot and theirRoot then
			myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 3)
		end
	end
	local spectateTarget: Player? = nil
	local spectateCharConn: RBXScriptConnection? = nil
	local spectateHeartbeat: RBXScriptConnection? = nil
	local spectateSavedType: Enum.CameraType? = nil
	local spectateSavedMin: number? = nil
	local spectateSavedMax: number? = nil
	local spectateSavedMode: Enum.CameraMode? = nil

	local function restoreOwnCamera()
		local camera = Workspace.CurrentCamera
		local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if camera then
			camera.CameraType = spectateSavedType or Enum.CameraType.Custom
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		pcall(function()
			if spectateSavedMode then
				localPlayer.CameraMode = spectateSavedMode
			end
			if spectateSavedMin then
				localPlayer.CameraMinZoomDistance = spectateSavedMin
			end
			if spectateSavedMax then
				localPlayer.CameraMaxZoomDistance = spectateSavedMax
			end
		end)
		spectateSavedType = nil
		spectateSavedMin = nil
		spectateSavedMax = nil
		spectateSavedMode = nil
	end

	local function applySpectateCamera()
		local target = spectateTarget
		local camera = Workspace.CurrentCamera
		if not target or not camera then
			return
		end
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		if camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
	end

	local function pushThirdPersonZoom()
		pcall(function()
			if spectateSavedMin == nil then
				spectateSavedMin = localPlayer.CameraMinZoomDistance
				spectateSavedMax = localPlayer.CameraMaxZoomDistance
				spectateSavedMode = localPlayer.CameraMode
			end
			localPlayer.CameraMode = Enum.CameraMode.Classic
			localPlayer.CameraMinZoomDistance = 12
			localPlayer.CameraMaxZoomDistance = 12
		end)
		task.defer(function()
			if not spectateTarget then
				return
			end
			pcall(function()
				localPlayer.CameraMinZoomDistance = 8
				localPlayer.CameraMaxZoomDistance = math.max(spectateSavedMax or 128, 32)
			end)
		end)
	end
	local function stopSpectate()
		spectateTarget = nil
		if spectateCharConn then
			spectateCharConn:Disconnect()
			spectateCharConn = nil
		end
		if spectateHeartbeat then
			spectateHeartbeat:Disconnect()
			spectateHeartbeat = nil
		end
		restoreOwnCamera()
	end

	local function spectatePlayer(target: Player)
		if target == localPlayer or not target.Character then
			stopSpectate()
			return
		end
		if spectateTarget == target then
			stopSpectate()
			return
		end
		if not getCharacterRoot(target.Character) then
			return
		end
		if spectateCharConn then
			spectateCharConn:Disconnect()
			spectateCharConn = nil
		end
		if spectateHeartbeat then
			spectateHeartbeat:Disconnect()
			spectateHeartbeat = nil
		end
		local camera = Workspace.CurrentCamera
		if camera and spectateSavedType == nil then
			spectateSavedType = camera.CameraType
		end
		spectateTarget = target
		pushThirdPersonZoom()
		applySpectateCamera()
		spectateHeartbeat = track(RunService.Heartbeat:Connect(applySpectateCamera))
		spectateCharConn = track(target.CharacterAdded:Connect(function()
			if spectateTarget == target then
				task.wait(0.1)
				pushThirdPersonZoom()
				applySpectateCamera()
			end
		end))
	end
	track(Players.PlayerRemoving:Connect(function(player)
		if spectateTarget == player then
			stopSpectate()
		end
		if sit.target == player then
			stopSit()
		end
	end))
	track(localPlayer.CharacterAdded:Connect(function(character)
		if spectateTarget then
			return
		end
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") and Workspace.CurrentCamera then
			Workspace.CurrentCamera.CameraSubject = humanoid
		end
	end))
	track(localPlayer.CharacterRemoving:Connect(function()
		if sit.enabled then
			stopSit()
		end
	end))

	local fly = {
		enabled = false,
		speed = 50,
		originalGravity = Workspace.Gravity,
		moveState = { forward = 0, backward = 0, left = 0, right = 0 },
		currentCF = nil :: CFrame?,
		currentVelocity = Vector3.zero,
		currentAnimTrack = nil :: AnimationTrack?,
		flightConns = {} :: { RBXScriptConnection },
	}
	local flyChanged: ((boolean) -> ())? = nil
	local function getFlyParts(): (Model?, Humanoid?, BasePart?)
		local character = localPlayer.Character
		if not character then
			return nil, nil, nil
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and not root:IsA("BasePart") then
			root = nil
		end
		return character, humanoid, root :: BasePart?
	end
	local function stopFlyAnim(humanoid: Humanoid?)
		if fly.currentAnimTrack then
			fly.currentAnimTrack:Stop(0.1)
			fly.currentAnimTrack = nil
		end
		if humanoid then
			local animate = humanoid.Parent and humanoid.Parent:FindFirstChild("Animate")
			if animate then
				pcall(function()
					animate.Disabled = false
				end)
			end
		end
	end
	local function playFlyAnim(humanoid: Humanoid?, animId: number, startTime: number)
		if not humanoid then
			return
		end
		stopFlyAnim(humanoid)
		local animate = humanoid.Parent and humanoid.Parent:FindFirstChild("Animate")
		if animate then
			pcall(function()
				animate.Disabled = true
			end)
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(animId)
		local track = humanoid:LoadAnimation(animation)
		track:Play()
		track.TimePosition = startTime
		track:AdjustSpeed(0)
		fly.currentAnimTrack = track
	end
	local function stopFly()
		fly.enabled = false
		for _, conn in fly.flightConns do
			conn:Disconnect()
		end
		table.clear(fly.flightConns)
		local _, humanoid, root = getFlyParts()
		Workspace.Gravity = fly.originalGravity
		if humanoid then
			humanoid.PlatformStand = false
			stopFlyAnim(humanoid)
		end
		if root then
			local gyro = root:FindFirstChild(SUPERMAN_BG_NAME)
			if gyro then
				gyro:Destroy()
			end
			local velocity = root:FindFirstChild(SUPERMAN_BV_NAME)
			if velocity then
				velocity:Destroy()
			end
		end
		fly.currentCF = nil
		fly.currentVelocity = Vector3.zero
		fly.moveState.forward = 0
		fly.moveState.backward = 0
		fly.moveState.left = 0
		fly.moveState.right = 0
		if flyChanged then
			flyChanged(false)
		end
	end
	local function startFly(): boolean
		local _, humanoid, root = getFlyParts()
		if not humanoid or not root then
			return false
		end
		stopFly()
		fly.enabled = true
		fly.originalGravity = Workspace.Gravity
		Workspace.Gravity = 0
		humanoid.PlatformStand = true
		playFlyAnim(humanoid, SUPERMAN_ANIM_IDLE, 4)
		local gyro = Instance.new("BodyGyro")
		gyro.Name = SUPERMAN_BG_NAME
		gyro.P = 90000
		gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
		gyro.CFrame = root.CFrame
		gyro.Parent = root
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Name = SUPERMAN_BV_NAME
		bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		bodyVelocity.Velocity = Vector3.new(0, 0.1, 0)
		bodyVelocity.Parent = root
		table.insert(
			fly.flightConns,
			RunService.RenderStepped:Connect(function()
				if not fly.enabled then
					return
				end
				local _, currentHumanoid, currentRoot = getFlyParts()
				local camera = Workspace.CurrentCamera
				if not currentHumanoid or not currentRoot or not camera then
					stopFly()
					return
				end
				local currentGyro = currentRoot:FindFirstChild(SUPERMAN_BG_NAME)
				local currentVel = currentRoot:FindFirstChild(SUPERMAN_BV_NAME)
				if not currentGyro or not currentGyro:IsA("BodyGyro") or not currentVel or not currentVel:IsA("BodyVelocity") then
					stopFly()
					return
				end
				local fwd = fly.moveState.forward - fly.moveState.backward
				local side = fly.moveState.right - fly.moveState.left
				local inputVec = (camera.CFrame.LookVector * fwd) + (camera.CFrame.RightVector * side)
				if fwd ~= 0 then
					inputVec += Vector3.new(0, 0.2 * fwd, 0)
				end
				local desired = if inputVec.Magnitude > 0
					then inputVec.Unit * fly.speed
					else Vector3.new(0, math.sin(os.clock()) * 0.5, 0)
				fly.currentVelocity = fly.currentVelocity:Lerp(desired, 0.1)
				currentVel.Velocity = fly.currentVelocity
				local desiredCF = if fwd > 0
					then camera.CFrame * CFrame.Angles(math.rad(-90), 0, 0)
					else camera.CFrame * CFrame.Angles(math.rad(-45 * fwd), 0, 0)
				fly.currentCF = if fly.currentCF then fly.currentCF:Lerp(desiredCF, 0.1) else desiredCF
				currentGyro.CFrame = fly.currentCF
				currentHumanoid.PlatformStand = true
			end)
		)
		table.insert(
			fly.flightConns,
			UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if not fly.enabled or gameProcessed or isTypingInTextBox() then
					return
				end
				if input.KeyCode == Enum.KeyCode.W then
					fly.moveState.forward = 1
					playFlyAnim(humanoid, SUPERMAN_ANIM_FORWARD, 4.65)
				elseif input.KeyCode == Enum.KeyCode.S then
					fly.moveState.backward = 1
					playFlyAnim(humanoid, SUPERMAN_ANIM_IDLE, 4)
				elseif input.KeyCode == Enum.KeyCode.A then
					fly.moveState.left = 1
				elseif input.KeyCode == Enum.KeyCode.D then
					fly.moveState.right = 1
				end
			end)
		)
		table.insert(
			fly.flightConns,
			UserInputService.InputEnded:Connect(function(input)
				if not fly.enabled then
					return
				end
				if input.KeyCode == Enum.KeyCode.W then
					fly.moveState.forward = 0
					playFlyAnim(humanoid, SUPERMAN_ANIM_IDLE, 4)
				elseif input.KeyCode == Enum.KeyCode.S then
					fly.moveState.backward = 0
				elseif input.KeyCode == Enum.KeyCode.A then
					fly.moveState.left = 0
				elseif input.KeyCode == Enum.KeyCode.D then
					fly.moveState.right = 0
				end
			end)
		)
		if flyChanged then
			flyChanged(true)
		end
		return true
	end
	local function setFlyEnabled(enabled: boolean)
		if enabled then
			if not fly.enabled and not startFly() then
				stopFly()
			end
			return
		end
		if fly.enabled then
			stopFly()
		end
	end
	local function toggleFly()
		setFlyEnabled(not fly.enabled)
	end
	local function toggleSit()
		setSitEnabled(not sit.enabled)
	end
	local function setFlySpeed(value: number)
		fly.speed = math.clamp(math.floor(value + 0.5), 1, 200)
	end
	track(localPlayer.CharacterAdded:Connect(function()
		if fly.enabled then
			stopFly()
		end
	end))

	local function runAntiVc()
		runRemoteLoadstring("https://shield.xao.wtf/api/loader/550af30c-aaa3-4338-acab-f44010a5ef09")
	end

	local fakeoutHeartbeat: RBXScriptConnection? = nil
	local fakeoutSafeCF: CFrame? = nil
	local function playerFromWorldPart(part: Instance?, myCharacter: Model): Player?
		local inst = part
		while inst and inst ~= game do
			if inst == myCharacter then
				return nil
			end
			if inst:IsA("Model") then
				local player = Players:GetPlayerFromCharacter(inst)
				if player and player ~= localPlayer then
					return player
				end
			end
			inst = inst.Parent
		end
		return nil
	end
	local function isOurSitTarget(player: Player): boolean
		return sit.enabled and sit.target == player
	end
	local function fakeoutVoidFloor(): number
		local destroyY = Workspace.FallenPartsDestroyHeight
		if typeof(destroyY) ~= "number" then
			destroyY = -500
		end
		return destroyY + 80
	end
	local function restoreLocalAfterFakeout(hrp: BasePart?, savedCF: CFrame?, savedVel: Vector3?, savedAng: Vector3?)
		if not hrp or not savedCF then
			return
		end
		hrp.CFrame = savedCF
		hrp.AssemblyLinearVelocity = savedVel or Vector3.zero
		hrp.AssemblyAngularVelocity = savedAng or Vector3.zero
	end
	local function neverVoidLocalPlayer(hrp: BasePart?, safeCF: CFrame?, voidFloor: number)
		if not hrp then
			return
		end
		if hrp.Position.Y > voidFloor then
			return
		end
		local fallback = safeCF or fakeoutSafeCF
		if fallback then
			hrp.CFrame = fallback
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	local function jointPair(obj: Instance): (BasePart?, BasePart?)
		if obj:IsA("WeldConstraint") or obj:IsA("JointInstance") then
			local p0 = obj.Part0
			local p1 = obj.Part1
			if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
				return p0, p1
			end
			return nil, nil
		end
		if obj:IsA("Constraint") then
			local a0 = obj.Attachment0
			local a1 = obj.Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
				return p0, p1
			end
		end
		return nil, nil
	end
	local function markFakeoutTarget(attached: { [Player]: boolean }, player: Player?)
		if not player or player == localPlayer then
			return
		end
		if isOurSitTarget(player) then
			return
		end
		attached[player] = true
	end
	local function collectFakeoutTargets(myCharacter: Model): { [Player]: boolean }
		local attached: { [Player]: boolean } = {}
		local function scanJoints(root: Instance)
			for _, obj in root:GetDescendants() do
				local p0, p1 = jointPair(obj)
				if p0 and p1 then
					local a = playerFromWorldPart(p0, myCharacter)
					local b = playerFromWorldPart(p1, myCharacter)
					local p0Mine = p0:IsDescendantOf(myCharacter)
					local p1Mine = p1:IsDescendantOf(myCharacter)
					if p0Mine and b then
						markFakeoutTarget(attached, b)
					elseif p1Mine and a then
						markFakeoutTarget(attached, a)
					elseif a and b and a ~= b then
						markFakeoutTarget(attached, a)
						markFakeoutTarget(attached, b)
					end
				end
			end
		end
		scanJoints(myCharacter)
		local probeNames = { "HumanoidRootPart", "Head", "UpperTorso", "Torso" }
		for _, name in probeNames do
			local part = myCharacter:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				pcall(function()
					for _, other in part:GetConnectedParts(true) do
						markFakeoutTarget(attached, playerFromWorldPart(other, myCharacter))
					end
				end)
			end
		end
		local overlapParams: OverlapParams? = nil
		pcall(function()
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { myCharacter }
			overlapParams = params
		end)
		if overlapParams then
			local head = myCharacter:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				pcall(function()
					for _, part in Workspace:GetPartsInPart(head, overlapParams) do
						markFakeoutTarget(attached, playerFromWorldPart(part, myCharacter))
					end
				end)
			end
		end
		for _, child in myCharacter:GetChildren() do
			if child:IsA("Model") then
				markFakeoutTarget(attached, Players:GetPlayerFromCharacter(child))
			end
		end
		local myHead = myCharacter:FindFirstChild("Head")
		local myRoot = getCharacterRoot(myCharacter)
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer and player.Character and not isOurSitTarget(player) then
				local theirChar = player.Character
				if theirChar:IsDescendantOf(myCharacter) or myCharacter:IsDescendantOf(theirChar) then
					markFakeoutTarget(attached, player)
				end
				local theirHum = theirChar:FindFirstChildOfClass("Humanoid")
				local theirRoot = getCharacterRoot(theirChar)
				local theirHead = theirChar:FindFirstChild("Head")
				if theirHum and theirHum.SeatPart and theirHum.SeatPart:IsDescendantOf(myCharacter) then
					markFakeoutTarget(attached, player)
				end
				if myHead and myHead:IsA("BasePart") and theirHead and theirHead:IsA("BasePart") then
					if (myHead.Position - theirHead.Position).Magnitude <= 1.7 then
						markFakeoutTarget(attached, player)
					end
				end
				if theirHum and theirRoot and myHead and myHead:IsA("BasePart") and myRoot then
					local delta = theirRoot.Position - myHead.Position
					local horiz = Vector3.new(delta.X, 0, delta.Z).Magnitude
					local onTop = theirRoot.Position.Y > myRoot.Position.Y + 0.35
					if onTop and horiz <= 3.4 and delta.Y > -0.5 and delta.Y < 6 then
						if theirHum.Sit or theirHum.SeatPart ~= nil then
							markFakeoutTarget(attached, player)
						end
					end
				end
			end
		end
		return attached
	end
	local function breakFakeoutLinks(myCharacter: Model, attached: { [Player]: boolean })
		local function shouldBreak(obj: Instance): boolean
			local p0, p1 = jointPair(obj)
			if not p0 or not p1 then
				return false
			end
			local a = playerFromWorldPart(p0, myCharacter)
			local b = playerFromWorldPart(p1, myCharacter)
			local p0Mine = p0:IsDescendantOf(myCharacter)
			local p1Mine = p1:IsDescendantOf(myCharacter)
			if p0Mine and b and attached[b] then
				return true
			end
			if p1Mine and a and attached[a] then
				return true
			end
			return false
		end
		local function destroyMatching(root: Instance)
			local doomed: { Instance } = {}
			for _, obj in root:GetDescendants() do
				if shouldBreak(obj) then
					table.insert(doomed, obj)
				end
			end
			for _, obj in doomed do
				pcall(function()
					obj:Destroy()
				end)
			end
		end
		destroyMatching(myCharacter)
		for player, _ in attached do
			if player.Character then
				destroyMatching(player.Character)
			end
		end
	end
	local function voidOtherCharacter(character: Model?)
		if not character or character == localPlayer.Character then
			return
		end
		if Players:GetPlayerFromCharacter(character) == localPlayer then
			return
		end
		local destroyY = Workspace.FallenPartsDestroyHeight
		if typeof(destroyY) ~= "number" then
			destroyY = -500
		end
		local voidY = destroyY - 40
		local dest = CFrame.new((math.random() - 0.5) * 12, voidY, (math.random() - 0.5) * 12)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				humanoid.Sit = false
				humanoid.PlatformStand = true
				humanoid.AutoRotate = false
				humanoid.Jump = true
			end)
		end
		local root = getCharacterRoot(character)
		if root then
			pcall(function()
				root.CFrame = dest
				root.AssemblyLinearVelocity = Vector3.new(0, -320, 0)
				root.AssemblyAngularVelocity = Vector3.zero
				root.CanCollide = false
			end)
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				pcall(function()
					part.CFrame = dest
					part.AssemblyLinearVelocity = Vector3.new(0, -320, 0)
					part.AssemblyAngularVelocity = Vector3.zero
					part.CanCollide = false
				end)
			end
		end
	end
	local function stillPhysicallyAttached(myCharacter: Model, attached: { [Player]: boolean }): boolean
		for _, name in { "HumanoidRootPart", "Head", "UpperTorso", "Torso" } do
			local part = myCharacter:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				local hit = false
				pcall(function()
					for _, other in part:GetConnectedParts(true) do
						local player = playerFromWorldPart(other, myCharacter)
						if player and attached[player] then
							hit = true
							break
						end
					end
				end)
				if hit then
					return true
				end
			end
		end
		return false
	end
	local function pulseFakeout()
		local myCharacter = localPlayer.Character
		local myHrp = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
		if not myCharacter or not myHrp or not myHrp:IsA("BasePart") then
			return
		end
		local voidFloor = fakeoutVoidFloor()
		if myHrp.Position.Y > voidFloor then
			fakeoutSafeCF = myHrp.CFrame
		end
		local savedCF = fakeoutSafeCF or myHrp.CFrame
		local savedVel = myHrp.AssemblyLinearVelocity
		local savedAng = myHrp.AssemblyAngularVelocity
		local rodeToVoid = false
		pcall(function()
			local attached = collectFakeoutTargets(myCharacter)
			local hasTarget = false
			for player, _ in attached do
				if player ~= localPlayer then
					hasTarget = true
					break
				end
			end
			if not hasTarget then
				return
			end
			breakFakeoutLinks(myCharacter, attached)
			for player, _ in attached do
				if player ~= localPlayer then
					voidOtherCharacter(player.Character)
				end
			end
			if stillPhysicallyAttached(myCharacter, attached) then
				rodeToVoid = true
				myHrp.CFrame = CFrame.new(savedCF.Position.X, voidFloor - 120, savedCF.Position.Z)
				breakFakeoutLinks(myCharacter, attached)
				for player, _ in attached do
					if player ~= localPlayer then
						voidOtherCharacter(player.Character)
					end
				end
			end
		end)
		if rodeToVoid then
			restoreLocalAfterFakeout(myHrp, savedCF, savedVel, savedAng)
		end
		neverVoidLocalPlayer(myHrp, savedCF, voidFloor)
	end
	local function setFakeout(enabled: boolean)
		settings.fakeout = enabled
		if fakeoutHeartbeat then
			fakeoutHeartbeat:Disconnect()
			fakeoutHeartbeat = nil
		end
		if not enabled then
			return
		end
		pcall(function()
			local setRadius = envGlobal("setsimulationradius")
			if typeof(setRadius) == "function" then
				setRadius(math.huge)
			end
		end)
		pulseFakeout()
		local acc = 0
		fakeoutHeartbeat = track(RunService.Heartbeat:Connect(function(dt: number)
			acc += dt
			if acc < 0.05 then
				return
			end
			acc = 0
			if not settings.fakeout then
				return
			end
			pulseFakeout()
		end))
	end

	local function cleanup()
		setNoclip(false)
		setAntiFling(false)
		setFakeout(false)
		setAntiNetworkPause(false)
		setAntiAfk(false)
		setInfiniteJump(false)
		setInfiniteZoom(false)
		setFullbright(false)
		setHideChat(false)
		setClickTeleport(false)
		setTpTool(false)
		setNameEsp(false)
		stopSit()
		stopSpectate()
		stopFly()
		disconnectAll()
	end

	return {
		settings = settings,
		setNoclip = setNoclip,
		setAntiFling = setAntiFling,
		setFakeout = setFakeout,
		setAntiNetworkPause = setAntiNetworkPause,
		setAntiAfk = setAntiAfk,
		setInfiniteJump = setInfiniteJump,
		setInfiniteZoom = setInfiniteZoom,
		setFullbright = setFullbright,
		setHideChat = setHideChat,
		setClickTeleport = setClickTeleport,
		setTpTool = setTpTool,
		setNameEsp = setNameEsp,
		runAntiVc = runAntiVc,
		toggleSit = toggleSit,
		toggleFly = toggleFly,
		setSitEnabled = setSitEnabled,
		setFlyEnabled = setFlyEnabled,
		sitOnPlayer = sitOnPlayer,
		teleportToPlayer = teleportToPlayer,
		spectatePlayer = spectatePlayer,
		stopSpectate = stopSpectate,
		isSpectating = function(player: Player)
			return spectateTarget == player
		end,
		getSitTarget = function()
			return sit.target
		end,
		getSitMode = function()
			return sit.mode
		end,
		setSitSpeed = setSitSpeed,
		setSitDistance = setSitDistance,
		setSitMode = setSitMode,
		setFlySpeed = setFlySpeed,
		getSitSpeed = function()
			return sit.speed
		end,
		getSitDistance = function()
			return sit.distance
		end,
		getFlySpeed = function()
			return fly.speed
		end,
		isSit = function()
			return sit.enabled
		end,
		isFly = function()
			return fly.enabled
		end,
		onSitChanged = function(callback: (boolean) -> ())
			sitChanged = callback
		end,
		onFlyChanged = function(callback: (boolean) -> ())
			flyChanged = callback
		end,
		cleanup = cleanup,
	}
end

local function createScriptTags(
	localPlayer: Player,
	hostGui: Instance,
	network: any,
	teleportToPlayer: (Player) -> ()
)
	-- message (15) Kryptex nametag renderer. Styles come from the Scorp Discord bot via GET /nametags.
	local TAG_COLORS = {
		bg = Color3.fromRGB(12, 14, 20),
		text = Color3.fromRGB(244, 246, 255),
	}
	local TAG_HEIGHT = 58
	local ICON_SIZE = 44
	local ICON_LEFT = 10
	local TEXT_GAP = 12
	local NAME_SIZE = 18
	local USER_SIZE = 12
	local PAD_RIGHT = 14
	local FONT_MAP = {
		GothamBlack = Enum.Font.GothamBlack,
		GothamBold = Enum.Font.GothamBold,
		Gotham = Enum.Font.Gotham,
		Bangers = Enum.Font.Bangers,
		SourceSansBold = Enum.Font.SourceSansBold,
	}

	local running = true
	local epoch = CLIENT_EPOCH
	local tagGui = Instance.new("ScreenGui")
	tagGui.Name = "ScorpNametagGui"
	tagGui.ResetOnSpawn = false
	tagGui.IgnoreGuiInset = true
	tagGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tagGui.DisplayOrder = 1000000
	tagGui.Enabled = true
	-- BillboardGuis under a protect_gui hub ScreenGui never draw in the world.
	-- Keep this ScreenGui in PlayerGui (or CoreGui) and never parent tags to the Head —
	-- games strip Head children, and our leftover-tag cleaner also matches @username.
	local function resolveTagParent(): Instance?
		local pg: Instance? = nil
		pcall(function()
			pg = localPlayer:FindFirstChildOfClass("PlayerGui")
		end)
		if not pg then
			pcall(function()
				pg = localPlayer:WaitForChild("PlayerGui", 4)
			end)
		end
		if pg and pg ~= hostGui and pg ~= hostGui.Parent then
			return pg
		end
		local okCore, coreGui = pcall(function()
			return game:GetService("CoreGui")
		end)
		if okCore and typeof(coreGui) == "Instance" and coreGui ~= hostGui and coreGui ~= hostGui.Parent then
			return coreGui
		end
		return pg
	end
	local tagParent = resolveTagParent()
	pcall(function()
		tagGui.Parent = tagParent
	end)
	if not tagGui.Parent then
		pcall(function()
			tagGui.Parent = localPlayer:FindFirstChildOfClass("PlayerGui")
		end)
	end
	local folder = Instance.new("Folder")
	folder.Name = "ScorpRunnerTags"
	folder.Parent = tagGui
	pcall(function()
		local env = executorTable()
		if type(env) == "table" then
			env.ScorpLiveNametagFolder = folder
		end
	end)
	stripForeignNametags(folder, epoch)
	local tags: { [number]: BillboardGui } = {}
	local charConns: { [number]: RBXScriptConnection } = {}
	local charRemoving: { [number]: RBXScriptConnection } = {}
	local charAppearance: { [number]: RBXScriptConnection } = {}
	local extraConns: { RBXScriptConnection } = {}
	local nameHideConns: { [number]: { RBXScriptConnection } } = {}
	local function suppressEngineNames()
		pcall(function()
			if Players.NameDisplayDistance ~= 0 then
				Players.NameDisplayDistance = 0
			end
		end)
	end
	suppressEngineNames()
	do
		local okDist, distConn = pcall(function()
			return Players:GetPropertyChangedSignal("NameDisplayDistance"):Connect(function()
				if running and isLiveEpoch(epoch) then
					suppressEngineNames()
				end
			end)
		end)
		if okDist and distConn then
			table.insert(extraConns, distConn)
		end
	end
	local function bindForeignJanitor(parent: Instance?)
		if not parent then
			return
		end
		local ok, conn = pcall(function()
			return parent.ChildAdded:Connect(function(inst)
				if not running or not isLiveEpoch(epoch) then
					return
				end
				if not inst:IsA("BillboardGui") then
					return
				end
				task.defer(function()
					if not running or not isLiveEpoch(epoch) then
						return
					end
					local ours = inst:GetAttribute("ScorpNametag") == true
					local tagEpoch = tonumber(inst:GetAttribute("ScorpNametagEpoch"))
					if ours or tagEpoch == epoch then
						return
					end
					if isNametagBillboard(inst) then
						pcall(function()
							inst.Enabled = false
							inst.Adornee = nil
						end)
					end
				end)
			end)
		end)
		if ok and conn then
			table.insert(extraConns, conn)
		end
	end
	bindForeignJanitor(localPlayer:FindFirstChild("PlayerGui"))
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer then
			bindForeignJanitor(other:FindFirstChild("PlayerGui"))
		end
	end
	local styles: { [number]: any } = {}
	local styleSig: { [number]: string } = {}
	local iconCache: { [number]: string } = {}
	local bgCache: { [number]: string } = {}
	-- message (15) ships no bundled glyph; Discord icon wins, otherwise Roblox avatar.
	local defaultIcon = ""

	local function hexColor(hex: string, fallback: Color3): Color3
		local clean = string.upper((hex or ""):gsub("#", ""))
		if #clean ~= 6 then
			return fallback
		end
		local r = tonumber(string.sub(clean, 1, 2), 16)
		local g = tonumber(string.sub(clean, 3, 4), 16)
		local b = tonumber(string.sub(clean, 5, 6), 16)
		if not (r and g and b) then
			return fallback
		end
		return Color3.fromRGB(r, g, b)
	end

	local function textWidth(text: string, size: number, font: Enum.Font): number
		local ok, bounds = pcall(function()
			return TextService:GetTextSize(text, size, font, Vector2.new(400, 40))
		end)
		if ok and typeof(bounds) == "Vector2" then
			return bounds.X
		end
		return math.max(24, #text * (size * 0.55))
	end

	local function resolveFont(name: string?): Enum.Font
		return FONT_MAP[name or ""] or Enum.Font.GothamBlack
	end

	local function cornerRadius(shape: any): UDim
		local name = string.lower(tostring(shape or "pill"))
		if name == "square" or name == "rectangle" or name == "rect" then
			return UDim.new(0, 4)
		end
		if name == "rounded" or name == "round" then
			return UDim.new(0, 12)
		end
		return UDim.new(0.5, 0)
	end

	local function attachGlitch(nameLabel: TextLabel, enabled: boolean)
		if not enabled then
			return
		end
		local function ghost(color: Color3): TextLabel
			local copy = nameLabel:Clone()
			copy.Name = "Glitch"
			copy.TextColor3 = color
			copy.TextStrokeTransparency = 1
			copy.ZIndex = math.max(1, nameLabel.ZIndex - 1)
			copy.Parent = nameLabel.Parent
			return copy
		end
		local red = ghost(Color3.fromRGB(255, 70, 90))
		local cyan = ghost(Color3.fromRGB(80, 220, 255))
		task.spawn(function()
			while nameLabel.Parent and red.Parent and cyan.Parent and running and isLiveEpoch(epoch) do
				red.Position = UDim2.fromOffset(nameLabel.Position.X.Offset + math.random(-3, -1), nameLabel.Position.Y.Offset + math.random(-1, 1))
				cyan.Position = UDim2.fromOffset(nameLabel.Position.X.Offset + math.random(1, 3), nameLabel.Position.Y.Offset + math.random(-1, 1))
				task.wait(0.08)
			end
		end)
	end

	local function isStaffPlayer(player: Player, style: any): boolean
		if isScriptStaff(player.UserId) then
			return true
		end
		if type(style) == "table" and style.staff == true then
			return true
		end
		return false
	end

	local function hasVerifiedBadge(style: any): boolean
		if type(style) ~= "table" then
			return false
		end
		local flag = style.verified_badge
		if flag == true then
			return true
		end
		if type(flag) == "string" then
			local lowered = string.lower(flag)
			return lowered == "1" or lowered == "true" or lowered == "yes" or lowered == "on"
		end
		return false
	end

	local function displayNameFor(player: Player, style: any): string
		if type(style) == "table" then
			local name = style.display_name
			if type(name) == "string" and name ~= "" then
				name = string.gsub(name, "^%s*%[[Ss][Tt][Aa][Ff][Ff]%]%s*", "")
				if name ~= "" then
					return name
				end
			end
		end
		if player.DisplayName ~= "" then
			return player.DisplayName
		end
		return player.Name
	end

	local function usernameFor(player: Player, style: any): string
		if type(style) == "table" then
			local name = style.roblox_username
			if type(name) == "string" and name ~= "" then
				return name
			end
		end
		return player.Name
	end

	local function hasCustomBg(style: any): boolean
		if type(style) ~= "table" then
			return false
		end
		return tostring(style.bg_image_url or "") ~= ""
	end

	local function hasCustomIcon(style: any): boolean
		if type(style) ~= "table" then
			return false
		end
		local icon = tostring(style.icon_image_url or style.image_url or "")
		if icon == "" then
			return false
		end
		if string.find(icon, "/images/default/icon", 1, true) then
			return false
		end
		return true
	end

	local function normalizeGifFrames(value: any): { string }
		local frames: { string } = {}
		local function addFrame(frame: any)
			if type(frame) == "number" then
				table.insert(frames, "rbxassetid://" .. tostring(frame))
				return
			end
			if type(frame) ~= "string" or frame == "" then
				return
			end
			if #frame >= 80 or string.find(frame, "://", 1, true) then
				table.insert(frames, frame)
				return
			end
			local n = tonumber(frame)
			if n then
				table.insert(frames, "rbxassetid://" .. frame)
			else
				table.insert(frames, frame)
			end
		end
		if type(value) == "table" then
			for _, frame in value do
				if type(frame) == "table" then
					addFrame(frame.url or frame.image or frame.asset or frame.asset_url or frame.id)
				else
					addFrame(frame)
				end
			end
		elseif type(value) == "string" and value ~= "" then
			local decoded: any = nil
			if string.sub(value, 1, 1) == "[" then
				pcall(function() decoded = HttpService:JSONDecode(value) end)
			end
			if type(decoded) == "table" then
				return normalizeGifFrames(decoded)
			end
			for frame in string.gmatch(value, "[^,;|%s]+") do
				addFrame(frame)
			end
		end
		return frames
	end

	local function getGifFrames(style: any, kind: string): { string }
		if type(style) ~= "table" then return {} end
		local value: any
		if kind == "icon" then
			value = style.icon_frames or style.icon_gif_frames or style.icon_frame_urls
		else
			value = style.bg_frames or style.bg_gif_frames or style.bg_frame_urls
		end
		local frames = normalizeGifFrames(value)
		if #frames > 0 then
			return frames
		end
		-- Some backends serialize the frame list into the image URL field.
		local fallback = if kind == "icon" then (style.icon_image_url or style.image_url) else style.bg_image_url
		if type(fallback) == "string" and string.sub(fallback, 1, 1) == "[" then
			return normalizeGifFrames(fallback)
		end
		return {}
	end

	local function getGifDelay(style: any, kind: string): number
		local value: any
		if type(style) == "table" then
			value = if kind == "icon" then (style.icon_frame_delay or style.gif_frame_delay) else style.bg_frame_delay
		end
		return math.clamp(tonumber(value) or 0.08, 0.03, 2)
	end

	local function animateImage(label: ImageLabel, frames: { string }, delay: number, gen: number)
		if #frames == 0 then
			return
		end
		if #frames == 1 then
			if (tonumber(label:GetAttribute("ScorpAnimGen")) or 0) == gen then
				label.Image = frames[1]
			end
			return
		end
		task.spawn(function()
			local index = 1
			while label.Parent and running and isLiveEpoch(epoch) and (tonumber(label:GetAttribute("ScorpAnimGen")) or 0) == gen do
				label.Image = frames[index]
				index = index % #frames + 1
				task.wait(delay)
			end
		end)
	end

	local frameAssetCache: { [string]: { string } } = {}

	local function detectImageExtension(data: string): string
		local b1, b2, b3, b4 = string.byte(data, 1, 4)
		if b1 == 0x47 and b2 == 0x49 and b3 == 0x46 then
			return ".gif"
		end
		if b1 == 0x89 and b2 == 0x50 and b3 == 0x4E and b4 == 0x47 then
			return ".png"
		end
		if b1 == 0xFF and b2 == 0xD8 then
			return ".jpg"
		end
		if b1 == 0x52 and b2 == 0x49 and b3 == 0x46 and b4 == 0x46 and string.sub(data, 9, 12) == "WEBP" then
			return ".webp"
		end
		return ".img"
	end

	local function assetFromB64(fileName: string, b64: string): string?
		local decoded: string? = nil
		pcall(function()
			decoded = (HttpService :: any):Base64Decode(b64)
		end)
		if type(decoded) ~= "string" or #decoded < 16 then
			local crypt = envGlobal("crypt")
			if type(crypt) == "table" then
				local decodeFn = (crypt :: any).base64decode or (crypt :: any).base64_decode
				if typeof(decodeFn) == "function" then
					pcall(function()
						decoded = decodeFn(b64)
					end)
				end
			end
		end
		if type(decoded) ~= "string" then
			return nil
		end
		local writeFile = envGlobal("writefile")
		local getAsset = envGlobal("getcustomasset") or envGlobal("getsynasset")
		if typeof(writeFile) ~= "function" or typeof(getAsset) ~= "function" then
			return nil
		end
		-- Never save an animated GIF as .png. The old implementation did that,
		-- which corrupts the asset and produces the gray/broken background shown
		-- when a GIF was selected.
		if detectImageExtension(decoded) == ".gif" or detectImageExtension(decoded) == ".webp" then
			-- Roblox cannot display these formats. The API rasterizes PNG frames instead.
			return nil
		end
		local ext = detectImageExtension(decoded)
		if string.match(fileName, "%.[%w]+$") then
			fileName = (string.gsub(fileName, "%.[%w]+$", ext))
		else
			fileName = fileName .. ext
		end
		pcall(writeFile, fileName, decoded)
		local ok, asset = pcall(getAsset, fileName)
		if not (ok and type(asset) == "string" and asset ~= "") then
			ok, asset = pcall(getAsset, fileName, true)
		end
		if ok and type(asset) == "string" and asset ~= "" then
			return asset
		end
		return nil
	end

	local function isRemoteImageUrl(value: string): boolean
		return string.find(value, "http://", 1, true) ~= nil or string.find(value, "https://", 1, true) ~= nil
	end

	local function animatedAssets(player: Player, style: any, kind: string): { string }
		local stamp = if type(style) == "table" then tostring(style.updated_at or "") else ""
		local cacheKey = kind .. ":" .. tostring(player.UserId) .. ":" .. stamp
		local cached = frameAssetCache[cacheKey]
		if cached then
			return cached
		end
		-- Always fetch PNG bytes from the host. Stable /media/... URLs keep showing the
		-- previous Discord upload because executors cache Image by URL.
		local frames: { string } = {}
		local payload = network.fetchSite("/images/nametag/" .. tostring(player.UserId) .. "/" .. kind .. "/b64")
		if type(payload) == "table" then
			if type(payload.delay) == "number" and type(style) == "table" then
				if kind == "icon" then
					style.icon_frame_delay = payload.delay
				else
					style.bg_frame_delay = payload.delay
				end
			end
			frames = normalizeGifFrames(payload.frames)
			if #frames == 0 and type(payload.data) == "string" then
				frames = { payload.data }
			end
		end
		if #frames == 0 then
			for _, frame in getGifFrames(style, kind) do
				if type(frame) == "string" and frame ~= "" and not isRemoteImageUrl(frame) then
					table.insert(frames, frame)
				end
			end
		end
		local fileStamp = (stamp:gsub("[^%w]", ""))
		if fileStamp == "" then
			fileStamp = tostring(math.floor(os.clock() * 1000))
		end
		local assets: { string } = {}
		for index, frame in frames do
			if string.find(frame, "://", 1, true) == nil and #frame >= 80 then
				local asset = assetFromB64(
					"ScorpTag" .. kind .. "F" .. tostring(index) .. "_" .. tostring(player.UserId) .. "_" .. fileStamp .. ".png",
					frame
				)
				if asset then
					table.insert(assets, asset)
				end
			elseif not isRemoteImageUrl(frame) then
				table.insert(assets, frame)
			end
		end
		if #assets > 0 then
			frameAssetCache[cacheKey] = assets
		end
		return assets
	end

	local function applyAnimatedImage(label: ImageLabel, player: Player, style: any, kind: string, fallback: (() -> string?)?)
		local gen = (tonumber(label:GetAttribute("ScorpAnimGen")) or 0) + 1
		pcall(function()
			label:SetAttribute("ScorpAnimGen", gen)
		end)
		label.Image = ""
		task.spawn(function()
			local frames = animatedAssets(player, style, kind)
			if not running or not isLiveEpoch(epoch) or not label.Parent or (tonumber(label:GetAttribute("ScorpAnimGen")) or 0) ~= gen then
				return
			end
			if #frames > 0 then
				animateImage(label, frames, getGifDelay(style, kind), gen)
				return
			end
			if fallback then
				local asset = fallback()
				if label.Parent and (tonumber(label:GetAttribute("ScorpAnimGen")) or 0) == gen and type(asset) == "string" and asset ~= "" then
					label.Image = asset
				end
			end
		end)
	end

	local function imageFromStyle(player: Player, style: any, kind: string, cache: { [number]: string }): string?
		local cached = cache[player.UserId]
		if type(cached) == "string" and cached ~= "" then
			return cached
		end
		local stamp = "0"
		if type(style) == "table" then
			stamp = tostring(style.updated_at or ""):gsub("[^%w]", "")
			if stamp == "" then
				stamp = tostring(math.floor(os.clock() * 1000))
			end
		end
		local fileName = "ScorpTag" .. kind .. "_" .. tostring(player.UserId) .. "_" .. stamp .. ".img"
		local b64Key = if kind == "bg" then "bg_b64" else "icon_b64"
		local b64 = if type(style) == "table" then style[b64Key] else nil
		if type(b64) == "string" and b64 ~= "" then
			local asset = assetFromB64(fileName, b64)
			if asset then
				cache[player.UserId] = asset
				return asset
			end
		end
		local payload = network.fetchSite("/images/nametag/" .. tostring(player.UserId) .. "/" .. kind .. "/b64")
		if type(payload) == "table" and type(payload.data) == "string" and payload.data ~= "" then
			local asset = assetFromB64(fileName, payload.data)
			if asset then
				cache[player.UserId] = asset
				return asset
			end
		end
		return nil
	end

	local function iconFor(player: Player, style: any): string
		if hasCustomIcon(style) then
			local asset = imageFromStyle(player, style, "icon", iconCache)
			if type(asset) == "string" and asset ~= "" then
				return asset
			end
		end
		if defaultIcon ~= "" then
			return defaultIcon
		end
		return avatarUrl(player.UserId)
	end

	local function bgFor(player: Player, style: any): string?
		if not hasCustomBg(style) then
			return nil
		end
		return imageFromStyle(player, style, "bg", bgCache)
	end

	local function signature(player: Player, style: any): string
		if type(style) ~= "table" then
			return table.concat({ tostring(player.UserId), player.DisplayName, player.Name, tostring(isStaffPlayer(player, nil)) }, "|")
		end
		return table.concat({
			tostring(player.UserId),
			tostring(style.display_name or ""),
			tostring(style.roblox_username or ""),
			tostring(style.outline_color or ""),
			tostring(style.text_color or ""),
			tostring(style.background_color or ""),
			tostring(style.icon_image_url or style.image_url or ""),
			table.concat(getGifFrames(style, "icon"), ","),
			tostring(getGifDelay(style, "icon")),
			tostring(style.bg_image_url or ""),
			table.concat(getGifFrames(style, "bg"), ","),
			tostring(getGifDelay(style, "bg")),
			tostring(style.font or ""),
			tostring(style.shape or ""),
			tostring(style.glitch or ""),
			tostring(style.updated_at or ""),
			tostring(isStaffPlayer(player, style)),
			tostring(hasVerifiedBadge(style)),
		}, "|")
	end

	local function getAttachPart(character: Model?): BasePart?
		if not character then
			return nil
		end
		for _, name in { "Head", "UpperTorso", "Torso", "HumanoidRootPart" } do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				return part
			end
		end
		return nil
	end

	local function textLooksLikePlayerName(text: string, player: Player): boolean
		if type(text) ~= "string" or text == "" then
			return false
		end
		local lowered = string.lower((string.gsub(text, "%s+", " ")))
		local name = string.lower(player.Name)
		local display = string.lower(player.DisplayName)
		if lowered == name or lowered == display or lowered == "@" .. name or lowered == "@" .. display then
			return true
		end
		if string.find(lowered, "@" .. name, 1, true) then
			return true
		end
		if display ~= "" and string.find(lowered, display, 1, true) and string.find(lowered, "@", 1, true) then
			return true
		end
		return false
	end

	local function hideDefaultName(character: Model?, player: Player?)
		suppressEngineNames()
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				humanoid.NameDisplayDistance = 0
				humanoid.HealthDisplayDistance = 0
				humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			end)
			local userId = if player then player.UserId else nil
			if userId and not nameHideConns[userId] then
				local bucket: { RBXScriptConnection } = {}
				local function relock()
					if running and isLiveEpoch(epoch) then
						pcall(function()
							humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
							humanoid.NameDisplayDistance = 0
							humanoid.HealthDisplayDistance = 0
						end)
						suppressEngineNames()
					end
				end
				pcall(function()
					table.insert(bucket, humanoid:GetPropertyChangedSignal("DisplayDistanceType"):Connect(relock))
					table.insert(bucket, humanoid:GetPropertyChangedSignal("NameDisplayDistance"):Connect(relock))
				end)
				if #bucket > 0 then
					nameHideConns[userId] = bucket
				end
			end
		end
		if not player then
			return
		end
		pcall(function()
			local function consider(inst: Instance)
				if not inst:IsA("BillboardGui") then
					return
				end
				local ours = false
				pcall(function()
					ours = inst:GetAttribute("ScorpNametag") == true
				end)
				if ours then
					return
				end
				local rival = isNametagBillboard(inst)
				if not rival then
					for _, desc in inst:GetChildren() do
						if desc:IsA("TextLabel") or desc:IsA("TextButton") then
							if textLooksLikePlayerName(tostring(desc.Text or ""), player) then
								rival = true
								break
							end
						end
					end
				end
				if rival then
					inst.Enabled = false
					pcall(function()
						inst.Adornee = nil
					end)
				end
			end
			for _, child in character:GetChildren() do
				consider(child)
				if child:IsA("BasePart") then
					for _, nested in child:GetChildren() do
						consider(nested)
					end
				end
			end
		end)
	end

	local function tagAlive(billboard: BillboardGui?): boolean
		return billboard ~= nil and billboard.Parent ~= nil
	end

	local function parkBillboard(billboard: BillboardGui)
		billboard.Enabled = false
		billboard.Adornee = nil
		if folder.Parent and billboard.Parent ~= folder then
			pcall(function()
				billboard.Parent = folder
			end)
		end
	end

	local function mountBillboard(gui: BillboardGui, part: BasePart)
		gui.Adornee = part
		if folder.Parent and gui.Parent ~= folder then
			pcall(function()
				gui.Parent = folder
			end)
		end
		if not gui.Parent then
			pcall(function()
				gui.Parent = folder
			end)
		end
		gui.Enabled = true
	end

	local function killRivalBillboards(ours: BillboardGui)
		if not tagAlive(ours) then
			return
		end
		local adornee = ours.Adornee
		if not adornee then
			return
		end
		pcall(function()
			for _, child in adornee:GetChildren() do
				if child:IsA("BillboardGui") and child ~= ours and isNametagBillboard(child) then
					local instEpoch = tonumber(child:GetAttribute("ScorpNametagEpoch"))
					if instEpoch ~= epoch then
						child.Enabled = false
						child.Adornee = nil
						child.Parent = nil
						child:Destroy()
					end
				end
			end
		end)
	end

	local function disconnectPlayer(userId: number)
		local conn = charConns[userId]
		if conn then
			conn:Disconnect()
			charConns[userId] = nil
		end
		local removing = charRemoving[userId]
		if removing then
			removing:Disconnect()
			charRemoving[userId] = nil
		end
		local appearance = charAppearance[userId]
		if appearance then
			appearance:Disconnect()
			charAppearance[userId] = nil
		end
		local hideConns = nameHideConns[userId]
		if hideConns then
			for _, hideConn in hideConns do
				hideConn:Disconnect()
			end
			nameHideConns[userId] = nil
		end
		local tag = tags[userId]
		if tag then
			tag:Destroy()
			tags[userId] = nil
		end
		styleSig[userId] = nil
	end

	local function attachToCharacter(player: Player, character: Model?)
		local gui = tags[player.UserId]
		if not tagAlive(gui) then
			return
		end
		if not character then
			parkBillboard(gui)
			return
		end
		local prevHide = nameHideConns[player.UserId]
		if prevHide then
			for _, hideConn in prevHide do
				hideConn:Disconnect()
			end
			nameHideConns[player.UserId] = nil
		end
		hideDefaultName(character, player)
		task.spawn(function()
			if not running or not isLiveEpoch(epoch) then
				return
			end
			local part = getAttachPart(character)
			if not part then
				local waited = character:WaitForChild("Head", 8)
				if waited and waited:IsA("BasePart") then
					part = waited
				end
			end
			local deadline = os.clock() + 8
			while not part and os.clock() < deadline and character.Parent and running and isLiveEpoch(epoch) do
				if player.Character ~= character then
					return
				end
				part = getAttachPart(character)
				if part then
					break
				end
				task.wait()
			end
			if not running or not isLiveEpoch(epoch) then
				return
			end
			gui = tags[player.UserId]
			if not tagAlive(gui) or player.Character ~= character then
				return
			end
			part = getAttachPart(character) or part
			if part and part.Parent then
				mountBillboard(gui, part)
			else
				parkBillboard(gui)
			end
			hideDefaultName(character, player)
		end)
	end

	local function bindCharacterWatch(player: Player)
		if charConns[player.UserId] then
			charConns[player.UserId]:Disconnect()
			charConns[player.UserId] = nil
		end
		if charRemoving[player.UserId] then
			charRemoving[player.UserId]:Disconnect()
			charRemoving[player.UserId] = nil
		end
		if charAppearance[player.UserId] then
			charAppearance[player.UserId]:Disconnect()
			charAppearance[player.UserId] = nil
		end
		charConns[player.UserId] = player.CharacterAdded:Connect(function(character)
			attachToCharacter(player, character)
		end)
		charRemoving[player.UserId] = player.CharacterRemoving:Connect(function()
			local gui = tags[player.UserId]
			if tagAlive(gui) then
				parkBillboard(gui)
			end
		end)
		pcall(function()
			charAppearance[player.UserId] = player.CharacterAppearanceLoaded:Connect(function(character)
				attachToCharacter(player, character)
			end)
		end)
		if player.Character then
			attachToCharacter(player, player.Character)
		end
	end

	local function createTag(player: Player)
		if not running or not isLiveEpoch(epoch) or not network.isScriptUser(player.UserId) then
			disconnectPlayer(player.UserId)
			return
		end
		local style = styles[player.UserId]
		local sig = signature(player, style)
		if tags[player.UserId] and not tagAlive(tags[player.UserId]) then
			tags[player.UserId] = nil
			styleSig[player.UserId] = nil
		end
		if tags[player.UserId] and styleSig[player.UserId] == sig then
			if not charConns[player.UserId] then
				bindCharacterWatch(player)
			else
				attachToCharacter(player, player.Character)
			end
			hideDefaultName(player.Character, player)
			return
		end
		disconnectPlayer(player.UserId)
		local verified = hasVerifiedBadge(style)
		local font = resolveFont(if type(style) == "table" then style.font else nil)
		local shownName = displayNameFor(player, style)
		local shownUser = usernameFor(player, style)
		local userText = "@" .. shownUser
		local nameW = textWidth(shownName, NAME_SIZE, font)
		local badgeW = 0
		if verified then
			badgeW = math.max(NAME_SIZE, textWidth(VERIFIED_BADGE_GLYPH, NAME_SIZE, Enum.Font.Gotham)) + 4
		end
		local userW = textWidth(userText, USER_SIZE, Enum.Font.Gotham)
		local textW = math.max(nameW + badgeW, userW)
		local width = math.clamp(math.ceil(ICON_LEFT + ICON_SIZE + TEXT_GAP + textW + PAD_RIGHT), 150, 330)
		local bg = if type(style) == "table" then hexColor(style.background_color, TAG_COLORS.bg) else TAG_COLORS.bg
		local fg = if type(style) == "table" then hexColor(style.text_color, TAG_COLORS.text) else TAG_COLORS.text
		local outline = if type(style) == "table" then hexColor(style.outline_color, Color3.new(1, 1, 1)) else Color3.new(1, 1, 1)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = tostring(player.UserId)
		billboard.AlwaysOnTop = true
		billboard.Active = player ~= localPlayer
		billboard.LightInfluence = 0
		billboard.MaxDistance = 500
		billboard.Size = UDim2.fromOffset(width, TAG_HEIGHT)
		billboard.StudsOffset = Vector3.new(0, 3.1, 0)
		pcall(function()
			billboard:SetAttribute("ScorpNametag", true)
			billboard:SetAttribute("ScorpNametagEpoch", epoch)
		end)
		pcall(function()
			billboard.Brightness = 2
		end)
		billboard.Parent = folder
		local container = Instance.new("Frame")
		container.Name = "Container"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundColor3 = bg
		container.BorderSizePixel = 0
		container.Parent = billboard
		local radius = cornerRadius(if type(style) == "table" then style.shape else nil)
		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = radius
		uiCorner.Parent = container
		local uiStroke = Instance.new("UIStroke")
		uiStroke.Thickness = 1
		uiStroke.Color = outline
		uiStroke.Transparency = 0
		uiStroke.Parent = container
		local bgImage = Instance.new("ImageLabel")
		bgImage.Name = "BgImage"
		bgImage.Size = UDim2.fromScale(1, 1)
		bgImage.BackgroundTransparency = 1
		bgImage.ScaleType = Enum.ScaleType.Crop
		bgImage.Visible = false
		bgImage.ZIndex = 0
		bgImage.Parent = container
		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = radius
		bgCorner.Parent = bgImage
		local bgFrames = getGifFrames(style, "bg")
		if #bgFrames > 0 or hasCustomBg(style) then
			container.BackgroundTransparency = 1
			container.ClipsDescendants = true
			bgImage.Visible = true
			applyAnimatedImage(bgImage, player, style, "bg", function()
				return bgFor(player, style)
			end)
		end
		local avatar = Instance.new("ImageLabel")
		avatar.BackgroundColor3 = bg
		avatar.BackgroundTransparency = 0.15
		avatar.BorderSizePixel = 0
		avatar.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
		avatar.Position = UDim2.new(0, ICON_LEFT, 0.5, 0)
		avatar.AnchorPoint = Vector2.new(0, 0.5)
		avatar.Image = if defaultIcon ~= "" then defaultIcon else avatarUrl(player.UserId)
		avatar.ScaleType = Enum.ScaleType.Fit
		avatar.ZIndex = 2
		avatar.Parent = container
		local avatarCorner = Instance.new("UICorner")
		avatarCorner.CornerRadius = UDim.new(0.36, 0)
		avatarCorner.Parent = avatar
		local iconFrames = getGifFrames(style, "icon")
		if #iconFrames > 0 or hasCustomIcon(style) then
			applyAnimatedImage(avatar, player, style, "icon", function()
				return iconFor(player, style)
			end)
		end
		local textLeft = ICON_LEFT + ICON_SIZE + TEXT_GAP
		local nameHost = Instance.new("Frame")
		nameHost.Name = "NameHost"
		nameHost.BackgroundTransparency = 1
		nameHost.Position = UDim2.fromOffset(textLeft, 10)
		nameHost.Size = UDim2.new(1, -(textLeft + PAD_RIGHT), 0, 21)
		nameHost.ZIndex = 2
		nameHost.Parent = container
		local nameLayout = Instance.new("UIListLayout")
		nameLayout.FillDirection = Enum.FillDirection.Horizontal
		nameLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		nameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		nameLayout.Padding = UDim.new(0, 3)
		nameLayout.SortOrder = Enum.SortOrder.LayoutOrder
		nameLayout.Parent = nameHost
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(0, math.ceil(nameW + 2), 1, 0)
		nameLabel.Font = font
		nameLabel.TextSize = NAME_SIZE
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.TextColor3 = fg
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Text = shownName
		nameLabel.LayoutOrder = 1
		nameLabel.ZIndex = 3
		pcall(function()
			nameLabel.AutoLocalize = false
		end)
		nameLabel.Parent = nameHost
		if verified then
			local badge = Instance.new("TextLabel")
			badge.Name = "Verified"
			badge.BackgroundTransparency = 1
			badge.Size = UDim2.fromOffset(math.ceil(badgeW - 2), NAME_SIZE)
			badge.Font = Enum.Font.Gotham
			badge.TextSize = NAME_SIZE
			badge.TextXAlignment = Enum.TextXAlignment.Center
			badge.TextYAlignment = Enum.TextYAlignment.Center
			badge.TextColor3 = Color3.fromRGB(255, 255, 255)
			badge.Text = VERIFIED_BADGE_GLYPH
			badge.LayoutOrder = 2
			badge.ZIndex = 4
			badge.Parent = nameHost
		end
		if type(style) == "table" and style.glitch == true then
			attachGlitch(nameLabel, true)
		end
		local userLabel = Instance.new("TextLabel")
		userLabel.BackgroundTransparency = 1
		userLabel.Position = UDim2.fromOffset(textLeft, 31)
		userLabel.Size = UDim2.new(1, -(textLeft + PAD_RIGHT), 0, 14)
		userLabel.Font = Enum.Font.Gotham
		userLabel.TextSize = USER_SIZE
		userLabel.TextTransparency = 0.5
		userLabel.TextXAlignment = Enum.TextXAlignment.Left
		userLabel.TextColor3 = fg
		userLabel.TextTruncate = Enum.TextTruncate.AtEnd
		userLabel.Text = userText
		userLabel.ZIndex = 2
		pcall(function()
			userLabel.AutoLocalize = false
		end)
		userLabel.Parent = container
		if player ~= localPlayer then
			local click = Instance.new("TextButton")
			click.Name = "ClickTarget"
			click.Size = UDim2.fromScale(1, 1)
			click.BackgroundTransparency = 1
			click.Text = ""
			click.AutoButtonColor = false
			click.Active = true
			click.ZIndex = 10
			click.Parent = container
			local function onClick()
				teleportToPlayer(player)
			end
			click.MouseButton1Click:Connect(onClick)
			click.Activated:Connect(onClick)
		end
		tags[player.UserId] = billboard
		styleSig[player.UserId] = sig
		billboard.Enabled = false
		bindCharacterWatch(player)
	end

	local function ingestStyles(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local users = payload.users
		if type(users) ~= "table" then
			users = payload
		end
		if type(users) ~= "table" then
			return
		end
		local nextStaff: { [number]: boolean } = {}
		for key, entry in users do
			if type(entry) == "table" then
				local userId = tonumber(entry.roblox_id) or tonumber(key)
				if userId then
					local staffOn = entry.staff == true
					if type(entry.staff) == "string" then
						local lowered = string.lower(entry.staff)
						staffOn = lowered == "1" or lowered == "true" or lowered == "yes" or lowered == "on"
					end
					if staffOn then
						nextStaff[userId] = true
					end
					local previous = styles[userId]
					styles[userId] = entry
					local stampChanged = type(previous) ~= "table"
						or tostring(previous.updated_at or "") ~= tostring(entry.updated_at or "")
						or tostring(previous.display_name or "") ~= tostring(entry.display_name or "")
						or tostring(previous.roblox_username or "") ~= tostring(entry.roblox_username or "")
						or tostring(previous.shape or "") ~= tostring(entry.shape or "")
						or tostring(previous.glitch or "") ~= tostring(entry.glitch or "")
						or tostring(previous.verified_badge or "") ~= tostring(entry.verified_badge or "")
						or tostring(previous.staff or "") ~= tostring(entry.staff or "")
						or tostring(previous.icon_image_url or previous.image_url or "")
							~= tostring(entry.icon_image_url or entry.image_url or "")
						or table.concat(getGifFrames(previous, "icon"), ",") ~= table.concat(getGifFrames(entry, "icon"), ",")
						or tostring(getGifDelay(previous, "icon")) ~= tostring(getGifDelay(entry, "icon"))
						or tostring(previous.bg_image_url or "") ~= tostring(entry.bg_image_url or "")
						or table.concat(getGifFrames(previous, "bg"), ",") ~= table.concat(getGifFrames(entry, "bg"), ",")
						or tostring(getGifDelay(previous, "bg")) ~= tostring(getGifDelay(entry, "bg"))
					if stampChanged then
						iconCache[userId] = nil
						bgCache[userId] = nil
						styleSig[userId] = nil
						for key in frameAssetCache do
							if string.find(key, ":" .. tostring(userId) .. ":", 1, true) then
								frameAssetCache[key] = nil
							end
						end
					end
				end
			end
		end
		local localId = localPlayer.UserId
		local localChanged = (FIREBASE_STAFF[localId] == true) ~= (nextStaff[localId] == true)
		table.clear(FIREBASE_STAFF)
		for userId, on in nextStaff do
			FIREBASE_STAFF[userId] = on
		end
		if localChanged then
			notifyStaffAccess()
		end
	end

	local function refresh()
		if not running or not isLiveEpoch(epoch) then
			return
		end
		local seen: { [number]: boolean } = {}
		for _, player in Players:GetPlayers() do
			if network.isScriptUser(player.UserId) then
				seen[player.UserId] = true
				createTag(player)
			end
		end
		for userId in tags do
			if not seen[userId] then
				disconnectPlayer(userId)
			end
		end
	end

	local function pullStyles()
		if not running or not isLiveEpoch(epoch) then
			return
		end
		local payload = network.fetchSite("/nametags")
		ingestStyles(payload)
		refresh()
	end

	table.insert(extraConns, Players.PlayerAdded:Connect(function(player)
		bindForeignJanitor(player:FindFirstChild("PlayerGui"))
		task.defer(function()
			createTag(player)
		end)
	end))
	table.insert(extraConns, Players.PlayerRemoving:Connect(function(player)
		disconnectPlayer(player.UserId)
	end))
	network.onScriptUsersChanged(refresh)
	refresh()
	if localPlayer.Character then
		hideDefaultName(localPlayer.Character, localPlayer)
	end
	task.spawn(pullStyles)
	task.spawn(function()
		local nextStrip = 0
		local function disableForeignGui(parent: Instance?)
			if not parent then
				return
			end
			pcall(function()
				for _, child in parent:GetChildren() do
					if child:IsA("ScreenGui") and child ~= hostGui and child ~= tagGui then
						local lower = string.lower(child.Name)
						if child.Name == GUI_NAME
							or child.Name == "ScorpNametagGui"
							or string.find(lower, "cryax", 1, true)
							or string.find(lower, "cryax", 1, true)
						then
							child.Enabled = false
						end
					end
				end
			end)
		end
		while running and isLiveEpoch(epoch) do
			if os.clock() >= nextStrip then
				pcall(function()
					local pg = localPlayer:FindFirstChild("PlayerGui")
					if pg and tagGui.Parent ~= pg then
						tagGui.Parent = pg
					end
				end)
				stripForeignNametags(folder, epoch)
				disableForeignGui(executorGethui())
				disableForeignGui(localPlayer:FindFirstChild("PlayerGui"))
				nextStrip = os.clock() + 5
			end
			for userId, billboard in tags do
				if not tagAlive(billboard) then
					tags[userId] = nil
					styleSig[userId] = nil
					local player = Players:GetPlayerByUserId(userId)
					if player then
						createTag(player)
					end
				else
					local player = Players:GetPlayerByUserId(userId)
					local character = if player then player.Character else nil
					local part = getAttachPart(character)
					if part then
						if billboard.Adornee ~= part or billboard.Parent ~= folder or not billboard.Enabled then
							mountBillboard(billboard, part)
						end
					elseif billboard.Enabled or billboard.Adornee then
						parkBillboard(billboard)
					end
				end
			end
			task.wait(1.5)
		end
	end)
	task.spawn(function()
		local lastRev = -1
		local lastUsers: { [string]: string } = {}
		while running and isLiveEpoch(epoch) do
			local snapshot = network.fetchSite("/nametags/revision")
			local changed = false
			if type(snapshot) == "table" then
				local rev = tonumber(snapshot.revision) or 0
				if rev ~= lastRev then
					changed = true
				end
				local users = snapshot.users
				if type(users) == "table" then
					for userId, updatedAt in users do
						local key = tostring(userId)
						if lastUsers[key] ~= tostring(updatedAt or "") then
							changed = true
						end
					end
					for key in lastUsers do
						if users[key] == nil then
							changed = true
							break
						end
					end
				end
				if changed then
					lastRev = rev
					table.clear(lastUsers)
					if type(users) == "table" then
						for userId, updatedAt in users do
							lastUsers[tostring(userId)] = tostring(updatedAt or "")
						end
					end
					pullStyles()
				end
			end
			task.wait(2)
		end
	end)

	return {
		refresh = refresh,
		cleanup = function()
			running = false
			pcall(function()
				local env = executorTable()
				if type(env) == "table" and (env :: any).ScorpLiveNametagFolder == folder then
					env.ScorpLiveNametagFolder = nil
				end
			end)
			for _, conn in extraConns do
				conn:Disconnect()
			end
			table.clear(extraConns)
			for userId in tags do
				disconnectPlayer(userId)
			end
			pcall(function()
				tagGui:Destroy()
			end)
		end,
	}
end

function MainUI.mount(parent: Instance?): ScreenGui
	local clientEpoch = bumpScorpEpoch()
	local LocalPlayer = getLocalPlayer()
	table.clear(staffAccessListeners)
	local openStaffPanel = function() end
	local guiParent = resolveGuiParent(LocalPlayer, parent)
	pcall(function()
		destroyExisting(GUI_NAME, LocalPlayer, guiParent)
	end)
	local network = createClientNetwork(LocalPlayer)
	local executorName, executorVersion = detectExecutor()
	local executorLabel = executorName
	if executorVersion then
		executorLabel = `{executorName} {executorVersion}`
	end

	local gui = apply(Instance.new("ScreenGui"), {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999999,
		Enabled = true,
	}) :: ScreenGui
	pcall(function()
		gui:SetAttribute("ScorpClientEpoch", clientEpoch)
	end)
	protectGui(gui)
	local parentOk = pcall(function()
		gui.Parent = guiParent
	end)
	if not parentOk or not gui.Parent then
		pcall(function()
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end)
	end

	local miscTools = createMiscTools(LocalPlayer, gui)
	local scriptTags = createScriptTags(LocalPlayer, gui, network, miscTools.teleportToPlayer)
	local unloaded = false
	local hubConns: { RBXScriptConnection } = {}
	local emotePanelCtl: { toggle: () -> (), destroy: () -> (), isOpen: () -> boolean }? = nil
	local function trackHub(conn: RBXScriptConnection): RBXScriptConnection
		table.insert(hubConns, conn)
		return conn
	end
	local function unloadScript()
		if unloaded then
			return
		end
		unloaded = true
		pcall(function()
			local env = executorTable()
			if type(env) == "table" then
				if tonumber((env :: any).ScorpClientEpoch) == clientEpoch then
					CLIENT_EPOCH = clientEpoch + 1
					env.ScorpClientEpoch = CLIENT_EPOCH
				end
				env.ScorpClientCleanup = nil
				env.ScorpLiveNametagFolder = nil
			end
		end)
		for _, conn in hubConns do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(hubConns)
		if emotePanelCtl then
			pcall(function()
				emotePanelCtl.destroy()
			end)
			emotePanelCtl = nil
		end
		pcall(function()
			scriptTags.cleanup()
		end)
		pcall(function()
			network.stop()
		end)
		pcall(function()
			miscTools.cleanup()
		end)
		pcall(function()
			local leftover = Lighting:FindFirstChild("ScorpClientBlur")
			if leftover then
				leftover:Destroy()
			end
		end)
		pcall(function()
			local ContextActionService = game:GetService("ContextActionService")
			ContextActionService:UnbindAction("ScorpEmoteMenu")
			ContextActionService:UnbindCoreAction("ScorpEmoteMenu")
		end)
		pcall(function()
			gui:Destroy()
		end)
	end
	setScorpCleanup(unloadScript)
	gui.Destroying:Connect(function()
		if not unloaded then
			unloadScript()
		end
	end)

	local ownerToastHost = frame({
		Name = "OwnerToasts",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 200),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 300,
		Parent = gui,
	})
	local activeToasts: { Frame } = {}
	local TWEEN_TOAST = TWEEN_SLIDE

	local function playOwnerJoinSound()
		local sound = Instance.new("Sound")
		sound.Name = "ScorpOwnerJoin"
		sound.SoundId = OWNER_JOIN_SOUND
		sound.Volume = 1
		sound.Parent = SoundService
		pcall(function()
			sound:Play()
		end)
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(6, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end

	local function toastRestY(index: number): number
		return 12 + (index - 1) * 66
	end

	local function relayoutOwnerToasts()
		for index, item in activeToasts do
			tween(item, TWEEN_TOAST, { Position = UDim2.new(0.5, 0, 0, toastRestY(index)) })
		end
	end

	local function resolveOwnerPlayer(userId: number?, displayName: string): (Player?, number?)
		if userId and userId > 0 then
			local byId = Players:GetPlayerByUserId(userId)
			if byId then
				return byId, userId
			end
			return nil, userId
		end
		local needle = string.lower(displayName)
		for _, player in Players:GetPlayers() do
			if STAFF_IDS[player.UserId] then
				if string.lower(player.DisplayName) == needle or string.lower(player.Name) == needle then
					return player, player.UserId
				end
			end
		end
		for _, player in Players:GetPlayers() do
			if STAFF_IDS[player.UserId] and player ~= LocalPlayer then
				return player, player.UserId
			end
		end
		if STAFF_IDS[LocalPlayer.UserId] then
			return LocalPlayer, LocalPlayer.UserId
		end
		return nil, nil
	end

	local function showOwnerJoinToast(displayName: string, userId: number?, force: boolean?, alreadyHere: boolean?)
		local ownerPlayer, ownerId = resolveOwnerPlayer(userId, displayName)
		if not force then
			if ownerId == LocalPlayer.UserId then
				return
			end
			if ownerId and not STAFF_IDS[ownerId] then
				return
			end
			if not ownerId then
				return
			end
		end
		local shownName = if ownerPlayer then ownerPlayer.DisplayName else displayName
		playOwnerJoinSound()
		local canTeleport = ownerPlayer ~= nil and ownerPlayer ~= LocalPlayer
		local toastWidth = if canTeleport then 292 else 248

		local toast = textButton({
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(toastWidth, 56),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -80),
			BackgroundColor3 = COLORS.bg,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 301,
			Parent = ownerToastHost,
		})
		corner(toast, 10)
		toast.BackgroundTransparency = 0.15
		local toastStroke = candleStroke(toast, 2, 0.2)
		local bar = frame({
			BackgroundColor3 = COLORS.accent,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(2, 22),
			Position = UDim2.fromOffset(10, 17),
			ZIndex = 302,
			Parent = toast,
		})
		corner(bar, 1)
		local textX = 20
		if ownerId and ownerId > 0 then
			local face = apply(Instance.new("ImageLabel"), {
				BackgroundColor3 = COLORS.statBg,
				Image = avatarUrl(ownerId),
				Size = UDim2.fromOffset(32, 32),
				Position = UDim2.fromOffset(20, 12),
				ZIndex = 302,
				Parent = toast,
			}) :: ImageLabel
			corner(face, 6)
			stroke(face, COLORS.border, 1, 0.22)
			textX = 62
		end
		local nameRow = frame({
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			Position = UDim2.fromOffset(textX, 10),
			ZIndex = 303,
			Parent = toast,
		})
		apply(Instance.new("UIListLayout"), {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = nameRow,
		})
		textLabel({
			Text = shownName,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			LayoutOrder = 1,
			ZIndex = 304,
			Parent = nameRow,
		})
		textLabel({
			Text = VERIFIED_BADGE_GLYPH,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			LayoutOrder = 2,
			ZIndex = 304,
			Parent = nameRow,
		})
		textLabel({
			Text = if alreadyHere then "Already in this server" else "Owner joined",
			TextColor3 = COLORS.dim,
			TextSize = 11,
			Size = UDim2.new(1, if canTeleport then -textX - 78 else -textX - 14, 0, 14),
			Position = UDim2.fromOffset(textX, 30),
			ZIndex = 304,
			Parent = toast,
		})
		if canTeleport and ownerPlayer then
			local tpBtn = textButton({
				Text = "Teleport",
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				Size = UDim2.fromOffset(62, 24),
				Position = UDim2.new(1, -72, 0.5, -12),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.subtext,
				ZIndex = 305,
				Parent = toast,
			})
			tpBtn.MouseEnter:Connect(function()
				tween(tpBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
			end)
			tpBtn.MouseLeave:Connect(function()
				tween(tpBtn, TWEEN_FAST, { TextColor3 = COLORS.subtext })
			end)
			tpBtn.MouseButton1Click:Connect(function()
				miscTools.teleportToPlayer(ownerPlayer)
			end)
		end

		table.insert(activeToasts, toast)
		relayoutOwnerToasts()

		local dismissed = false
		local function dismiss()
			if dismissed or not toast.Parent then
				return
			end
			dismissed = true
			for index, item in activeToasts do
				if item == toast then
					table.remove(activeToasts, index)
					break
				end
			end
			tween(toast, TWEEN_SLIDE_OUT, { Position = UDim2.new(0.5, 0, 0, -80) })
			if toastStroke then
				tween(toastStroke, TWEEN_SLIDE_OUT, { Transparency = 1 })
			end
			relayoutOwnerToasts()
			task.delay(0.34, function()
				if toast.Parent then
					toast:Destroy()
				end
			end)
		end
		toast.MouseButton1Click:Connect(dismiss)
		task.delay(6.5, dismiss)
	end

	for _, player in Players:GetPlayers() do
		if STAFF_IDS[player.UserId] and player ~= LocalPlayer then
			showOwnerJoinToast(player.DisplayName, player.UserId, false, true)
		end
	end
	trackHub(Players.PlayerAdded:Connect(function(player)
		if STAFF_IDS[player.UserId] then
			showOwnerJoinToast(player.DisplayName, player.UserId, false, false)
		end
	end))
	network.onOwnerJoinCommand(function(name: string, userId: number?)
		showOwnerJoinToast(if name ~= "" then name else "Owner", userId, true, false)
	end)

	local windowOpen = true
	local activeTab: TabId = "home"

	pcall(function()
		local leftover = Lighting:FindFirstChild("ScorpClientBlur")
		if leftover then
			leftover:Destroy()
		end
	end)

	local window = frame({
		Name = "Window",
		Size = UDim2.fromOffset(LAYOUT.width, LAYOUT.height),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.bg,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		Parent = gui,
	})
	corner(window, LAYOUT.corner)
	candleStroke(window, 2, 0.15, true)
	apply(Instance.new("UIGradient"), {
		Rotation = -45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 15, 18)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 12, 16)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 15, 20)),
		}),
		Parent = window,
	})
	local windowScale = apply(Instance.new("UIScale"), {
		Scale = 1,
		Parent = window,
	}) :: UIScale

	local sidebar = frame({
		Name = "Sidebar",
		BackgroundColor3 = COLORS.sidebar,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(0, LAYOUT.sidebar, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		ClipsDescendants = true,
		Parent = window,
	})

	local logoArea = frame({
		Name = "LogoArea",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 62),
		Active = true,
		Parent = sidebar,
	})
	local logo = textLabel({
		Name = "Title",
		Text = "SCORP",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 8),
		Parent = logoArea,
	})
	breathe(apply(Instance.new("UIGradient"), {
		Rotation = 0,
		Parent = logo,
	}) :: UIGradient)
	textLabel({
		Name = "Version",
		Text = `v{SCRIPT_VERSION}`,
		TextColor3 = COLORS.dim,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = logoArea,
	})
	local logoLine = frame({
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -40, 0, 2),
		Position = UDim2.new(0, 20, 1, -2),
		Parent = logoArea,
	})
	breathe(apply(Instance.new("UIGradient"), {
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.7),
		}),
		Parent = logoLine,
	}) :: UIGradient)

	local navList = apply(Instance.new("ScrollingFrame"), {
		Name = "NavList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -92),
		Position = UDim2.fromOffset(0, 70),
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = sidebar,
	}) :: ScrollingFrame
	apply(Instance.new("UIListLayout"), {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = navList,
	})
	apply(Instance.new("UIPadding"), {
		PaddingTop = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		Parent = navList,
	})

	local content = frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -LAYOUT.sidebar, 1, 0),
		Position = UDim2.fromOffset(LAYOUT.sidebar, 0),
		ClipsDescendants = true,
		Parent = window,
	})
	local topStrip = frame({
		Name = "TopStrip",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Active = true,
		Parent = content,
	})
	local toggleHint = textLabel({
		Text = `[{displayKeyName(keybindValues.toggleUi or "RightShift")}] Toggle`,
		TextColor3 = COLORS.dim,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(0, 0),
		Parent = topStrip,
	})
	onKeybindsChanged(function()
		toggleHint.Text = `[{displayKeyName(keybindValues.toggleUi or "RightShift")}] Toggle`
	end)
	local pagesHost = frame({
		Name = "Pages",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -28),
		Position = UDim2.fromOffset(0, 28),
		Parent = content,
	})

	local pages: { [TabId]: Frame } = {}
	local navButtons: { [TabId]: TextButton } = {}
	local navPips: { [TabId]: Frame } = {}
	local navLabels: { [TabId]: TextLabel } = {}
	local navGlows: { [TabId]: UIStroke } = {}
	local navScales: { [TabId]: UIScale } = {}
	local closePlayerMenu = function() end

	local function showTab(id: TabId)
		activeTab = id
		if id ~= "keybinds" and keybindCapturingId then
			keybindCapturingId = nil
			notifyKeybindChange()
		end
		if id ~= "players" then
			closePlayerMenu()
		end
		for tabId, page in pages do
			page.Visible = tabId == id
		end
		for tabId, btn in navButtons do
			local selected = tabId == id
			local pip = navPips[tabId]
			if pip then
				pip.Visible = selected
			end
			local label = navLabels[tabId]
			if label then
				tween(label, TWEEN_FAST, { TextColor3 = if selected then COLORS.text else COLORS.subtext })
			end
			local glow = navGlows[tabId]
			if glow then
				tween(glow, TWEEN_FAST, { Transparency = if selected then 0 else 0.6 })
			end
			btn.BackgroundTransparency = 1
		end
	end

	local function addNav(id: TabId, labelText: string, order: number)
		local selected = id == "home"
		local btn = textButton({
			Name = id,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Parent = navList,
		})
		local glowLabel = textLabel({
			Text = labelText,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -16, 1, 0),
			ZIndex = 1,
			Parent = btn,
		})
		local glow = apply(Instance.new("UIStroke"), {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = Color3.new(1, 1, 1),
			Thickness = 1.5,
			Transparency = if selected then 0 else 0.6,
			Parent = glowLabel,
		}) :: UIStroke
		paintCandle(apply(Instance.new("UIGradient"), {
			Rotation = 0,
			Parent = glow,
		}) :: UIGradient)
		local label = textLabel({
			Text = labelText,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = if selected then COLORS.text else COLORS.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -16, 1, 0),
			ZIndex = 2,
			Parent = btn,
		})
		local pip = frame({
			BackgroundColor3 = COLORS.accent,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Visible = selected,
			Size = UDim2.fromOffset(4, 18),
			Position = UDim2.fromOffset(-4, 7),
			ZIndex = 3,
			Parent = btn,
		})
		round(pip)
		local scale = apply(Instance.new("UIScale"), {
			Scale = 1,
			Parent = btn,
		}) :: UIScale
		navButtons[id] = btn
		navPips[id] = pip
		navLabels[id] = label
		navGlows[id] = glow
		navScales[id] = scale
		btn.MouseEnter:Connect(function()
			tween(scale, TWEEN_BACK, { Scale = 1.05 })
			tween(glowLabel, TWEEN_FAST, { Position = UDim2.fromOffset(18, 0) })
			tween(label, TWEEN_FAST, { Position = UDim2.fromOffset(18, 0), TextColor3 = COLORS.text })
			if not pip.Visible then
				tween(glow, TWEEN_FAST, { Transparency = 0.2 })
			end
		end)
		btn.MouseLeave:Connect(function()
			tween(scale, TWEEN_FAST, { Scale = 1 })
			tween(glowLabel, TWEEN_FAST, { Position = UDim2.fromOffset(12, 0) })
			tween(label, TWEEN_FAST, {
				Position = UDim2.fromOffset(12, 0),
				TextColor3 = if activeTab == id then COLORS.text else COLORS.subtext,
			})
			if not pip.Visible then
				tween(glow, TWEEN_FAST, { Transparency = 0.6 })
			end
		end)
		btn.MouseButton1Click:Connect(function()
			tween(scale, TWEEN_FAST, { Scale = 0.95 })
			task.delay(0.1, function()
				if scale.Parent then
					tween(scale, TWEEN_BACK, { Scale = 1 })
				end
			end)
			showTab(id)
		end)
	end

	addNav("home", "  🏠  Home", 1)
	addNav("players", "  👥  Players", 2)
	addNav("misc", "  🧰  Misc", 3)
	addNav("keybinds", "  ⌨️  Keybinds", 4)
	addNav("settings", "  ⚙  Settings", 5)
	local moreOrder = 6
	local moreHeader = frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = moreOrder,
		Parent = navList,
	})
	local moreLine = frame({
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 0, 2),
		Position = UDim2.fromOffset(8, 4),
		Parent = moreHeader,
	})
	paintCandle(apply(Instance.new("UIGradient"), {
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.8),
		}),
		Parent = moreLine,
	}) :: UIGradient)
	textLabel({
		Text = "QUICK ACTIONS",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = COLORS.dim,
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -12, 0, 14),
		Parent = moreHeader,
	})
	local function addNavScript(name: string, url: string, order: number, mark: string?)
		local btn = textButton({
			Name = name,
			Text = "",
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = order,
			BackgroundColor3 = COLORS.trackOff,
			BackgroundTransparency = 0.3,
			Parent = navList,
		})
		corner(btn, 8)
		candleStroke(btn, 1, 0.2)
		hoverGrow(btn, 1.05)
		local textX = 12
		local markLabel: TextLabel? = nil
		if mark == "infinity" then
			markLabel = textLabel({
				Text = utf8.char(0x221E),
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				TextColor3 = COLORS.dim,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(4, 0),
				Size = UDim2.fromOffset(18, 32),
				ZIndex = 2,
				Parent = btn,
			})
			textX = 24
		end
		local label = textLabel({
			Text = name,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = COLORS.subtext,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(textX, 0),
			Size = UDim2.new(1, -textX - 8, 1, 0),
			Parent = btn,
		})
		btn.MouseEnter:Connect(function()
			tween(btn, TWEEN_FAST, { BackgroundTransparency = 0.1 })
			tween(label, TWEEN_FAST, { TextColor3 = COLORS.text })
			if markLabel then
				tween(markLabel, TWEEN_FAST, { TextColor3 = COLORS.text })
			end
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, TWEEN_FAST, { BackgroundTransparency = 0.3 })
			tween(label, TWEEN_FAST, { TextColor3 = COLORS.subtext })
			if markLabel then
				tween(markLabel, TWEEN_FAST, { TextColor3 = COLORS.dim })
			end
		end)
		btn.MouseButton1Click:Connect(function()
			runRemoteLoadstring(url)
		end)
	end
	addNavScript(
		"Infinite Yield",
		"https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
		moreOrder + 1,
		"infinity"
	)
	addNavScript(
		"PShade Ultimate",
		"https://raw.githubusercontent.com/randomstring0/pshade-ultimate/refs/heads/main/src/cd.lua",
		moreOrder + 2
	)

	-- Home
	local home = apply(Instance.new("ScrollingFrame"), {
		Name = "Home",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = pagesHost,
	}) :: ScrollingFrame
	pages.home = home
	apply(Instance.new("UIListLayout"), {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = home,
	})
	apply(Instance.new("UIPadding"), {
		PaddingTop = UDim.new(0, LAYOUT.pad),
		PaddingBottom = UDim.new(0, LAYOUT.pad),
		PaddingLeft = UDim.new(0, LAYOUT.pad),
		PaddingRight = UDim.new(0, LAYOUT.pad),
		Parent = home,
	})

	local profile = frame({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 1,
		Parent = home,
	})

	local avatar = apply(Instance.new("ImageLabel"), {
		BackgroundColor3 = COLORS.statBg,
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(0, 6),
		Image = avatarUrl(LocalPlayer.UserId),
		Parent = profile,
	}) :: ImageLabel
	corner(avatar, 6)
	stroke(avatar, COLORS.border, 1, 0.2)

	textLabel({
		Text = LocalPlayer.DisplayName,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Position = UDim2.fromOffset(46, 6),
		Size = UDim2.new(1, -46, 0, 18),
		Parent = profile,
	})
	textLabel({
		Text = `@{LocalPlayer.Name}  ·  {executorName}`,
		TextColor3 = COLORS.dim,
		TextSize = 11,
		Position = UDim2.fromOffset(46, 24),
		Size = UDim2.new(1, -46, 0, 16),
		Parent = profile,
	})

	local statsRow = frame({
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 2,
		Parent = home,
	})
	corner(statsRow, 8)
	statsRow.BackgroundTransparency = 0.2
	candleStroke(statsRow, 1, 0.25)

	local function statCol(name: string, value: string, xScale: number): TextLabel
		textLabel({
			Text = string.upper(name),
			Font = Enum.Font.GothamBold,
			TextColor3 = COLORS.dim,
			TextSize = 9,
			Position = UDim2.new(xScale, 12, 0, 8),
			Size = UDim2.new(1 / 3, -16, 0, 12),
			Parent = statsRow,
		})
		return textLabel({
			Text = value,
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(xScale, 12, 0, 22),
			Size = UDim2.new(1 / 3, -16, 0, 18),
			Parent = statsRow,
		})
	end

	local fpsLabel = statCol("FPS", "--", 0)
	local pingLabel = statCol("PING", "--", 1 / 3)
	local executorStat = statCol("EXECUTOR", executorLabel, 2 / 3)
	executorStat.TextSize = 13
	executorStat.TextColor3 = COLORS.subtext

	frame({
		BackgroundColor3 = COLORS.border,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, -16),
		Position = UDim2.new(1 / 3, 0, 0, 8),
		Parent = statsRow,
	})
	frame({
		BackgroundColor3 = COLORS.border,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, -16),
		Position = UDim2.new(2 / 3, 0, 0, 8),
		Parent = statsRow,
	})

	local changelogCard = frame({
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 148),
		LayoutOrder = 3,
		Parent = home,
	})
	corner(changelogCard, 8)
	changelogCard.BackgroundTransparency = 0.2
	candleStroke(changelogCard, 1, 0.25)
	textLabel({
		Text = "Changelog",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = COLORS.subtext,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 16),
		Parent = changelogCard,
	})

	local logScroll = apply(Instance.new("ScrollingFrame"), {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 1, -32),
		Position = UDim2.fromOffset(6, 28),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = COLORS.border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = changelogCard,
	}) :: ScrollingFrame
	apply(Instance.new("UIListLayout"), {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = logScroll,
	})
	apply(Instance.new("UIPadding"), {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = logScroll,
	})

	for index, entry in CHANGELOG do
		local row = frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 0, 32),
			LayoutOrder = index,
			Parent = logScroll,
		})
		textLabel({
			Text = `v{entry.version}`,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = COLORS.dim,
			Size = UDim2.fromOffset(36, 16),
			Position = UDim2.fromOffset(0, 0),
			Parent = row,
		})
		textLabel({
			Text = entry.title,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -40, 0, 16),
			Parent = row,
		})
		textLabel({
			Text = entry.body,
			TextColor3 = COLORS.dim,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(40, 15),
			Size = UDim2.new(1, -40, 0, 14),
			Parent = row,
		})
	end

	local moreCard = frame({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 4,
		Parent = home,
	})

	textLabel({
		Text = "Discord",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.new(1, -88, 0, 18),
		Parent = moreCard,
	})
	local discordBtn = textButton({
		Text = "Copy invite",
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		Size = UDim2.fromOffset(80, 24),
		Position = UDim2.new(1, -80, 0.5, -12),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.subtext,
		Parent = moreCard,
	})
	discordBtn.MouseEnter:Connect(function()
		tween(discordBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
	end)
	discordBtn.MouseLeave:Connect(function()
		tween(discordBtn, TWEEN_FAST, { TextColor3 = COLORS.subtext })
	end)
	discordBtn.MouseButton1Click:Connect(function()
		if copyText(DISCORD_INVITE) then
			discordBtn.Text = "Copied"
			task.delay(1.4, function()
				if discordBtn.Parent then
					discordBtn.Text = "Copy invite"
				end
			end)
		else
			discordBtn.Text = "Copy"
		end
	end)

	local staffOpen = textButton({
		Text = "Staff",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 5,
		BackgroundTransparency = 1,
		TextColor3 = COLORS.subtext,
		Visible = isScriptStaff(LocalPlayer.UserId),
		Parent = home,
	})
	staffOpen.MouseEnter:Connect(function()
		tween(staffOpen, TWEEN_FAST, { TextColor3 = COLORS.text })
	end)
	staffOpen.MouseLeave:Connect(function()
		tween(staffOpen, TWEEN_FAST, { TextColor3 = COLORS.subtext })
	end)
	staffOpen.MouseButton1Click:Connect(function()
		openStaffPanel()
	end)
	table.insert(staffAccessListeners, function()
		if staffOpen.Parent then
			staffOpen.Visible = isScriptStaff(LocalPlayer.UserId)
		end
	end)

	-- Players
	local playersPage = frame({
		Name = "Players",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = pagesHost,
	})
	pages.players = playersPage

	local list = apply(Instance.new("ScrollingFrame"), {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -LAYOUT.pad * 2, 1, -LAYOUT.pad * 2),
		Position = UDim2.fromOffset(LAYOUT.pad, LAYOUT.pad),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = playersPage,
	}) :: ScrollingFrame
	apply(Instance.new("UIListLayout"), {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.Name,
		Parent = list,
	})

	local playerMenuTarget: Player? = nil
	local highlightedRow: GuiObject? = nil
	local playerActionButtons: { TextButton } = {}

	local playerMenu = frame({
		Name = "PlayerActions",
		Size = UDim2.fromOffset(168, 176),
		BackgroundColor3 = COLORS.bg,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = 70,
		Parent = window,
	})
	corner(playerMenu, 8)
	stroke(playerMenu, COLORS.border, 1, 0.25)
	apply(Instance.new("UIListLayout"), {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = playerMenu,
	})
	apply(Instance.new("UIPadding"), {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = playerMenu,
	})

	closePlayerMenu = function()
		playerMenu.Visible = false
		playerMenuTarget = nil
		if highlightedRow then
			pcall(function()
				highlightedRow.BackgroundColor3 = COLORS.card
			end)
			highlightedRow = nil
		end
	end

	local function mouseInside(object: GuiObject): boolean
		local mouse = UserInputService:GetMouseLocation()
		local inset = Vector2.zero
		if GuiService then
			pcall(function()
				inset = GuiService:GetGuiInset()
			end)
		end
		local pos = object.AbsolutePosition
		local size = object.AbsoluteSize
		local function inside(point: Vector2): boolean
			return point.X >= pos.X
				and point.X <= pos.X + size.X
				and point.Y >= pos.Y
				and point.Y <= pos.Y + size.Y
		end
		return inside(mouse) or inside(mouse - inset)
	end

	local function refreshPlayerActionStyles()
		local target = playerMenuTarget
		for _, btn in playerActionButtons do
			local id = btn.Name
			local active = false
			if target then
				if id == "view" then
					active = miscTools.isSpectating(target)
					btn.Text = if active then "Unview" else "View"
				elseif id == "headsit" then
					active = miscTools.isSit() and miscTools.getSitTarget() == target and miscTools.getSitMode() == "head"
				elseif id == "backpack" then
					active = miscTools.isSit() and miscTools.getSitTarget() == target and miscTools.getSitMode() == "back"
				end
			end
			btn.BackgroundColor3 = if active then COLORS.accentDim else COLORS.card
			btn.TextColor3 = if active then COLORS.accent else COLORS.text
		end
	end

	local function openPlayerMenu(player: Player, row: GuiObject)
		if player == LocalPlayer then
			return
		end
		if playerMenuTarget == player and playerMenu.Visible then
			closePlayerMenu()
			return
		end
		if highlightedRow and highlightedRow ~= row then
			pcall(function()
				highlightedRow.BackgroundColor3 = COLORS.card
			end)
		end
		playerMenuTarget = player
		highlightedRow = row
		row.BackgroundColor3 = COLORS.accentDim
		refreshPlayerActionStyles()
		local rowAbs = row.AbsolutePosition
		local rowSize = row.AbsoluteSize
		local winAbs = window.AbsolutePosition
		local winSize = window.AbsoluteSize
		local menuSize = playerMenu.AbsoluteSize
		if menuSize.X < 8 then
			menuSize = Vector2.new(168, 176)
		end
		local x = rowAbs.X - winAbs.X + rowSize.X - menuSize.X
		local y = rowAbs.Y - winAbs.Y + rowSize.Y + 6
		if y + menuSize.Y > winSize.Y - 10 then
			y = rowAbs.Y - winAbs.Y - menuSize.Y - 6
		end
		x = math.clamp(x, 10, math.max(10, winSize.X - menuSize.X - 10))
		y = math.clamp(y, 10, math.max(10, winSize.Y - menuSize.Y - 10))
		playerMenu.Position = UDim2.fromOffset(x, y)
		playerMenu.Visible = true
	end

	local function addPlayerAction(id: string, labelText: string, order: number, onClick: (Player) -> ())
		local btn = textButton({
			Name = id,
			Text = labelText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = order,
			BackgroundColor3 = COLORS.card,
			ZIndex = 71,
			Parent = playerMenu,
		})
		corner(btn, 8)
		apply(Instance.new("UIPadding"), {
			PaddingLeft = UDim.new(0, 10),
			Parent = btn,
		})
		btn.MouseEnter:Connect(function()
			if btn.TextColor3 ~= COLORS.accent then
				tween(btn, TWEEN_FAST, { BackgroundColor3 = COLORS.statBg })
			end
		end)
		btn.MouseLeave:Connect(function()
			refreshPlayerActionStyles()
		end)
		btn.MouseButton1Click:Connect(function()
			local target = playerMenuTarget
			if not target then
				return
			end
			onClick(target)
			if id == "view" or id == "headsit" or id == "backpack" then
				refreshPlayerActionStyles()
			end
			closePlayerMenu()
		end)
		table.insert(playerActionButtons, btn)
	end

	addPlayerAction("teleport", "Teleport to", 1, function(target)
		miscTools.stopSpectate()
		miscTools.teleportToPlayer(target)
	end)
	addPlayerAction("backpack", "Backpack", 2, function(target)
		miscTools.stopSpectate()
		miscTools.setFlyEnabled(false)
		miscTools.sitOnPlayer(target, "back")
	end)
	addPlayerAction("headsit", "Headsit", 3, function(target)
		miscTools.stopSpectate()
		miscTools.setFlyEnabled(false)
		miscTools.sitOnPlayer(target, "head")
	end)
	addPlayerAction("view", "View", 4, function(target)
		miscTools.setSitEnabled(false)
		miscTools.spectatePlayer(target)
	end)

	local function addPlayerRow(player: Player)
		if list:FindFirstChild(player.Name) then
			return
		end
		local row = textButton({
			Name = player.Name,
			Text = "",
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -6, 0, 48),
			Parent = list,
		})
		corner(row, 10)
		stroke(row, COLORS.border)
		local icon = apply(Instance.new("ImageLabel"), {
			BackgroundColor3 = COLORS.statBg,
			Size = UDim2.fromOffset(32, 32),
			Position = UDim2.fromOffset(8, 8),
			Image = avatarUrl(player.UserId),
			Parent = row,
		}) :: ImageLabel
		corner(icon, 10)
		textLabel({
			Text = player.DisplayName,
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(50, 8),
			Size = UDim2.new(1, -72, 0, 16),
			Parent = row,
		})
		textLabel({
			Text = `@{player.Name}`,
			TextColor3 = COLORS.subtext,
			TextSize = 11,
			Position = UDim2.fromOffset(50, 26),
			Size = UDim2.new(1, -72, 0, 14),
			Parent = row,
		})
		if player ~= LocalPlayer then
			textLabel({
				Text = "›",
				TextColor3 = COLORS.dim,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -22, 0, 0),
				Size = UDim2.fromOffset(16, 48),
				Parent = row,
			})
			row.MouseButton1Click:Connect(function()
				openPlayerMenu(player, row)
			end)
			row.MouseEnter:Connect(function()
				if highlightedRow ~= row then
					tween(row, TWEEN_FAST, { BackgroundColor3 = COLORS.statBg })
				end
			end)
			row.MouseLeave:Connect(function()
				if highlightedRow ~= row then
					tween(row, TWEEN_FAST, { BackgroundColor3 = COLORS.card })
				end
			end)
		end
	end

	local function removePlayerRow(player: Player)
		if playerMenuTarget == player then
			closePlayerMenu()
		end
		local row = list:FindFirstChild(player.Name)
		if row then
			row:Destroy()
		end
	end

	for _, player in Players:GetPlayers() do
		addPlayerRow(player)
	end
	trackHub(Players.PlayerAdded:Connect(function(player)
		addPlayerRow(player)
	end))
	trackHub(Players.PlayerRemoving:Connect(function(player)
		removePlayerRow(player)
	end))

	trackHub(UserInputService.InputEnded:Connect(function(input)
		if not playerMenu.Visible then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if mouseInside(playerMenu) then
			return
		end
		if highlightedRow and mouseInside(highlightedRow) then
			return
		end
		closePlayerMenu()
	end))
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if playerMenu.Visible then
			closePlayerMenu()
		end
	end)

	-- Misc
	local miscPage = apply(Instance.new("ScrollingFrame"), {
		Name = "Misc",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = pagesHost,
	}) :: ScrollingFrame
	pages.misc = miscPage
	apply(Instance.new("UIListLayout"), {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = miscPage,
	})
	apply(Instance.new("UIPadding"), {
		PaddingTop = UDim.new(0, LAYOUT.pad),
		PaddingBottom = UDim.new(0, LAYOUT.pad),
		PaddingLeft = UDim.new(0, LAYOUT.pad),
		PaddingRight = UDim.new(0, LAYOUT.pad),
		Parent = miscPage,
	})

	local function styleCardRow(row: Frame)
		row.BackgroundTransparency = 0.25
		corner(row, 8)
		local outline = candleStroke(row, 1, 0.35)
		row.MouseEnter:Connect(function()
			tween(row, TWEEN_FAST, { BackgroundTransparency = 0.08, BackgroundColor3 = COLORS.cardHover })
			tween(outline, TWEEN_FAST, { Transparency = 0.12 })
		end)
		row.MouseLeave:Connect(function()
			tween(row, TWEEN_FAST, { BackgroundTransparency = 0.25, BackgroundColor3 = COLORS.card })
			tween(outline, TWEEN_FAST, { Transparency = 0.35 })
		end)
	end

	local function miscSection(title: string, order: number)
		local wrap = frame({
			BackgroundColor3 = COLORS.trackOff,
			BackgroundTransparency = 0.3,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = order,
			Parent = miscPage,
		})
		corner(wrap, 6)
		candleStroke(wrap, 1, 0.5)
		textLabel({
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = COLORS.text,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -16, 1, 0),
			Parent = wrap,
		})
		return wrap
	end

	local function miscRun(order: number, title: string, description: string, onRun: () -> (), buttonText: string?)
		local row = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = order,
			Parent = miscPage,
		})
		styleCardRow(row)
		textLabel({
			Text = title,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -92, 0, 16),
			Parent = row,
		})
		textLabel({
			Text = description,
			TextColor3 = COLORS.subtext,
			TextSize = 11,
			Position = UDim2.fromOffset(14, 28),
			Size = UDim2.new(1, -92, 0, 16),
			Parent = row,
		})
		local actionText = buttonText or "Run"
		local runBtn = textButton({
			Text = actionText,
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			Size = UDim2.fromOffset(52, 24),
			Position = UDim2.new(1, -66, 0.5, -12),
			BackgroundTransparency = 1,
			TextColor3 = COLORS.subtext,
			Parent = row,
		})
		runBtn.MouseEnter:Connect(function()
			tween(runBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
		end)
		runBtn.MouseLeave:Connect(function()
			tween(runBtn, TWEEN_FAST, { TextColor3 = COLORS.subtext })
		end)
		runBtn.MouseButton1Click:Connect(function()
			onRun()
			if buttonText then
				return
			end
			local previous = runBtn.Text
			runBtn.Text = "OK"
			task.delay(0.9, function()
				if runBtn.Parent then
					runBtn.Text = previous
				end
			end)
		end)
	end

	local function setToggleButton(btn: TextButton, on: boolean)
		btn.Text = if on then "On" else "Off"
		btn.BackgroundColor3 = if on then COLORS.accentDim else COLORS.statBg
		btn.TextColor3 = if on then COLORS.accent else COLORS.subtext
	end

	local function miscToggle(order: number, title: string, description: string, get: () -> boolean, set: (boolean) -> ())
		local row = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = order,
			Parent = miscPage,
		})
		styleCardRow(row)
		textLabel({
			Text = title,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -70, 0, 16),
			Parent = row,
		})
		textLabel({
			Text = description,
			TextColor3 = COLORS.subtext,
			TextSize = 11,
			Position = UDim2.fromOffset(14, 28),
			Size = UDim2.new(1, -70, 0, 16),
			Parent = row,
		})
		return makeSwitch(row, UDim2.new(1, -14, 0.5, 0), get, set)
	end

	local extendBaseplate = createExtendBaseplate({ Workspace = Workspace })
	local function setExtendedBaseplate(enabled: boolean)
		if not enabled then
			extendBaseplate.remove()
			return
		end
		local ok, err = pcall(function()
			extendBaseplate.build()
		end)
		if not ok then
			extendBaseplate.remove()
			warn("[Scorp Client] Extended Baseplate:", err)
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Scorp Client",
					Text = "Could not find a baseplate to extend.",
					Duration = 4,
				})
			end)
		end
	end

	miscSection("Utilities", 1)
	miscRun(2, "Anti VC", "Load Anti-VC Ban script", function()
		miscTools.runAntiVc()
	end)
	local refreshAntiNetworkPause = miscToggle(3, "Anti Network Pause", "Remove the Gameplay Paused overlay", function()
		return miscTools.settings.antiNetworkPause
	end, miscTools.setAntiNetworkPause)
	local refreshAntiAfk = miscToggle(4, "Anti AFK", "Stop Roblox from kicking you while idle", function()
		return miscTools.settings.antiAfk
	end, miscTools.setAntiAfk)

	miscSection("Movement", 5)
	local refreshNoclip = miscToggle(6, "Noclip", "Walk through walls", function()
		return miscTools.settings.noclip
	end, miscTools.setNoclip)
	local refreshAntiFling = miscToggle(7, "Anti-Fling", "Prevent others from flinging your character", function()
		return miscTools.settings.antiFling
	end, miscTools.setAntiFling)
	local refreshFakeout = miscToggle(8, "Fakeout", "Void people facebanging, sitting on, or attached to you. You stay put", function()
		return miscTools.settings.fakeout
	end, miscTools.setFakeout)
	local refreshInfiniteJump = miscToggle(9, "Infinite Jump", "Jump again while already in the air", function()
		return miscTools.settings.infiniteJump
	end, miscTools.setInfiniteJump)
	local refreshInfiniteZoom = miscToggle(9, "Infinate Zoom", "Scroll camera out with no distance cap", function()
		return miscTools.settings.infiniteZoom
	end, miscTools.setInfiniteZoom)
	local refreshClickTeleport = miscToggle(10, "Click Teleport", "Aim and press your Click Teleport key", function()
		return miscTools.settings.clickTeleport
	end, miscTools.setClickTeleport)
	local refreshTpTool = miscToggle(11, "TP Tool", "Equip a backpack tool; click to teleport", function()
		return miscTools.settings.tpTool
	end, miscTools.setTpTool)

	local sitPanelWidth = 300
	local sitPanelHeight = 372
	local flyPanelWidth = 300
	local flyPanelHeight = 268
	local sitPlaced = false
	local flyPlaced = false

	local function placeBesideWindow(panel: Frame, width: number, offsetY: number)
		local abs = window.AbsolutePosition
		local size = window.AbsoluteSize
		local x = abs.X + size.X + 14
		local viewport = if Workspace.CurrentCamera then Workspace.CurrentCamera.ViewportSize else Vector2.new(1920, 1080)
		if x + width > viewport.X - 8 then
			x = abs.X - width - 14
		end
		panel.Position = UDim2.fromOffset(math.floor(x), math.floor(abs.Y + offsetY))
	end

	local sitPanel, sitBody, setSitPanelVisible = makeToolPanel(
		gui,
		"Sit on Player",
		Vector2.new(sitPanelWidth, sitPanelHeight),
		UDim2.fromOffset(40, 80)
	)
	local sitStatusCard = frame({
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = sitBody,
	})
	corner(sitStatusCard, 10)
	sitStatusCard.BackgroundTransparency = 0.2
	candleStroke(sitStatusCard, 1, 0.3)
	textLabel({
		Text = "Attach",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -70, 0, 16),
		Parent = sitStatusCard,
	})
	local sitStatus = textLabel({
		Text = "Inactive",
		TextColor3 = COLORS.subtext,
		TextSize = 11,
		Position = UDim2.fromOffset(12, 22),
		Size = UDim2.new(1, -70, 0, 14),
		Parent = sitStatusCard,
	})
	local refreshSitSwitch = makeSwitch(sitStatusCard, UDim2.new(1, -12, 0.5, 0), function()
		return miscTools.isSit()
	end, function(enabled)
		if enabled then
			miscTools.setFlyEnabled(false)
			miscTools.stopSpectate()
		end
		miscTools.setSitEnabled(enabled)
	end)
	local sitModeRow = frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 54),
		Parent = sitBody,
	})
	local sitModeButtons: { [string]: TextButton } = {}
	local refreshSitPanel: () -> ()
	local function refreshSitModes()
		local mode = miscTools.getSitMode()
		for id, btn in sitModeButtons do
			local on = id == mode
			btn.TextColor3 = if on then COLORS.text else COLORS.subtext
			btn.BackgroundColor3 = if on then COLORS.card else COLORS.statBg
		end
	end
	local function sitModeBtn(id: string, label: string, xScale: number)
		local btn = textButton({
			Text = label,
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			Size = UDim2.new(0.5, -4, 1, 0),
			Position = UDim2.new(xScale, if xScale == 0 then 0 else 4, 0, 0),
			BackgroundColor3 = COLORS.statBg,
			TextColor3 = COLORS.subtext,
			Parent = sitModeRow,
		})
		corner(btn, 6)
		btn.MouseButton1Click:Connect(function()
			miscTools.setSitMode(id)
			refreshSitModes()
			refreshSitPanel()
		end)
		sitModeButtons[id] = btn
	end
	sitModeBtn("back", "Backpack", 0)
	sitModeBtn("head", "Headsit", 0.5)
	refreshSitModes()
	local refreshSitSpeed = makeSlider(sitBody, "Speed", UDim2.fromOffset(0, 94), 1, 30, miscTools.getSitSpeed, miscTools.setSitSpeed)
	local refreshSitDistance = makeSlider(sitBody, "Distance", UDim2.fromOffset(0, 154), 0, 10, miscTools.getSitDistance, miscTools.setSitDistance)
	local sitHelpLabel = textLabel({
		Text = `{displayKeyName(keybindValues.sit or "Z")} toggles sit on the closest player. Distance is how far back or how high.`,
		TextColor3 = COLORS.dim,
		TextSize = 11,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 216),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = sitBody,
	})
	refreshSitPanel = function()
		local active = miscTools.isSit()
		local mode = miscTools.getSitMode()
		sitStatus.Text = if not active then "Inactive" elseif mode == "head" then "Headsit" else "Backpack"
		sitStatus.TextColor3 = if active then COLORS.accent else COLORS.subtext
		refreshSitSwitch()
		refreshSitSpeed()
		refreshSitDistance()
		refreshSitModes()
	end

	local flyPanel, flyBody, setFlyPanelVisible = makeToolPanel(
		gui,
		"Superman Fly",
		Vector2.new(flyPanelWidth, flyPanelHeight),
		UDim2.fromOffset(40, 380)
	)
	local flyStatusCard = frame({
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = flyBody,
	})
	corner(flyStatusCard, 10)
	flyStatusCard.BackgroundTransparency = 0.2
	candleStroke(flyStatusCard, 1, 0.3)
	textLabel({
		Text = "Flight",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -70, 0, 16),
		Parent = flyStatusCard,
	})
	textLabel({
		Text = "WASD to move  ·  S for reverse",
		TextColor3 = COLORS.subtext,
		TextSize = 11,
		Position = UDim2.fromOffset(12, 22),
		Size = UDim2.new(1, -70, 0, 14),
		Parent = flyStatusCard,
	})
	local refreshFlySwitch = makeSwitch(flyStatusCard, UDim2.new(1, -12, 0.5, 0), function()
		return miscTools.isFly()
	end, function(enabled)
		miscTools.setFlyEnabled(enabled)
	end)
	local refreshFlySpeed = makeSlider(flyBody, "Fly Speed", UDim2.fromOffset(0, 58), 1, 200, miscTools.getFlySpeed, miscTools.setFlySpeed)
	local flyHelpLabel = textLabel({
		Text = `{displayKeyName(keybindValues.fly or "X")} to toggle  ·  closing this window keeps fly on`,
		TextColor3 = COLORS.dim,
		TextSize = 11,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = flyBody,
	})
	onKeybindsChanged(function()
		sitHelpLabel.Text = `{displayKeyName(keybindValues.sit or "Z")} toggles sit on the closest player. Distance is how far back or how high.`
		flyHelpLabel.Text = `{displayKeyName(keybindValues.fly or "X")} to toggle  ·  closing this window keeps fly on`
	end)
	local function refreshFlyPanel()
		refreshFlySwitch()
		refreshFlySpeed()
	end
	miscTools.onSitChanged(function()
		refreshSitPanel()
	end)
	miscTools.onFlyChanged(function()
		refreshFlyPanel()
	end)
	refreshSitPanel()
	refreshFlyPanel()

	local wheelAnims = {
		{ n = "Handstand", i = "rbxassetid://13027233338" },
		{ n = "VIP 01", i = "rbxassetid://124072584017964" },
		{ n = "VIP 03", i = "rbxassetid://137445502103066" },
		{ n = "VIP 08", i = "rbxassetid://11137338685" },
		{ n = "Ghostly", i = "rbxassetid://124385779438289" },
		{ n = "Oof", i = "rbxassetid://134763058840745" },
		{ n = "Die", i = "rbxassetid://14852161489" },
		{ n = "Log", i = "rbxassetid://116818881329505" },
	}
	local wheelVertical = Vector2.new(268, 268)
	local wheelPanel, wheelBody, setWheelVisible = makeToolPanel(
		gui,
		"Emote Wheel",
		wheelVertical,
		UDim2.new(0, 18, 0.28, 0)
	)
	local wheelHorizontal = false
	local wheelActiveTrack: AnimationTrack? = nil
	local wheelActiveId: string? = nil
	local wheelActiveBtn: TextButton? = nil
	local function paintWheelBtn(btn: TextButton, active: boolean)
		btn.BackgroundColor3 = if active then COLORS.accentDim else COLORS.statBg
		btn.TextColor3 = if active then COLORS.accent else COLORS.text
	end
	local function stopEmoteWheel()
		if wheelActiveTrack then
			pcall(function()
				wheelActiveTrack:Stop()
			end)
			wheelActiveTrack = nil
		end
		wheelActiveId = nil
		if wheelActiveBtn then
			paintWheelBtn(wheelActiveBtn, false)
			wheelActiveBtn = nil
		end
	end
	local function getWheelHumanoid(): Humanoid?
		local character = LocalPlayer.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end
	local function playWheelAnim(animId: string, btn: TextButton)
		if wheelActiveTrack and wheelActiveId == animId then
			stopEmoteWheel()
			return
		end
		stopEmoteWheel()
		local humanoid = getWheelHumanoid()
		if not humanoid then
			return
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = animId
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or typeof(track) ~= "Instance" then
			return
		end
		local animTrack = track :: AnimationTrack
		animTrack:Play()
		wheelActiveTrack = animTrack
		wheelActiveId = animId
		wheelActiveBtn = btn
		paintWheelBtn(btn, true)
	end
	local layoutToggle = textButton({
		Text = "⇄  Switch layout",
		TextSize = 12,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = COLORS.statBg,
		TextColor3 = COLORS.subtext,
		ZIndex = 41,
		Parent = wheelBody,
	})
	corner(layoutToggle, 8)
	stroke(layoutToggle, COLORS.border)
	local wheelGrid = frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.fromOffset(0, 34),
		ZIndex = 41,
		Parent = wheelBody,
	})
	local gridLayout = apply(Instance.new("UIGridLayout"), {
		CellPadding = UDim2.fromOffset(6, 6),
		CellSize = UDim2.new(0.48, 0, 0, 28),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = wheelGrid,
	}) :: UIGridLayout
	for index, anim in wheelAnims do
		local btn = textButton({
			Text = anim.n,
			TextSize = 12,
			BackgroundColor3 = COLORS.statBg,
			TextColor3 = COLORS.text,
			LayoutOrder = index,
			ZIndex = 42,
			Parent = wheelGrid,
		})
		corner(btn, 7)
		btn.MouseEnter:Connect(function()
			if wheelActiveBtn ~= btn then
				tween(btn, TWEEN_FAST, { BackgroundColor3 = COLORS.card })
			end
		end)
		btn.MouseLeave:Connect(function()
			if wheelActiveBtn ~= btn then
				tween(btn, TWEEN_FAST, { BackgroundColor3 = COLORS.statBg })
			end
		end)
		btn.MouseButton1Click:Connect(function()
			playWheelAnim(anim.i, btn)
		end)
	end
	local function applyWheelLayout()
		if wheelHorizontal then
			tween(wheelPanel, TWEEN_MED, { Size = UDim2.fromOffset(328, 176) })
			gridLayout.CellSize = UDim2.fromOffset(72, 28)
			gridLayout.CellPadding = UDim2.fromOffset(4, 4)
		else
			tween(wheelPanel, TWEEN_MED, { Size = UDim2.fromOffset(wheelVertical.X, wheelVertical.Y) })
			gridLayout.CellSize = UDim2.new(0.48, 0, 0, 28)
			gridLayout.CellPadding = UDim2.fromOffset(6, 6)
		end
	end
	layoutToggle.MouseButton1Click:Connect(function()
		wheelHorizontal = not wheelHorizontal
		applyWheelLayout()
	end)
	trackHub(LocalPlayer.CharacterAdded:Connect(function()
		stopEmoteWheel()
	end))

	local function openFlyPanel()
		if not flyPlaced then
			placeBesideWindow(flyPanel, flyPanelWidth, sitPanelHeight + 12)
			flyPlaced = true
		end
		setFlyPanelVisible(true)
		refreshFlyPanel()
	end
	local function openSitPanel()
		if not sitPlaced then
			placeBesideWindow(sitPanel, sitPanelWidth, 0)
			sitPlaced = true
		end
		setSitPanelVisible(true)
		refreshSitPanel()
	end
	miscRun(10, "Superman Fly", "Open fly panel with speed control", openFlyPanel, "Open")
	miscRun(11, "Sit on Player", "Open sit panel with speed and distance", openSitPanel, "Open")

	miscSection("World", 12)
	local refreshFullbright = miscToggle(13, "Fullbright", "Brighten the map and remove fog/shadows", function()
		return miscTools.settings.fullbright
	end, miscTools.setFullbright)
	local refreshHideChat = miscToggle(14, "Hide Chat", "Hide the default Roblox chat UI", function()
		return miscTools.settings.hideChat
	end, miscTools.setHideChat)
	local refreshNameEsp = miscToggle(15, "Name ESP", "Show player display names above heads", function()
		return miscTools.settings.nameEsp
	end, miscTools.setNameEsp)

	miscSection("Actions", 20)
	miscRun(21, "Reset Character", "Respawn your character", function()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
	miscRun(22, "Rejoin Server", "Rejoin this same server instance", function()
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end)
	end)
	miscRun(23, "Stop Animations", "Stop all currently playing emotes", function()
		stopEmoteWheel()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop()
			end
		end
	end)
	miscSection("Emotes", 24)
	local function toggleEmoteWheel()
		if wheelPanel.Visible then
			setWheelVisible(false)
			return
		end
		setWheelVisible(true)
		if wheelHorizontal then
			wheelPanel.Size = UDim2.fromOffset(328, 176)
		end
	end
	local function toggleEmotePanel()
		if not emotePanelCtl then
			emotePanelCtl = createEmoteCatalogPanel(LocalPlayer, gui.Parent or guiParent)
		end
		emotePanelCtl.toggle()
	end
	miscRun(25, "Emote Wheel", "Open the animation wheel", toggleEmoteWheel, "Open")
	miscRun(26, "Emote Panel", "Browse and play catalog emotes", toggleEmotePanel, "Open")
	miscSection("Tools", 30)
	local refreshExtendedBaseplate = miscToggle(31, "Extended Baseplate", "Extend the map floor in all directions", function()
		return extendBaseplate.isActive()
	end, setExtendedBaseplate)
	miscSection("Script", 90)
	do
		local row = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = 91,
			Parent = miscPage,
		})
		styleCardRow(row)
		textLabel({
			Text = "Unload Script",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -96, 0, 16),
			Parent = row,
		})
		textLabel({
			Text = "Remove the hub, nametags, and tools from this game",
			TextColor3 = COLORS.subtext,
			TextSize = 11,
			Position = UDim2.fromOffset(14, 28),
			Size = UDim2.new(1, -96, 0, 16),
			Parent = row,
		})
		local runBtn = textButton({
			Text = "Unload",
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			Size = UDim2.fromOffset(64, 26),
			Position = UDim2.new(1, -78, 0.5, -13),
			BackgroundColor3 = COLORS.accentDim,
			BackgroundTransparency = 0.1,
			TextColor3 = COLORS.accent,
			Parent = row,
		})
		corner(runBtn, 6)
		runBtn.MouseEnter:Connect(function()
			tween(runBtn, TWEEN_FAST, { TextColor3 = COLORS.text, BackgroundTransparency = 0 })
		end)
		runBtn.MouseLeave:Connect(function()
			tween(runBtn, TWEEN_FAST, { TextColor3 = COLORS.accent, BackgroundTransparency = 0.1 })
		end)
		runBtn.MouseButton1Click:Connect(function()
			unloadScript()
		end)
	end
	frame({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 100,
		Parent = miscPage,
	})
	-- Keybinds
	local keybindsPage = apply(Instance.new("ScrollingFrame"), {
		Name = "Keybinds",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = pagesHost,
	}) :: ScrollingFrame
	pages.keybinds = keybindsPage
	apply(Instance.new("UIListLayout"), {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = keybindsPage,
	})
	apply(Instance.new("UIPadding"), {
		PaddingTop = UDim.new(0, LAYOUT.pad),
		PaddingBottom = UDim.new(0, LAYOUT.pad),
		PaddingLeft = UDim.new(0, LAYOUT.pad),
		PaddingRight = UDim.new(0, LAYOUT.pad),
		Parent = keybindsPage,
	})

	local keybindHint = frame({
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 0,
		Parent = keybindsPage,
	})
	corner(keybindHint, 8)
	keybindHint.BackgroundTransparency = 0.2
	candleStroke(keybindHint, 1, 0.25)
	textLabel({
		Text = "Click a bind, then press a key. Escape cancels. Backspace clears. One key per command.",
		TextColor3 = COLORS.subtext,
		TextSize = 11,
		TextWrapped = true,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 1, -16),
		Parent = keybindHint,
	})

	local function keybindSection(title: string, order: number)
		local wrap = frame({
			BackgroundColor3 = COLORS.trackOff,
			BackgroundTransparency = 0.3,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = order,
			Parent = keybindsPage,
		})
		corner(wrap, 6)
		candleStroke(wrap, 1, 0.5)
		textLabel({
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = COLORS.text,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -16, 1, 0),
			Parent = wrap,
		})
	end

	local keybindButtons: { [string]: TextButton } = {}
	local function paintKeybindButton(id: string)
		local btn = keybindButtons[id]
		if not btn then
			return
		end
		btn.Text = keybindButtonText(id)
		btn.TextColor3 = if keybindCapturingId == id then COLORS.accent else COLORS.subtext
	end

	local bindOrder = 1
	local lastSection = ""
	for _, spec in KEYBIND_SPECS do
		if spec.section ~= lastSection then
			lastSection = spec.section
			keybindSection(string.upper(spec.section), bindOrder)
			bindOrder += 1
		end
		local row = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = bindOrder,
			Parent = keybindsPage,
		})
		styleCardRow(row)
		textLabel({
			Text = spec.title,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -118, 0, 16),
			Parent = row,
		})
		textLabel({
			Text = spec.hint,
			TextColor3 = COLORS.subtext,
			TextSize = 11,
			Position = UDim2.fromOffset(14, 28),
			Size = UDim2.new(1, -118, 0, 16),
			Parent = row,
		})
		local bindBtn = textButton({
			Text = keybindButtonText(spec.id),
			Font = Enum.Font.Code,
			TextSize = 11,
			TextColor3 = COLORS.subtext,
			Size = UDim2.fromOffset(96, 26),
			Position = UDim2.new(1, -110, 0.5, -13),
			BackgroundColor3 = COLORS.statBg,
			BackgroundTransparency = 0.15,
			Parent = row,
		})
		corner(bindBtn, 6)
		candleStroke(bindBtn, 1, 0.3)
		hoverGrow(bindBtn, 1.04)
		keybindButtons[spec.id] = bindBtn
		local specId = spec.id
		bindBtn.MouseButton1Click:Connect(function()
			if keybindCapturingId == specId then
				keybindCapturingId = nil
			else
				keybindCapturingId = specId
			end
			notifyKeybindChange()
		end)
		bindBtn.MouseButton2Click:Connect(function()
			keybindCapturingId = nil
			setKeybind(specId, "")
		end)
		bindOrder += 1
	end

	local resetRow = frame({
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = bindOrder + 1,
		Parent = keybindsPage,
	})
	styleCardRow(resetRow)
	textLabel({
		Text = "Reset all keybinds",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -92, 0, 16),
		Parent = resetRow,
	})
	textLabel({
		Text = "Restore the default keys",
		TextColor3 = COLORS.subtext,
		TextSize = 11,
		Position = UDim2.fromOffset(14, 26),
		Size = UDim2.new(1, -92, 0, 16),
		Parent = resetRow,
	})
	local resetBtn = textButton({
		Text = "Reset",
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		Size = UDim2.fromOffset(52, 24),
		Position = UDim2.new(1, -66, 0.5, -12),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.subtext,
		Parent = resetRow,
	})
	resetBtn.MouseEnter:Connect(function()
		tween(resetBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
	end)
	resetBtn.MouseLeave:Connect(function()
		tween(resetBtn, TWEEN_FAST, { TextColor3 = COLORS.subtext })
	end)
	resetBtn.MouseButton1Click:Connect(function()
		resetKeybinds()
	end)

	onKeybindsChanged(function()
		for id, _btn in keybindButtons do
			paintKeybindButton(id)
		end
	end)

	local function bindToggleKey(id: string, get: () -> boolean, set: (boolean) -> (), refresh: () -> ())
		setKeybindAction(id, function()
			set(not get())
			refresh()
		end)
	end
	bindToggleKey("noclip", function()
		return miscTools.settings.noclip
	end, miscTools.setNoclip, refreshNoclip)
	bindToggleKey("antiFling", function()
		return miscTools.settings.antiFling
	end, miscTools.setAntiFling, refreshAntiFling)
	bindToggleKey("fakeout", function()
		return miscTools.settings.fakeout
	end, miscTools.setFakeout, refreshFakeout)
	bindToggleKey("infiniteJump", function()
		return miscTools.settings.infiniteJump
	end, miscTools.setInfiniteJump, refreshInfiniteJump)
	bindToggleKey("infiniteZoom", function()
		return miscTools.settings.infiniteZoom
	end, miscTools.setInfiniteZoom, refreshInfiniteZoom)
	bindToggleKey("toggleClickTeleport", function()
		return miscTools.settings.clickTeleport
	end, miscTools.setClickTeleport, refreshClickTeleport)
	bindToggleKey("tpTool", function()
		return miscTools.settings.tpTool
	end, miscTools.setTpTool, refreshTpTool)
	bindToggleKey("fullbright", function()
		return miscTools.settings.fullbright
	end, miscTools.setFullbright, refreshFullbright)
	bindToggleKey("hideChat", function()
		return miscTools.settings.hideChat
	end, miscTools.setHideChat, refreshHideChat)
	bindToggleKey("nameEsp", function()
		return miscTools.settings.nameEsp
	end, miscTools.setNameEsp, refreshNameEsp)
	bindToggleKey("antiNetworkPause", function()
		return miscTools.settings.antiNetworkPause
	end, miscTools.setAntiNetworkPause, refreshAntiNetworkPause)
	bindToggleKey("antiAfk", function()
		return miscTools.settings.antiAfk
	end, miscTools.setAntiAfk, refreshAntiAfk)
	bindToggleKey("extendedBaseplate", extendBaseplate.isActive, setExtendedBaseplate, refreshExtendedBaseplate)
	setKeybindAction("sit", function()
		miscTools.toggleSit()
	end)
	setKeybindAction("fly", function()
		miscTools.toggleFly()
	end)
	setKeybindAction("antiVc", function()
		miscTools.runAntiVc()
	end)
	setKeybindAction("resetCharacter", function()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
	setKeybindAction("rejoinServer", function()
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end)
	end)
	setKeybindAction("stopAnimations", function()
		stopEmoteWheel()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop()
			end
		end
	end)
	setKeybindAction("emoteWheel", toggleEmoteWheel)
	setKeybindAction("emotePanel", toggleEmotePanel)
	setKeybindAction("slowEmote", function()
		slowPlayingAnimations(LocalPlayer)
	end)
	setKeybindAction("sitPanel", openSitPanel)
	setKeybindAction("flyPanel", openFlyPanel)
	refreshEmoteCoreBind()

	-- Settings
	local settingsPage = frame({
		Name = "Settings",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = pagesHost,
	})
	pages.settings = settingsPage

	local settingsCard = frame({
		BackgroundColor3 = COLORS.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -LAYOUT.pad * 2, 0, 248),
		Position = UDim2.fromOffset(LAYOUT.pad, LAYOUT.pad),
		Parent = settingsPage,
	})
	corner(settingsCard, 8)
	settingsCard.BackgroundTransparency = 0.2
	candleStroke(settingsCard, 1, 0.25)

	textLabel({
		Text = "WINDOW",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = COLORS.dim,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 14),
		Parent = settingsCard,
	})

	local function settingsLine(y: number, labelText: string, valueText: string): TextLabel
		textLabel({
			Text = labelText,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.new(0.42, 0, 0, 18),
			Parent = settingsCard,
		})
		return textLabel({
			Text = valueText,
			TextColor3 = COLORS.subtext,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.42, 0, 0, y),
			Size = UDim2.new(0.58, -16, 0, 18),
			Parent = settingsCard,
		})
	end
	local settingsToggleValue = settingsLine(36, "Toggle", displayKeyName(keybindValues.toggleUi or "RightShift"))
	settingsLine(62, "Chat hide", ".hide  /  .unhide  [name]")
	settingsLine(88, "Move window", "Drag the logo")
	local settingsSitFlyValue = settingsLine(114, "Sit / Fly", `{displayKeyName(keybindValues.sit or "Z")} sit   ·   {displayKeyName(keybindValues.fly or "X")} fly`)
	onKeybindsChanged(function()
		settingsToggleValue.Text = displayKeyName(keybindValues.toggleUi or "RightShift")
		settingsSitFlyValue.Text = `{displayKeyName(keybindValues.sit or "Z")} sit   ·   {displayKeyName(keybindValues.fly or "X")} fly`
	end)
	loadUiMute()
	textLabel({
		Text = "UI click sound",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Position = UDim2.fromOffset(16, 148),
		Size = UDim2.new(0.42, 0, 0, 18),
		Parent = settingsCard,
	})
	textLabel({
		Text = "Mute button clicks",
		TextColor3 = COLORS.subtext,
		TextSize = 12,
		Position = UDim2.fromOffset(16, 166),
		Size = UDim2.new(0.5, 0, 0, 16),
		Parent = settingsCard,
	})
	makeSwitch(settingsCard, UDim2.new(1, -16, 0, 166), function()
		return not uiSoundsMuted
	end, function(enabled: boolean)
		uiSoundsMuted = not enabled
		saveUiMute()
	end)
	textLabel({
		Text = `Accent  {hexFromColor(COLORS.accent)}`,
		TextColor3 = COLORS.dim,
		TextSize = 11,
		Position = UDim2.fromOffset(16, 204),
		Size = UDim2.new(1, -32, 0, 16),
		Parent = settingsCard,
	})

	do
		local staffPanel, staffBody, setStaffPanelVisible = makeToolPanel(
			gui,
			"Staff Panel",
			Vector2.new(392, 528),
			UDim2.fromOffset(40, 64)
		)
		local staffPage = apply(Instance.new("ScrollingFrame"), {
			Name = "Staff",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = COLORS.border,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = staffBody,
		}) :: ScrollingFrame
		apply(Instance.new("UIListLayout"), {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = staffPage,
		})
		apply(Instance.new("UIPadding"), {
			PaddingTop = UDim.new(0, LAYOUT.pad),
			PaddingBottom = UDim.new(0, LAYOUT.pad),
			PaddingLeft = UDim.new(0, LAYOUT.pad),
			PaddingRight = UDim.new(0, LAYOUT.pad),
			Parent = staffPage,
		})

		local staffHeader = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 1,
			Parent = staffPage,
		})
		corner(staffHeader, 8)
		stroke(staffHeader, COLORS.border, 1, 0.28)
		textLabel({
			Text = "These only hit people with Scorp loaded. Kick, void, reset, and blind skip staff.",
			TextColor3 = COLORS.subtext,
			TextSize = 11,
			TextWrapped = true,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 28),
			Parent = staffHeader,
		})

		local function staffBtn(parent: Instance, col: number, row: number, startY: number, labelText: string, onClick: () -> ())
			local btn = textButton({
				Text = labelText,
				TextSize = 11,
				Font = Enum.Font.GothamMedium,
				Size = UDim2.new(0.5, -16, 0, 26),
				Position = UDim2.new(if col == 0 then 0 else 0.5, if col == 0 then 12 else 4, 0, startY + row * 32),
				BackgroundColor3 = COLORS.statBg,
				TextColor3 = COLORS.text,
				Parent = parent,
			})
			corner(btn, 6)
			bindHover(btn, COLORS.statBg, COLORS.card)
			btn.MouseButton1Click:Connect(function()
				onClick()
				local previous = btn.Text
				btn.Text = "Sent"
				task.delay(0.9, function()
					if btn.Parent then
						btn.Text = previous
					end
				end)
			end)
		end

		local function staffGrid(parent: Instance, startY: number, items: { { string | () -> () } })
			for index, item in items do
				local col = (index - 1) % 2
				local row = math.floor((index - 1) / 2)
				staffBtn(parent, col, row, startY, item[1] :: string, item[2] :: () -> ())
			end
			return startY + math.ceil(#items / 2) * 32
		end

		local selectedUsers: { [number]: boolean } = {}

		local function selectedIds(): { number }
			local ids = {}
			for userId, on in selectedUsers do
				if on then
					table.insert(ids, userId)
				end
			end
			return ids
		end

		local function sendToIds(prefix: string, ids: { number }, localFn: (() -> ())?)
			task.spawn(function()
				local filtered = {}
				for _, id in ids do
					if network.isScriptUser(id) then
						table.insert(filtered, id)
					end
				end
				if #filtered == 0 then
					return
				end
				local ranLocal = false
				local head = prefix .. ":"
				local function sendChunk(chunk: { string })
					if #chunk == 0 then
						return
					end
					network.broadcast(head .. table.concat(chunk, ","))
				end
				local chunk = {}
				local len = #head
				for _, id in filtered do
					if id == LocalPlayer.UserId then
						ranLocal = true
					end
					local piece = tostring(id)
					local extra = if #chunk == 0 then #piece else #piece + 1
					if len + extra > 30 and #chunk > 0 then
						sendChunk(chunk)
						chunk = {}
						len = #head
						extra = #piece
						task.wait(0.45)
					end
					table.insert(chunk, piece)
					len += extra
				end
				sendChunk(chunk)
				if ranLocal and localFn then
					localFn()
				end
			end)
		end

		local function sendKicks(ids: { number })
			task.spawn(function()
				local sent = false
				for _, id in ids do
					if id ~= LocalPlayer.UserId and not isScriptStaff(id) and network.isScriptUser(id) then
						if sent then
							task.wait(0.45)
						end
						network.broadcast(`kick:{id}`)
						sent = true
					end
				end
			end)
		end

		local trollCard = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 256),
			LayoutOrder = 2,
			Parent = staffPage,
		})
		corner(trollCard, 8)
		stroke(trollCard, COLORS.border)
		textLabel({
			Text = "All script users",
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = COLORS.subtext,
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 16),
			Parent = trollCard,
		})
		staffGrid(trollCard, 30, {
			{
				"Fly Wheel",
				function()
					network.broadcast("fw")
					task.spawn(network.executeFlyWheel)
				end,
			},
			{
				"Jump",
				function()
					network.broadcast("jump")
					task.spawn(network.executeScriptJump)
				end,
			},
			{
				"Spin",
				function()
					network.broadcast("spn")
					task.spawn(function()
						network.executeSpin(true)
					end)
				end,
			},
			{
				"Unspin",
				function()
					network.broadcast("usp")
					task.spawn(function()
						network.executeSpin(false)
					end)
				end,
			},
			{
				"Freeze",
				function()
					network.broadcast("frz")
					task.spawn(function()
						network.executeFreeze(true)
					end)
				end,
			},
			{
				"Unfreeze",
				function()
					network.broadcast("thw")
					task.spawn(function()
						network.executeFreeze(false)
					end)
				end,
			},
			{
				"Fling",
				function()
					network.broadcast("flg")
					task.spawn(network.executeFling)
				end,
			},
			{
				"Sit",
				function()
					network.broadcast("sit")
					task.spawn(network.executeSit)
				end,
			},
			{
				"Blind",
				function()
					network.broadcast("bld")
				end,
			},
			{
				"Unblind",
				function()
					network.broadcast("ubl")
					task.spawn(function()
						network.executeBlind(false)
					end)
				end,
			},
			{
				"Bring",
				function()
					network.broadcast("brg")
				end,
			},
			{
				"Void",
				function()
					network.broadcast("vod")
				end,
			},
			{
				"Reset",
				function()
					network.broadcast("rst")
				end,
			},
			{
				"Kick all",
				function()
					network.broadcast("kick:all")
				end,
			},
		})

		local selectedCard = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 224),
			LayoutOrder = 3,
			Parent = staffPage,
		})
		corner(selectedCard, 8)
		stroke(selectedCard, COLORS.border)
		textLabel({
			Text = "Selected users",
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = COLORS.subtext,
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 16),
			Parent = selectedCard,
		})
		staffGrid(selectedCard, 30, {
			{
				"Firework",
				function()
					sendToIds("fw", selectedIds(), network.executeFlyWheel)
				end,
			},
			{
				"Kick",
				function()
					sendKicks(selectedIds())
				end,
			},
			{
				"Spin",
				function()
					sendToIds("spn", selectedIds(), function()
						network.executeSpin(true)
					end)
				end,
			},
			{
				"Freeze",
				function()
					sendToIds("frz", selectedIds(), function()
						network.executeFreeze(true)
					end)
				end,
			},
			{
				"Fling",
				function()
					sendToIds("flg", selectedIds(), network.executeFling)
				end,
			},
			{
				"Sit",
				function()
					sendToIds("sit", selectedIds(), network.executeSit)
				end,
			},
			{
				"Bring",
				function()
					sendToIds("brg", selectedIds())
				end,
			},
			{
				"Void",
				function()
					sendToIds("vod", selectedIds(), network.executeVoid)
				end,
			},
			{
				"Reset",
				function()
					sendToIds("rst", selectedIds(), network.executeReset)
				end,
			},
			{
				"Blind",
				function()
					sendToIds("bld", selectedIds())
				end,
			},
			{
				"Unspin",
				function()
					sendToIds("usp", selectedIds(), function()
						network.executeSpin(false)
					end)
				end,
			},
			{
				"Unfreeze",
				function()
					sendToIds("thw", selectedIds(), function()
						network.executeFreeze(false)
					end)
				end,
			},
		})

		local kickCard = frame({
			BackgroundColor3 = COLORS.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 248),
			LayoutOrder = 4,
			Parent = staffPage,
		})
		corner(kickCard, 8)
		stroke(kickCard, COLORS.border)
		textLabel({
			Text = "Script users",
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = COLORS.subtext,
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -120, 0, 16),
			Parent = kickCard,
		})
		local selectAllBtn = textButton({
			Text = "Select all",
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			BackgroundTransparency = 1,
			TextColor3 = COLORS.subtext,
			Size = UDim2.fromOffset(64, 16),
			Position = UDim2.new(1, -120, 0, 8),
			Parent = kickCard,
		})
		local clearBtn = textButton({
			Text = "Clear",
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			BackgroundTransparency = 1,
			TextColor3 = COLORS.subtext,
			Size = UDim2.fromOffset(40, 16),
			Position = UDim2.new(1, -52, 0, 8),
			Parent = kickCard,
		})
		selectAllBtn.MouseEnter:Connect(function()
			tween(selectAllBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
		end)
		selectAllBtn.MouseLeave:Connect(function()
			tween(selectAllBtn, TWEEN_FAST, { TextColor3 = COLORS.subtext })
		end)
		clearBtn.MouseEnter:Connect(function()
			tween(clearBtn, TWEEN_FAST, { TextColor3 = COLORS.text })
		end)
		clearBtn.MouseLeave:Connect(function()
			tween(clearBtn, TWEEN_FAST, { TextColor3 = COLORS.subtext })
		end)

		local kickList = apply(Instance.new("ScrollingFrame"), {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 1, -36),
			Position = UDim2.fromOffset(8, 30),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = COLORS.border,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = kickCard,
		}) :: ScrollingFrame
		apply(Instance.new("UIListLayout"), {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.Name,
			Parent = kickList,
		})

		local lastListKey = ""
		local function refreshKickList(force: boolean?)
			local scriptPlayers = network.getScriptPlayers()
			table.sort(scriptPlayers, function(a, b)
				if a == LocalPlayer then
					return true
				end
				if b == LocalPlayer then
					return false
				end
				return string.lower(a.DisplayName) < string.lower(b.DisplayName)
			end)
			local keys = {}
			for _, player in scriptPlayers do
				table.insert(keys, tostring(player.UserId))
			end
			local listKey = table.concat(keys, ",")
			if not force and listKey == lastListKey then
				return
			end
			lastListKey = listKey
			for _, child in kickList:GetChildren() do
				if not child:IsA("UIListLayout") then
					child:Destroy()
				end
			end
			local shown = 0
			for _, player in scriptPlayers do
				shown += 1
				local userId = player.UserId
				local isYou = player == LocalPlayer
				local selected = selectedUsers[userId] == true
				local row = frame({
					Name = player.Name,
					BackgroundColor3 = COLORS.statBg,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -6, 0, 36),
					Parent = kickList,
				})
				corner(row, 8)
				local check = textButton({
					Text = if selected then "✓" else "",
					TextSize = 12,
					TextColor3 = COLORS.accent,
					BackgroundColor3 = if selected then COLORS.accentDim else COLORS.card,
					Size = UDim2.fromOffset(20, 20),
					Position = UDim2.fromOffset(8, 8),
					Parent = row,
				})
				corner(check, 5)
				check.MouseButton1Click:Connect(function()
					selectedUsers[userId] = not selectedUsers[userId]
					local on = selectedUsers[userId] == true
					check.Text = if on then "✓" else ""
					check.BackgroundColor3 = if on then COLORS.accentDim else COLORS.card
				end)
				textLabel({
					Text = if isYou then `{player.DisplayName}  (you)` else player.DisplayName,
					TextSize = 12,
					Position = UDim2.fromOffset(34, 0),
					Size = UDim2.new(1, -168, 1, 0),
					Parent = row,
				})
				local function tinyBtn(label: string, x: number, color: Color3, onClick: () -> ()): TextButton
					local btn = textButton({
						Text = label,
						TextSize = 11,
						TextColor3 = color,
						BackgroundColor3 = COLORS.card,
						Size = UDim2.fromOffset(34, 24),
						Position = UDim2.new(1, x, 0.5, -12),
						Parent = row,
					})
					corner(btn, 6)
					btn.MouseButton1Click:Connect(onClick)
					return btn
				end
				tinyBtn("TP", -114, COLORS.subtext, function()
					local myChar = LocalPlayer.Character
					local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
					local theirChar = player.Character
					local theirHrp = theirChar and theirChar:FindFirstChild("HumanoidRootPart")
					if myHrp and myHrp:IsA("BasePart") and theirHrp and theirHrp:IsA("BasePart") then
						myHrp.CFrame = theirHrp.CFrame * CFrame.new(0, 0, 3)
					end
				end)
				tinyBtn("FW", -76, COLORS.accent, function()
					sendToIds("fw", { userId }, network.executeFlyWheel)
				end)
				if not isYou then
					tinyBtn("Kick", -38, COLORS.danger, function()
						if network.isScriptUser(userId) then
							sendKicks({ userId })
						end
					end)
				end
			end
			if shown == 0 then
				textLabel({
					Name = "Empty",
					Text = "Waiting for script users in this server…",
					TextColor3 = COLORS.dim,
					TextSize = 11,
					Size = UDim2.new(1, 0, 0, 20),
					Parent = kickList,
				})
			end
		end

		selectAllBtn.MouseButton1Click:Connect(function()
			for _, player in network.getScriptPlayers() do
				selectedUsers[player.UserId] = true
			end
			refreshKickList(true)
		end)
		clearBtn.MouseButton1Click:Connect(function()
			selectedUsers = {}
			refreshKickList(true)
		end)

		network.onScriptUsersChanged(function()
			if staffPanel.Visible then
				refreshKickList(false)
			end
		end)

		openStaffPanel = function()
			if not isScriptStaff(LocalPlayer.UserId) then
				return
			end
			setStaffPanelVisible(true)
			refreshKickList(true)
		end
		table.insert(staffAccessListeners, function()
			if not isScriptStaff(LocalPlayer.UserId) then
				setStaffPanelVisible(false)
			end
		end)
	end
	-- Reopen widget
	local reopenRest = UDim2.new(0, 20, 1, -60)
	local reopenHiddenPos = UDim2.new(0, 20, 1, 40)
	local reopen = textButton({
		Name = "ReopenChip",
		Text = "",
		Size = UDim2.fromOffset(110, 40),
		Position = reopenRest,
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(20, 15, 20),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 80,
		Parent = gui,
	})
	round(reopen)
	candleStroke(reopen, 2, 0.2, true)
	textLabel({
		Text = "SCORP",
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(5, 0),
		ZIndex = 81,
		Parent = reopen,
	})
	local reopenScale = apply(Instance.new("UIScale"), {
		Scale = 1,
		Parent = reopen,
	}) :: UIScale
	reopen.MouseEnter:Connect(function()
		tween(reopenScale, TWEEN_BACK, { Scale = 1.05 })
	end)
	reopen.MouseLeave:Connect(function()
		tween(reopenScale, TWEEN_FAST, { Scale = 1 })
	end)

	local function setOpen(open: boolean)
		windowOpen = open
		if open then
			window.Visible = true
			reopen.Visible = false
			windowScale.Scale = 0.7
			tween(windowScale, TWEEN_BACK, { Scale = 1 })
		else
			reopen.Visible = true
			reopen.Position = reopenHiddenPos
			tween(reopen, TWEEN_MED, { Position = reopenRest })
			tween(windowScale, TWEEN_FAST, { Scale = 0 })
			task.delay(0.3, function()
				if not windowOpen and window.Parent then
					window.Visible = false
				end
			end)
		end
	end

	reopen.MouseButton1Click:Connect(function()
		setOpen(true)
	end)

	setKeybindAction("toggleUi", function()
		setOpen(not windowOpen)
	end)
	trackHub(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local capturing = keybindCapturingId
		if capturing then
			if not isBindableKeyCode(input.KeyCode) then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				keybindCapturingId = nil
				notifyKeybindChange()
				return
			end
			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				keybindCapturingId = nil
				setKeybind(capturing, "")
				return
			end
			keybindCapturingId = nil
			setKeybind(capturing, input.KeyCode.Name)
			return
		end
		if isTypingInTextBox() then
			return
		end
		local id = keybindIdForKey(input.KeyCode)
		if not id then
			return
		end
		if id == "clickTeleport" then
			return
		end
		if id == "emotePanel" and emoteCoreBound then
			return
		end
		if gameProcessed and id ~= "toggleUi" then
			return
		end
		runKeybindAction(id)
	end))

	bindFrameDrag(window, logoArea)
	bindFrameDrag(window, topStrip)

	-- Stats loop
	local frames = 0
	local elapsed = 0
	trackHub(RunService.Heartbeat:Connect(function(dt)
		if not windowOpen then
			return
		end
		frames += 1
		elapsed += dt
		if elapsed >= 0.5 then
			fpsLabel.Text = tostring(math.floor(frames / elapsed + 0.5))
			frames = 0
			elapsed = 0
			local pingOk, ping = pcall(function()
				return LocalPlayer:GetNetworkPing() * 1000
			end)
			if pingOk and typeof(ping) == "number" then
				pingLabel.Text = `{math.floor(ping + 0.5)} ms`
			end
		end
	end))

	showTab("home")
	gui.Enabled = true
	pcall(function()
		network.start()
	end)
	return gui
end

local function isRequiredStudioModule(): boolean
	local ok, required = pcall(function()
		if not RunService:IsStudio() then
			return false
		end
		if typeof(script) ~= "Instance" then
			return false
		end
		if not script:IsA("ModuleScript") then
			return false
		end
		if script.Parent == nil then
			return false
		end
		return script:FindFirstAncestorOfClass("ReplicatedStorage") ~= nil
			or script:FindFirstAncestorOfClass("StarterPlayer") ~= nil
	end)
	return ok and required == true
end

if isRequiredStudioModule() then
	return MainUI
end

local mounted, mountErr = pcall(function()
	MainUI.mount()
end)
if not mounted then
	warn("[Scorp Client] UI failed to load: " .. tostring(mountErr))
	pcall(function()
		local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
		local fallbackParent = resolveGuiParent(player)
		local fallback = Instance.new("ScreenGui")
		fallback.Name = "ScorpClientError"
		fallback.ResetOnSpawn = false
		fallback.IgnoreGuiInset = true
		fallback.DisplayOrder = 999999
		fallback.Parent = fallbackParent
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
		label.TextColor3 = Color3.fromRGB(255, 160, 160)
		label.Font = Enum.Font.SourceSans
		label.TextSize = 14
		label.TextWrapped = true
		label.Size = UDim2.fromOffset(420, 72)
		label.Position = UDim2.new(0.5, -210, 0.12, 0)
		label.Text = "Scorp Client failed: " .. tostring(mountErr)
		label.Parent = fallback
		Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
	end)
end