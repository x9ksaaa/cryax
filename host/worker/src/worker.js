import { CLIENT_SCRIPT } from "./script.generated.js";

const TEXT = {
  "content-type": "text/plain; charset=utf-8",
  "cache-control": "no-store, no-cache, must-revalidate",
};
const JSON_HDR = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store, no-cache, must-revalidate",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: JSON_HDR });
}

function secretOk(request, env, url) {
  const expected = String(env.API_SECRET || "cryaxontop");
  const got = (request.headers.get("x-api-secret") || url.searchParams.get("secret") || "").trim();
  return got === expected;
}

function loaderBootstrap(base) {
  const url = JSON.stringify(`${base}/script.lua`);
  return `-- Cryax loader (plain Lua)
local url = ${url}

local function looks_like_script(src)
	if type(src) ~= "string" or #src < 80 then
		return false
	end
	-- Only the response head. The client source itself contains "<html".
	local head = string.gsub(string.sub(src, 1, 200), "^%s+", "")
	if string.sub(head, 1, 1) == "<" then
		return false
	end
	if string.find(string.sub(head, 1, 40), "404:", 1, true) then
		return false
	end
	return true
end

local function download(target)
	local src
	pcall(function()
		src = game:HttpGet(target)
	end)
	if not looks_like_script(src) then
		pcall(function()
			src = game:HttpGet(target, true)
		end)
	end
	if not looks_like_script(src) then
		local req = http_request or request or httpget or HttpGet
		if type(syn) == "table" and type(syn.request) == "function" then
			req = syn.request
		elseif type(fluxus) == "table" and type(fluxus.request) == "function" then
			req = fluxus.request
		elseif type(http) == "table" and type(http.request) == "function" then
			req = http.request
		end
		if type(req) == "function" then
			local ok, res = pcall(req, {
				Url = target,
				Method = "GET",
			})
			if ok then
				if type(res) == "table" then
					src = res.Body or res.body or res.Source
				elseif type(res) == "string" then
					src = res
				end
			end
		end
	end
	if looks_like_script(src) then
		return src
	end
	return nil
end

local src = download(url)
if not src then
	error("Cryax: download failed (" .. url .. "). Open that URL in a browser; if it looks like Lua, git pull and re-run host/worker/deploy.ps1.", 0)
end

local compile = loadstring or load
if type(compile) ~= "function" then
	error("Cryax: this executor has no loadstring/load", 0)
end

local fn, err = compile(src)
if not fn then
	local why = tostring(err)
	if string.find(why, "ambiguous", 1, true) or string.find(src, "(env ).CryaxClientEpoch", 1, true) then
		error("Cryax: this workers.dev /script.lua is still old 3.3 (ambiguous (env)). Run host/worker/deploy.ps1, wait for the deploy, then paste the loadstring again.", 0)
	end
	error("Cryax: compile failed: " .. why, 0)
end
fn()
`;
}

function bakeScript(src, base) {
  return src
    .replaceAll('local BAKED_API_URL = "http://127.0.0.1:8787"', `local BAKED_API_URL = "${base}"`)
    .replaceAll('API_URL = "http://127.0.0.1:8787"', `API_URL = "${base}"`)
    .replaceAll('API_ROOT = "http://127.0.0.1:8787/cryax/v1"', `API_ROOT = "${base}/cryax/v1"`);
}

function scriptResponse(base) {
  return new Response(bakeScript(CLIENT_SCRIPT, base), {
    headers: { ...TEXT, "content-disposition": "inline; filename=cryax.lua" },
  });
}

