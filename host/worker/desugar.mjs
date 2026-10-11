const BINOPS = new Set(["+", "-", "*", "/", "%", "^", "..", "==", "~=", "<", ">", "<=", ">=", "and", "or"]);
const EXPR_PREV_OP = new Set(["=", "(", ",", "{", "[", "+", "-", "*", "/", "%", "^", "..", "==", "~=", "<", ">", "<=", ">="]);
const KEYWORDS = new Set(["and", "or", "not", "if", "then", "else", "elseif", "end", "function", "return", "local", "for", "while", "repeat", "until", "do", "break", "in"]);
const IDENT_RE = /[A-Za-z_]/;
const IDENT_CONT = /[A-Za-z0-9_]/;

export function loaderBootstrap(baseUrl) {
  const base = String(baseUrl || "").replace(/\/+$/, "");
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

export function desugarLuau(src) {
  let text = stripTypes(src);
  text = unwrapIdentParens(text);
  text = convertInterpolations(text);
  text = convertCompounds(text);
  text = convertIfExpressions(text);
  text = fixLua51ParenStatements(text);
  text = breakHtmlNeedles(text);
  return text;
}

function breakHtmlNeedles(src) {
  return src
    .replaceAll('"<html"', '"<" .. "html"')
    .replaceAll("'<html'", "'<' .. 'html'")
    .replaceAll('"<!DOCTYPE"', '"<" .. "!DOCTYPE"')
    .replaceAll("'<!DOCTYPE'", "'<' .. '!DOCTYPE'");
}

function previousWord(src, i) {
  let j = i - 1;
  while (j >= 0 && (src[j] === " " || src[j] === "\t")) j -= 1;
  if (j < 0) return "";
  if (!isIdent(src[j])) return src[j];
  const end = j + 1;
  while (j >= 0 && isIdent(src[j])) j -= 1;
  return src.slice(j + 1, end);
}

function shouldUnwrapIdentParen(src, openI) {
  const word = previousWord(src, openI);
  if (word === "#" || word === "-" || word === "not") return false;
  if (!word || KEYWORDS.has(word)) return true;
  if (isIdentStart(word[0] || "")) return false;
  if (word === ")" || word === "]" || word[0] === "'" || word[0] === '"') return false;
  return true;
}

function unwrapIdentParens(src) {
  const out = [];
  let i = 0;
  const n = src.length;
  while (i < n) {
    const ch = src[i];
    if (ch === "'" || ch === '"') {
      const nxt = skipString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "-" && src[i + 1] === "-") {
      const nxt = skipComment(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "[" && (src[i + 1] === "=" || src[i + 1] === "[")) {
      const nxt = skipLongString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "(") {
      const inner = skipWs(src, i + 1);
      if (isIdentStart(src[inner] || "")) {
        const identEnd = skipIdent(src, inner);
        const afterIdent = skipWs(src, identEnd);
        if (src[afterIdent] === ")") {
          const afterParen = skipWs(src, afterIdent + 1);
          if (src[afterParen] === "." || src[afterParen] === ":" || src[afterParen] === "[") {
            if (shouldUnwrapIdentParen(src, i)) {
              out.push(src.slice(inner, identEnd));
              i = afterIdent + 1;
              continue;
            }
          }
        }
      }
    }
    out.push(ch);
    i += 1;
  }
  return out.join("");
}

function fixLua51ParenStatements(src) {
  const out = [];
  let i = 0;
  const n = src.length;
  while (i < n) {
    const ch = src[i];
    if (ch === "'" || ch === '"') {
      const nxt = skipString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "-" && src[i + 1] === "-") {
      const nxt = skipComment(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "[" && (src[i + 1] === "=" || src[i + 1] === "[")) {
      const nxt = skipLongString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "\n") {
      out.push(ch);
      i += 1;
      let j = i;
      while (j < n && (src[j] === " " || src[j] === "\t")) j += 1;
      if (src[j] === "(") {
        const k = skipBalanced(src, j, "(", ")");
        const k2 = skipWs(src, k);
        if (src[k2] === "." || src[k2] === ":" || src[k2] === "[") {
          let lineEnd = src.indexOf("\n", j);
          if (lineEnd < 0) lineEnd = n;
          let stmtEnd = lineEnd;
          if (stmtEnd > 0 && src[stmtEnd - 1] === "\r") stmtEnd -= 1;
          out.push(src.slice(i, j));
          out.push("do ");
          out.push(src.slice(j, stmtEnd));
          out.push("; end");
          i = stmtEnd;
          continue;
        }
      }
      continue;
    }
    out.push(ch);
    i += 1;
  }
  return out.join("");
}

function isIdentStart(ch) {
  return IDENT_RE.test(ch || "");
}
function isIdent(ch) {
  return IDENT_CONT.test(ch || "");
}
function skipIdent(src, i) {
  while (i < src.length && isIdent(src[i])) i += 1;
  return i;
}
function skipWs(src, i) {
  while (i < src.length && (src[i] === " " || src[i] === "\t")) i += 1;
  return i;
}
function skipString(src, i) {
  const quote = src[i];
  i += 1;
  while (i < src.length) {
    const ch = src[i];
    if (ch === "\\" && i + 1 < src.length) {
      i += 2;
      continue;
    }
    if (ch === quote) return i + 1;
    if (ch === "\n" && quote !== "`") return i;
    i += 1;
  }
  return src.length;
}
function skipLongString(src, i) {
  i += 1;
  let eqs = 0;
  while (i < src.length && src[i] === "=") {
    eqs += 1;
    i += 1;
  }
  if (i >= src.length || src[i] !== "[") return i;
  i += 1;
  const close = "]" + "=".repeat(eqs) + "]";
  const found = src.indexOf(close, i);
  return found < 0 ? src.length : found + close.length;
}
function skipComment(src, i) {
  if (src.startsWith("--", i)) {
    if (src[i + 2] === "[") return skipLongString(src, i + 2);
    while (i < src.length && src[i] !== "\n") i += 1;
    return i;
  }
  return i + 1;
}
function skipBalanced(src, i, opener, closer) {
  let depth = 0;
  while (i < src.length) {
    const ch = src[i];
    if (ch === "'" || ch === '"') {
      i = skipString(src, i);
      continue;
    }
    if (ch === "-" && src[i + 1] === "-") {
      i = skipComment(src, i);
      continue;
    }
    if (ch === "[" && (src[i + 1] === "=" || src[i + 1] === "[")) {
      i = skipLongString(src, i);
      continue;
    }
    if (ch === opener) depth += 1;
    else if (ch === closer) {
      depth -= 1;
      i += 1;
      if (depth <= 0) return i;
      continue;
    }
    i += 1;
  }
  return src.length;
}
function skipType(src, i) {
  const n = src.length;
  i = skipWs(src, i);
  if (i >= n) return i;
  if (src.startsWith("typeof", i) && (i + 6 >= n || !isIdent(src[i + 6]))) {
    i += 6;
    i = skipWs(src, i);
    if (src[i] === "(") i = skipBalanced(src, i, "(", ")");
    return skipTypeSuffix(src, i);
  }
  const ch = src[i];
  if (ch === "{") return skipTypeSuffix(src, skipBalanced(src, i, "{", "}"));
  if (ch === "(") return skipTypeSuffix(src, skipBalanced(src, i, "(", ")"));
  if (ch === "'" || ch === '"') return skipTypeSuffix(src, skipString(src, i));
  if (isIdentStart(ch)) {
    i = skipIdent(src, i);
    while (true) {
      i = skipWs(src, i);
      if (src[i] === ".") {
        i += 1;
        i = skipWs(src, i);
        if (isIdentStart(src[i] || "")) {
          i = skipIdent(src, i);
          continue;
        }
      }
      break;
    }
    i = skipWs(src, i);
    if (src[i] === "<") i = skipBalanced(src, i, "<", ">");
    return skipTypeSuffix(src, i);
  }
  return i < n ? i + 1 : i;
}
function skipTypeSuffix(src, i) {
  const n = src.length;
  while (true) {
    i = skipWs(src, i);
    if (src[i] === "?") {
      i += 1;
      continue;
    }
    if (src[i] === "|" || src[i] === "&") {
      i = skipType(src, i + 1);
      continue;
    }
    if (src.startsWith("->", i)) {
      i = skipType(src, i + 2);
      continue;
    }
    break;
  }
  return i;
}
function skipTypeAlias(src, i) {
  const n = src.length;
  i = skipWs(src, i + 4);
  if (isIdentStart(src[i] || "")) {
    i = skipIdent(src, i);
    i = skipWs(src, i);
    if (src[i] === "<") {
      i = skipBalanced(src, i, "<", ">");
      i = skipWs(src, i);
    }
    if (src[i] === "=") return skipType(src, i + 1);
  }
  const lineEnd = src.indexOf("\n", i);
  return lineEnd < 0 ? n : lineEnd;
}
function isMethodColon(src, i) {
  let j = i + 1;
  if (" \t\r\n".includes(src[j] || "")) return false;
  if (!isIdentStart(src[j] || "")) return false;
  j = skipIdent(src, j);
  j = skipWs(src, j);
  return src[j] === "(";
}
function previousCode(src, i) {
  let j = i - 1;
  while (j >= 0 && (src[j] === " " || src[j] === "\t")) j -= 1;
  return j >= 0 ? src[j] : "";
}
function atLineStartKeyword(src, i, word) {
  if (!src.startsWith(word, i)) return false;
  const end = i + word.length;
  if (end < src.length && isIdent(src[end])) return false;
  let j = i - 1;
  while (j >= 0 && (src[j] === " " || src[j] === "\t")) j -= 1;
  return j < 0 || src[j] === "\n" || src[j] === ";";
}
function stripTypes(src) {
  const out = [];
  let i = 0;
  const n = src.length;
  while (i < n) {
    const ch = src[i];
    if (ch === "'" || ch === '"') {
      const nxt = skipString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "-" && src[i + 1] === "-") {
      const nxt = skipComment(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "[" && (src[i + 1] === "=" || src[i + 1] === "[")) {
      const nxt = skipLongString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (atLineStartKeyword(src, i, "export") && src.startsWith("type", skipWs(src, i + 6))) {
      i = skipTypeAlias(src, skipWs(src, i + 6));
      continue;
    }
    if (atLineStartKeyword(src, i, "type")) {
      const j = skipWs(src, i + 4);
      if (isIdentStart(src[j] || "")) {
        i = skipTypeAlias(src, i);
        continue;
      }
    }
    if ((ch === " " || ch === "\t") && src.startsWith("::", skipWs(src, i))) {
      i = skipType(src, skipWs(src, i) + 2);
      continue;
    }
    if (src.startsWith("::", i)) {
      i = skipType(src, i + 2);
      continue;
    }
    if (ch === ":" && !isMethodColon(src, i)) {
      const prev = previousCode(src, i);
      if (/[A-Za-z0-9_]/.test(prev) || prev === ")" || prev === "]") {
        i = skipType(src, i + 1);
        continue;
      }
    }
    out.push(ch);
    i += 1;
  }
  return out.join("");
}
function luaString(text) {
  return `"${text.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
}
function convertInterpolations(src) {
  const out = [];
  let i = 0;
  const n = src.length;
  while (i < n) {
    const ch = src[i];
    if (ch === "'" || ch === '"') {
      const nxt = skipString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "-" && src[i + 1] === "-") {
      const nxt = skipComment(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "[" && (src[i + 1] === "=" || src[i + 1] === "[")) {
      const nxt = skipLongString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch !== "`") {
      out.push(ch);
      i += 1;
      continue;
    }
    i += 1;
    const parts = [];
    let buf = [];
    while (i < n && src[i] !== "`") {
      if (src[i] === "{" && !src.startsWith("{{", i)) {
        if (buf.length) {
          parts.push(luaString(buf.join("")));
          buf = [];
        }
        let depth = 1;
        i += 1;
        const start = i;
        while (i < n && depth) {
          if (src[i] === "'" || src[i] === '"') {
            i = skipString(src, i);
            continue;
          }
          if (src[i] === "{") depth += 1;
          else if (src[i] === "}") {
            depth -= 1;
            if (depth === 0) break;
          }
          i += 1;
        }
        parts.push("tostring(" + src.slice(start, i).trim() + ")");
        if (src[i] === "}") i += 1;
        continue;
      }
      if (src.startsWith("{{", i)) {
        buf.push("{");
        i += 2;
        continue;
      }
      if (src.startsWith("}}", i)) {
        buf.push("}");
        i += 2;
        continue;
      }
      buf.push(src[i]);
      i += 1;
    }
    if (buf.length) parts.push(luaString(buf.join("")));
    if (src[i] === "`") i += 1;
    out.push(" (" + (parts.length ? parts.join(" .. ") : '""') + ") ");
  }
  return out.join("");
}
function convertCompounds(src) {
  const out = [];
  let i = 0;
  const n = src.length;
  while (i < n) {
    const ch = src[i];
    if (ch === "'" || ch === '"') {
      const nxt = skipString(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (ch === "-" && src[i + 1] === "-") {
      const nxt = skipComment(src, i);
      out.push(src.slice(i, nxt));
      i = nxt;
      continue;
    }
    if (src.startsWith("+=", i)) {
      let start = out.length;
      while (start > 0 && (out[start - 1] === " " || out[start - 1] === "\t")) start -= 1;
      const nameEnd = start;
      while (start > 0 && /[A-Za-z0-9._]/.test(out[start - 1])) start -= 1;
      const target = out.slice(start, nameEnd).join("").trim();
      if (target) {
        out.push(" = " + target + " + ");
        i += 2;
        continue;
      }
    }
    out.push(ch);
    i += 1;
  }
  return out.join("");
}

function tokenize(src) {
  const toks = [];
  let i = 0;
  const n = src.length;
  const multi = ["..=", "+=", "-=", "*=", "/=", "==", "~=", "<=", ">=", "..", "::", "->"];
  while (i < n) {
    const ch = src[i];
    if (" \t\r\n".includes(ch)) {
      let j = i;
      while (j < n && " \t\r\n".includes(src[j])) j += 1;
      toks.push({ kind: "WS", val: src.slice(i, j) });
      i = j;
      continue;
    }
    if (ch === "-" && src[i + 1] === "-") {
      const j = skipComment(src, i);
      toks.push({ kind: "COMMENT", val: src.slice(i, j) });
      i = j;
      continue;
    }
    if (ch === "'" || ch === '"') {
      const j = skipString(src, i);
      toks.push({ kind: "STRING", val: src.slice(i, j) });
      i = j;
      continue;
    }
    if (ch === "[" && (src[i + 1] === "=" || src[i + 1] === "[")) {
      const j = skipLongString(src, i);
      toks.push({ kind: "STRING", val: src.slice(i, j) });
      i = j;
      continue;
    }
    const hit = multi.find((op) => src.startsWith(op, i));
    if (hit) {
      toks.push({ kind: "OP", val: hit });
      i += hit.length;
      continue;
    }
    if (isIdentStart(ch)) {
      const j = skipIdent(src, i);
      const word = src.slice(i, j);
      toks.push({ kind: KEYWORDS.has(word) ? "KW" : "IDENT", val: word });
      i = j;
      continue;
    }
    if (/\d/.test(ch) || (ch === "." && /\d/.test(src[i + 1] || ""))) {
      let j = i;
      if (src.startsWith("0x", i) || src.startsWith("0X", i)) {
        j += 2;
        while (j < n && /[0-9a-fA-F]/.test(src[j])) j += 1;
      } else {
        while (j < n && (/\d/.test(src[j]) || src[j] === ".")) j += 1;
        if (src[j] === "e" || src[j] === "E") {
          j += 1;
          if (src[j] === "+" || src[j] === "-") j += 1;
          while (j < n && /\d/.test(src[j])) j += 1;
        }
      }
      toks.push({ kind: "NUM", val: src.slice(i, j) });
      i = j;
      continue;
    }
    toks.push({ kind: "OP", val: ch });
    i += 1;
  }
  return toks;
}

class Parser {
  constructor(toks) {
    this.t = toks;
    this.n = toks.length;
  }
  skip(i) {
    while (i < this.n && (this.t[i].kind === "WS" || this.t[i].kind === "COMMENT")) i += 1;
    return i;
  }
  join(a, b) {
    let s = "";
    for (let i = a; i < b; i += 1) s += this.t[i].val;
    return s;
  }
  kw(i, word) {
    i = this.skip(i);
    return i < this.n && this.t[i].kind === "KW" && this.t[i].val === word;
  }
  parseIfExpr(i) {
    i = this.skip(i);
    if (i >= this.n || this.t[i].val !== "if") throw new Error("missing if");
    i += 1;
    let cond;
    [cond, i] = this.parseExp(i);
    i = this.skip(i);
    if (!this.kw(i, "then")) throw new Error("missing then");
    i = this.skip(i) + 1;
    let thenE;
    [thenE, i] = this.parseExp(i);
    const parts = [`if ${cond} then return ${thenE}`];
    while (this.kw(i, "elseif")) {
      i = this.skip(i) + 1;
      let econd;
      [econd, i] = this.parseExp(i);
      i = this.skip(i);
      if (!this.kw(i, "then")) throw new Error("missing elseif then");
      i = this.skip(i) + 1;
      let ebody;
      [ebody, i] = this.parseExp(i);
      parts.push(`elseif ${econd} then return ${ebody}`);
    }
    if (!this.kw(i, "else")) throw new Error("missing else");
    i = this.skip(i) + 1;
    let elseE;
    [elseE, i] = this.parseExp(i);
    parts.push(`else return ${elseE} end`);
    return ["(function() " + parts.join(" ") + " end)()", i];
  }
  parseExp(i) {
    let text;
    [text, i] = this.parsePrefix(i);
    while (true) {
      const j = this.skip(i);
      if (j >= this.n) break;
      const tok = this.t[j];
      let op = null;
      if (tok.kind === "KW" && (tok.val === "and" || tok.val === "or")) op = tok.val;
      else if (tok.kind === "OP" && BINOPS.has(tok.val)) op = tok.val;
      else break;
      const [right, nxt] = this.parsePrefix(j + 1);
      text = text + this.join(i, j) + op + this.join(j + 1, this.skip(j + 1)) + right;
      i = nxt;
    }
    return [text, i];
  }
  parsePrefix(i) {
    const raw = i;
    i = this.skip(i);
    const lead = this.join(raw, i);
    if (i >= this.n) return [lead, i];
    const tok = this.t[i];
    if (tok.kind === "KW" && tok.val === "not") {
      const [body, nxt] = this.parsePrefix(i + 1);
      return [lead + "not" + body, nxt];
    }
    if (tok.kind === "OP" && (tok.val === "#" || tok.val === "-")) {
      const [body, nxt] = this.parsePrefix(i + 1);
      return [lead + tok.val + body, nxt];
    }
    if (tok.kind === "KW" && tok.val === "if") {
      const [transformed, mid] = this.parseIfExpr(i);
      const [suff, nxt] = this.parseSuffix(mid);
      return [lead + transformed + suff, nxt];
    }
    if (tok.kind === "KW" && tok.val === "function") {
      const end = this.skipBlock(i);
      const [suff, nxt] = this.parseSuffix(end);
      return [lead + this.join(this.skip(raw), end) + suff, nxt];
    }
    if (tok.kind === "OP" && tok.val === "(") {
      const [inner, mid] = this.parseExp(i + 1);
      i = this.skip(mid);
      let close = "";
      if (i < this.n && this.t[i].val === ")") {
        close = ")";
        i += 1;
      }
      const [suff, nxt] = this.parseSuffix(i);
      return [lead + "(" + inner + close + suff, nxt];
    }
    if (tok.kind === "OP" && tok.val === "{") {
      const end = this.skipBraces(i);
      const [suff, nxt] = this.parseSuffix(end);
      return [lead + this.join(this.skip(raw), end) + suff, nxt];
    }
    if (tok.kind === "IDENT" || tok.kind === "NUM" || tok.kind === "STRING" || tok.kind === "KW") {
      const [suff, nxt] = this.parseSuffix(i + 1);
      return [lead + tok.val + suff, nxt];
    }
    return [lead + tok.val, i + 1];
  }
  parseSuffix(i) {
    let text = "";
    while (true) {
      const j = this.skip(i);
      if (j >= this.n) return [text, i];
      const tok = this.t[j];
      if (tok.kind === "OP" && tok.val === ".") {
        const k = this.skip(j + 1);
        if (k < this.n && (this.t[k].kind === "IDENT" || this.t[k].kind === "KW")) {
          text += this.join(i, k + 1);
          i = k + 1;
          continue;
        }
        return [text, i];
      }
      if (tok.kind === "OP" && tok.val === "[") {
        const [inner, mid] = this.parseExp(j + 1);
        let nxt = this.skip(mid);
        let close = "";
        if (nxt < this.n && this.t[nxt].val === "]") {
          close = "]";
          nxt += 1;
        }
        text += this.join(i, j) + "[" + inner + close;
        i = nxt;
        continue;
      }
      if (tok.kind === "OP" && tok.val === "(") {
        const [args, nxt] = this.parseArgs(j);
        text += this.join(i, j) + args;
        i = nxt;
        continue;
      }
      if (tok.kind === "OP" && tok.val === ":") {
        let k = this.skip(j + 1);
        if (k < this.n && (this.t[k].kind === "IDENT" || this.t[k].kind === "KW")) {
          k += 1;
          const kws = this.skip(k);
          if (kws < this.n && this.t[kws].val === "(") {
            const [args, nxt] = this.parseArgs(kws);
            text += this.join(i, kws) + args;
            i = nxt;
            continue;
          }
        }
        return [text, i];
      }
      if (tok.kind === "STRING") {
        text += this.join(i, j + 1);
        i = j + 1;
        continue;
      }
      if (tok.kind === "OP" && tok.val === "{") {
        const end = this.skipBraces(j);
        text += this.join(i, end);
        i = end;
        continue;
      }
      return [text, i];
    }
  }
  parseArgs(i) {
    i = this.skip(i);
    if (i >= this.n || this.t[i].val !== "(") return ["", i];
    const out = ["("];
    i += 1;
    const head = i;
    i = this.skip(i);
    if (i < this.n && this.t[i].val === ")") return ["()", i + 1];
    let first = true;
    i = head;
    while (i < this.n) {
      if (!first) {
        const s = this.skip(i);
        if (s < this.n && this.t[s].val === ",") {
          out.push(this.join(i, s + 1));
          i = s + 1;
        } else if (s < this.n && this.t[s].val === ")") {
          out.push(this.join(i, s) + ")");
          return [out.join(""), s + 1];
        } else break;
      }
      first = false;
      const [arg, nxt] = this.parseExp(i);
      out.push(arg);
      i = nxt;
    }
    const s = this.skip(i);
    if (s < this.n && this.t[s].val === ")") {
      out.push(this.join(i, s) + ")");
      return [out.join(""), s + 1];
    }
    return [out.join(""), i];
  }
  skipBraces(i) {
    i = this.skip(i);
    if (i >= this.n || this.t[i].val !== "{") return i;
    let depth = 0;
    while (i < this.n) {
      const tok = this.t[i];
      if (tok.kind === "OP" && tok.val === "{") depth += 1;
      else if (tok.kind === "OP" && tok.val === "}") {
        depth -= 1;
        i += 1;
        if (depth <= 0) return i;
        continue;
      }
      i += 1;
    }
    return i;
  }
  skipBlock(i) {
    i = this.skip(i);
    let depth = 0;
    while (i < this.n) {
      const tok = this.t[i];
      if (tok.kind === "KW" && ["function", "if", "for", "while", "repeat", "do"].includes(tok.val)) depth += 1;
      else if (tok.kind === "KW" && tok.val === "end") {
        depth -= 1;
        i += 1;
        if (depth <= 0) return i;
        continue;
      } else if (tok.kind === "KW" && tok.val === "until") {
        depth -= 1;
        i += 1;
        if (depth <= 0) return i;
        continue;
      }
      i += 1;
    }
    return i;
  }
}

function prevCode(toks, i) {
  let j = i - 1;
  while (j >= 0 && (toks[j].kind === "WS" || toks[j].kind === "COMMENT")) j -= 1;
  return j >= 0 ? toks[j] : null;
}

function convertIfExpressions(src) {
  const toks = tokenize(src);
  const parser = new Parser(toks);
  const out = [];
  let i = 0;
  while (i < toks.length) {
    const tok = toks[i];
    if (tok.kind === "KW" && tok.val === "if") {
      const prev = prevCode(toks, i);
      let expr = false;
      if (prev) {
        if (prev.kind === "KW" && (prev.val === "return" || prev.val === "and" || prev.val === "or")) expr = true;
        else if (prev.kind === "OP" && EXPR_PREV_OP.has(prev.val)) expr = true;
      }
      if (expr) {
        try {
          const [text, nxt] = parser.parseIfExpr(i);
          out.push(text);
          i = nxt;
          continue;
        } catch {
          /* keep original tokens */
        }
      }
    }
    out.push(tok.val);
    i += 1;
  }
  return out.join("");
}