export class CryaxStore {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.ready = false;
  }

  ensure() {
    if (this.ready) {
      return;
    }
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT);
      CREATE TABLE IF NOT EXISTS tags (id TEXT PRIMARY KEY, json TEXT);
      CREATE TABLE IF NOT EXISTS images (id TEXT, kind TEXT, payload TEXT, PRIMARY KEY (id, kind));
      CREATE TABLE IF NOT EXISTS presence (id TEXT PRIMARY KEY, json TEXT, expires REAL);
    `);
    this.ready = true;
  }

  metaGet(key, fallback) {
    const row = this.ctx.storage.sql.exec("SELECT v FROM meta WHERE k = ?", key).toArray()[0];
    return row ? row.v : fallback;
  }

  metaSet(key, value) {
    this.ctx.storage.sql.exec("INSERT OR REPLACE INTO meta (k, v) VALUES (?, ?)", key, String(value));
  }

  bump() {
    const next = Number(this.metaGet("revision", "0")) + 1;
    this.metaSet("revision", String(next));
    return next;
  }

  allTags() {
    const users = {};
    for (const row of this.ctx.storage.sql.exec("SELECT id, json FROM tags").toArray()) {
      try {
        users[String(row.id)] = JSON.parse(row.json);
      } catch {
        /* skip */
      }
    }
    return users;
  }

  async fetch(request) {
    try {
      return await this.dispatch(request);
    } catch (err) {
      const message = err && err.message ? err.message : String(err);
      return json({ detail: message }, 500);
    }
  }

  async dispatch(request) {
    this.ensure();
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";
    const method = request.method.toUpperCase();
    if (!secretOk(request, this.env, url)) {
      return json({ detail: "bad secret" }, 401);
    }

    if (path === "/nametags" || path === "/cryax/v1/nametags") {
      if (method === "GET") {
        return json({ users: this.allTags() });
      }
    }

    if (path === "/nametags/revision" || path === "/cryax/v1/nametags/revision") {
      const users = {};
      for (const [id, tag] of Object.entries(this.allTags())) {
        users[id] = String(tag.updated_at || "");
      }
      return json({ revision: Number(this.metaGet("revision", "0")), users });
    }

    const imageMatch = path.match(/^\/(?:images|media)\/nametag\/(\d+)\/(icon|bg)(?:\/b64)?$/);
    if (imageMatch && method === "GET") {
      const id = imageMatch[1];
      const kind = imageMatch[2];
      const row = this.ctx.storage.sql
        .exec("SELECT payload FROM images WHERE id = ? AND kind = ?", id, kind)
        .toArray()[0];
      if (!row) {
        if (path.includes("/b64")) {
          return json({ data: "", frames: [] });
        }
        return json({ detail: "missing image" }, 404);
      }
      let payload = { frames: [], delay: 0.08 };
      try {
        payload = JSON.parse(row.payload);
      } catch {
        /* empty */
      }
      const frames = Array.isArray(payload.frames) ? payload.frames : [];
      if (path.includes("/b64")) {
        return json({
          data: frames[0] || "",
          frames,
          delay: Number(payload.delay || 0.08),
          content_type: "image/png",
        });
      }
      if (!frames[0]) {
        return json({ detail: "missing image" }, 404);
      }
      const bytes = Uint8Array.from(atob(frames[0]), (c) => c.charCodeAt(0));
      return new Response(bytes, {
        headers: { "content-type": "image/png", "cache-control": "no-store" },
      });
    }

    if (path === "/cryax/v1/heartbeat" && (method === "GET" || method === "POST")) {
      let body = {};
      if (method === "POST") {
        try {
          body = await request.json();
        } catch {
          body = {};
        }
      }
      const robloxId = Number(body.roblox_id || url.searchParams.get("roblox_id") || 0);
      if (!robloxId) {
        return json({ detail: "roblox_id required" }, 400);
      }
      const ttl = 15;
      const entry = {
        roblox_id: robloxId,
        roblox_username: String(body.roblox_username || url.searchParams.get("roblox_username") || ""),
        expires: Date.now() / 1000 + ttl,
      };
      this.ctx.storage.sql.exec(
        "INSERT OR REPLACE INTO presence (id, json, expires) VALUES (?, ?, ?)",
        String(robloxId),
        JSON.stringify(entry),
        entry.expires,
      );
      return json({ ok: true, roblox_id: robloxId });
    }

    if (path === "/cryax/v1/online") {
      const now = Date.now() / 1000;
      this.ctx.storage.sql.exec("DELETE FROM presence WHERE expires < ?", now);
      const ids = this.ctx.storage.sql
        .exec("SELECT id FROM presence WHERE expires >= ?", now)
        .toArray()
        .map((row) => Number(row.id));
      return json({ user_ids: ids, users: ids.map((user_id) => ({ roblox_id: user_id })) });
    }

    if (path === "/cryax/v1/access") {
      return json({ allowed: true, reason: "open", username: url.searchParams.get("roblox_username") || "" });
    }

    if (path === "/cryax/v1/session" && method === "POST") {
      let body = {};
      try {
        body = await request.json();
      } catch {
        body = {};
      }
      if (body.roblox_id) {
        const ttl = 15;
        const robloxId = Number(body.roblox_id);
        const entry = { roblox_id: robloxId, expires: Date.now() / 1000 + ttl };
        this.ctx.storage.sql.exec(
          "INSERT OR REPLACE INTO presence (id, json, expires) VALUES (?, ?, ?)",
          String(robloxId),
          JSON.stringify(entry),
          entry.expires,
        );
      }
      const now = Date.now() / 1000;
      const ids = this.ctx.storage.sql
        .exec("SELECT id FROM presence WHERE expires >= ?", now)
        .toArray()
        .map((row) => Number(row.id));
      return json({
        ok: true,
        presence: { user_ids: ids, users: ids.map((user_id) => ({ roblox_id: user_id })) },
        config: { presence_interval: 3, command_poll_interval: 0.35 },
      });
    }

    if (path === "/cryax/v1/executions") {
      return json({ ok: true });
    }
    if (path === "/cryax/v1/commands") {
      if (method === "GET") {
        return json({ commands: [] });
      }
      return json({ ok: false, reason: "commands_disabled" });
    }

    const tagPut = path.match(/^\/internal\/tags\/(\d+)$/);
    if (tagPut && method === "PUT") {
      const id = tagPut[1];
      const tag = await request.json();
      tag.roblox_id = Number(id);
      this.ctx.storage.sql.exec("INSERT OR REPLACE INTO tags (id, json) VALUES (?, ?)", id, JSON.stringify(tag));
      this.bump();
      return json({ ok: true, roblox_id: Number(id) });
    }
    if (tagPut && method === "DELETE") {
      const id = tagPut[1];
      this.ctx.storage.sql.exec("DELETE FROM tags WHERE id = ?", id);
      this.ctx.storage.sql.exec("DELETE FROM images WHERE id = ?", id);
      this.bump();
      return json({ ok: true });
    }

    const imgPut = path.match(/^\/internal\/images\/(\d+)\/(icon|bg)$/);
    if (imgPut && method === "PUT") {
      const id = imgPut[1];
      const kind = imgPut[2];
      const payload = await request.json();
      this.ctx.storage.sql.exec(
        "INSERT OR REPLACE INTO images (id, kind, payload) VALUES (?, ?, ?)",
        id,
        kind,
        JSON.stringify({ frames: payload.frames || [], delay: payload.delay || 0.08 }),
      );
      this.bump();
      return json({ ok: true });
    }

    if (path === "/internal/snapshot" && method === "PUT") {
      const payload = await request.json();
      const users = payload.users || {};
      this.ctx.storage.sql.exec("DELETE FROM tags");
      for (const [id, tag] of Object.entries(users)) {
        this.ctx.storage.sql.exec("INSERT OR REPLACE INTO tags (id, json) VALUES (?, ?)", String(id), JSON.stringify(tag));
      }
      const images = payload.images || {};
      this.ctx.storage.sql.exec("DELETE FROM images");
      for (const [key, body] of Object.entries(images)) {
        const [id, kind] = String(key).split(":");
        if (!id || (kind !== "icon" && kind !== "bg")) {
          continue;
        }
        this.ctx.storage.sql.exec(
          "INSERT OR REPLACE INTO images (id, kind, payload) VALUES (?, ?, ?)",
          id,
          kind,
          JSON.stringify({ frames: body.frames || [], delay: body.delay || 0.08 }),
        );
      }
      this.bump();
      return json({ ok: true, users: Object.keys(users).length });
    }

    return json({ detail: "not found" }, 404);
  }
}

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);
      const path = url.pathname.replace(/\/+$/, "") || "/";
      const base = `${url.protocol}//${url.host}`;

      if (path === "/") {
        const line = `loadstring(game:HttpGet("${base}/loader"))()`;
        return new Response(`Cryax API\n\n${line}\n`, { headers: TEXT });
      }
      if (path === "/loader") {
        return new Response(loaderBootstrap(base), {
          headers: { ...TEXT, "content-disposition": "inline; filename=loader.lua" },
        });
      }
      if (path === "/script.lua" || path === "/script" || path === "/cryax.lua") {
        return scriptResponse(base);
      }
      if (path === "/loadstring") {
        return new Response(`loadstring(game:HttpGet("${base}/loader"))()\n`, { headers: TEXT });
      }
      if (path === "/health") {
        return json({ ok: true, worker: true, public_base_url: base });
      }
      if (!env.STORE) {
        return json({ detail: "store binding missing — redeploy the worker" }, 500);
      }
      const stub = env.STORE.get(env.STORE.idFromName("main"));
      return stub.fetch(request);
    } catch (err) {
      const message = err && err.message ? err.message : String(err);
      return json({ detail: message }, 500);
    }
  },
};
