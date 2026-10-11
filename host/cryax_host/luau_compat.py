"""Turn executor Luau into something loadstring can compile.

Roblox executors often compile the editor buffer with Luau, but
`loadstring(game:HttpGet(...))()` uses a Lua 5.1 parser. Types,
`::` casts, backtick interpolation, `+=`, and if-expressions make
that parser return nil, and the trailing `()` becomes:

    :1: attempt to call a nil value
    Script '', Line 1
"""

from __future__ import annotations

IDENT_START = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
IDENT_CHARS = IDENT_START | set("0123456789")
BINOPS = {"+", "-", "*", "/", "%", "^", "..", "==", "~=", "<", ">", "<=", ">=", "and", "or"}
EXPR_PREV_OP = {"=", "(", ",", "{", "[", "+", "-", "*", "/", "%", "^", "..", "==", "~=", "<", ">", "<=", ">="}
KEYWORDS = {"and", "or", "not", "if", "then", "else", "elseif", "end", "function", "return", "local", "for", "while", "repeat", "until", "do", "break", "in"}


def loader_bootstrap(base_url: str) -> str:
    base = str(base_url or "").rstrip("/")
    url = f"{base}/script.lua"
    return f"""-- Cryax loader (plain Lua)
local url = {url!r}

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
			local ok, res = pcall(req, {{
				Url = target,
				Method = "GET",
			}})
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
"""


def desugar_luau(src: str) -> str:
    text = _strip_types(src)
    text = _unwrap_ident_parens(text)
    text = _convert_interpolations(text)
    text = _convert_compounds(text)
    text = _convert_if_expressions(text)
    text = _fix_lua51_paren_statements(text)
    text = _break_html_needles(text)
    return text


def _break_html_needles(src: str) -> str:
    """Old /loader rejected any body containing the bytes <html, including Lua source."""
    text = src.replace('"<html"', '"<" .. "html"')
    text = text.replace("'<html'", "'<' .. 'html'")
    text = text.replace('"<!DOCTYPE"', '"<" .. "!DOCTYPE"')
    text = text.replace("'<!DOCTYPE'", "'<' .. '!DOCTYPE'")
    return text


def _previous_word(src: str, i: int) -> str:
    j = i - 1
    while j >= 0 and src[j] in " \t":
        j -= 1
    if j < 0:
        return ""
    if not _is_ident(src[j]):
        return src[j]
    end = j + 1
    while j >= 0 and _is_ident(src[j]):
        j -= 1
    return src[j + 1 : end]


def _should_unwrap_ident_paren(src: str, open_i: int) -> bool:
    word = _previous_word(src, open_i)
    if word in {"#", "-", "not"}:
        return False
    if not word or word in KEYWORDS:
        return True
    if word[0] in IDENT_START:
        return False
    if word in ")]" or word[0] in "'\"":
        return False
    return True


def _unwrap_ident_parens(src: str) -> str:
    """Turn leftover `(env).Field` from `(env :: any).Field` into `env.Field`.

    Lua 5.1 / Luau loadstring treat newline then `(env).Field =` as an
    ambiguous call. A single identifier in parens is only a type-cast leftover.
    Leaves real calls like `foo(env).Name` alone.
    """
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            nxt = _skip_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            nxt = _skip_comment(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "[" and i + 1 < n and src[i + 1] in "=[":
            nxt = _skip_long_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "(":
            inner = _skip_ws(src, i + 1)
            if inner < n and _is_ident_start(src[inner]):
                ident_end = _skip_ident(src, inner)
                after_ident = _skip_ws(src, ident_end)
                if after_ident < n and src[after_ident] == ")":
                    after_paren = _skip_ws(src, after_ident + 1)
                    if after_paren < n and src[after_paren] in ".:[":
                        if _should_unwrap_ident_paren(src, i):
                            out.append(src[inner:ident_end])
                            i = after_ident + 1
                            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _fix_lua51_paren_statements(src: str) -> str:
    """Lua 5.1 treats newline + '(' as a call on the previous expression.

    `(getgenv()).Field = 1` after another expression is a parse error unless wrapped.
    Luau: "use ';' to separate statements". Lua 5.1 forbids a leading empty `;`,
    so wrap as `do (getgenv()).Field = 1; end`.
    """
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            nxt = _skip_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            nxt = _skip_comment(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "[" and i + 1 < n and src[i + 1] in "=[":
            nxt = _skip_long_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "\n":
            out.append(ch)
            i += 1
            j = i
            while j < n and src[j] in " \t":
                j += 1
            if j < n and src[j] == "(":
                k = _skip_balanced(src, j, "(", ")")
                k2 = _skip_ws(src, k)
                if k2 < n and src[k2] in ".:[":
                    line_end = src.find("\n", j)
                    if line_end < 0:
                        line_end = n
                    stmt_end = line_end
                    if stmt_end > 0 and src[stmt_end - 1] == "\r":
                        stmt_end -= 1
                    out.append(src[i:j])
                    out.append("do ")
                    out.append(src[j:stmt_end])
                    out.append("; end")
                    i = stmt_end
                    continue
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _is_ident_start(ch: str) -> bool:
    return ch in IDENT_START


def _is_ident(ch: str) -> bool:
    return ch in IDENT_CHARS


def _skip_ident(src: str, i: int) -> int:
    n = len(src)
    while i < n and _is_ident(src[i]):
        i += 1
    return i


def _skip_ws(src: str, i: int) -> int:
    n = len(src)
    while i < n and src[i] in " \t":
        i += 1
    return i


def _skip_string(src: str, i: int) -> int:
    n = len(src)
    quote = src[i]
    i += 1
    while i < n:
        ch = src[i]
        if ch == "\\" and i + 1 < n:
            i += 2
            continue
        if ch == quote:
            return i + 1
        if ch == "\n" and quote != "`":
            return i
        i += 1
    return n


def _skip_long_string(src: str, i: int) -> int:
    n = len(src)
    i += 1
    eqs = 0
    while i < n and src[i] == "=":
        eqs += 1
        i += 1
    if i >= n or src[i] != "[":
        return i
    i += 1
    close = "]" + ("=" * eqs) + "]"
    found = src.find(close, i)
    return n if found < 0 else found + len(close)


def _skip_comment(src: str, i: int) -> int:
    n = len(src)
    if i + 1 < n and src[i : i + 2] == "--":
        if i + 2 < n and src[i + 2] == "[":
            return _skip_long_string(src, i + 2)
        while i < n and src[i] != "\n":
            i += 1
        return i
    return i + 1


def _skip_balanced(src: str, i: int, opener: str, closer: str) -> int:
    n = len(src)
    depth = 0
    while i < n:
        ch = src[i]
        if ch in "'\"":
            i = _skip_string(src, i)
            continue
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            i = _skip_comment(src, i)
            continue
        if ch == "[" and i + 1 < n and src[i + 1] in "=[":
            i = _skip_long_string(src, i)
            continue
        if ch == opener:
            depth += 1
        elif ch == closer:
            depth -= 1
            i += 1
            if depth <= 0:
                return i
            continue
        i += 1
    return n


def _skip_type(src: str, i: int) -> int:
    n = len(src)
    i = _skip_ws(src, i)
    if i >= n:
        return i
    if src.startswith("typeof", i) and (i + 6 >= n or not _is_ident(src[i + 6])):
        i += 6
        i = _skip_ws(src, i)
        if i < n and src[i] == "(":
            i = _skip_balanced(src, i, "(", ")")
        return _skip_type_suffix(src, i)
    ch = src[i]
    if ch == "{":
        return _skip_type_suffix(src, _skip_balanced(src, i, "{", "}"))
    if ch == "(":
        return _skip_type_suffix(src, _skip_balanced(src, i, "(", ")"))
    if ch in "'\"":
        return _skip_type_suffix(src, _skip_string(src, i))
    if _is_ident_start(ch):
        i = _skip_ident(src, i)
        while True:
            i = _skip_ws(src, i)
            if i < n and src[i] == ".":
                i += 1
                i = _skip_ws(src, i)
                if i < n and _is_ident_start(src[i]):
                    i = _skip_ident(src, i)
                    continue
            break
        i = _skip_ws(src, i)
        if i < n and src[i] == "<":
            i = _skip_balanced(src, i, "<", ">")
        return _skip_type_suffix(src, i)
    return i + 1 if i < n else i


def _skip_type_suffix(src: str, i: int) -> int:
    n = len(src)
    while True:
        i = _skip_ws(src, i)
        if i < n and src[i] == "?":
            i += 1
            continue
        if i < n and src[i] in "|&":
            i += 1
            i = _skip_type(src, i)
            continue
        if src.startswith("->", i):
            i += 2
            i = _skip_type(src, i)
            continue
        break
    return i


def _is_method_colon(src: str, i: int) -> bool:
    j = i + 1
    n = len(src)
    if j < n and src[j] in " \t\r\n":
        return False
    if j >= n or not _is_ident_start(src[j]):
        return False
    j = _skip_ident(src, j)
    j = _skip_ws(src, j)
    return j < n and src[j] == "("


def _previous_code(src: str, i: int) -> str:
    j = i - 1
    while j >= 0 and src[j] in " \t":
        j -= 1
    return src[j] if j >= 0 else ""


def _at_line_start_keyword(src: str, i: int, word: str) -> bool:
    if not src.startswith(word, i):
        return False
    end = i + len(word)
    if end < len(src) and _is_ident(src[end]):
        return False
    j = i - 1
    while j >= 0 and src[j] in " \t":
        j -= 1
    return j < 0 or src[j] in "\n;"


def _skip_type_alias(src: str, i: int) -> int:
    """i points at the 'type' keyword of a type alias."""
    n = len(src)
    i = _skip_ws(src, i + 4)
    if i < n and _is_ident_start(src[i]):
        i = _skip_ident(src, i)
        i = _skip_ws(src, i)
        if i < n and src[i] == "<":
            i = _skip_balanced(src, i, "<", ">")
            i = _skip_ws(src, i)
        if i < n and src[i] == "=":
            return _skip_type(src, i + 1)
    line_end = src.find("\n", i)
    return n if line_end < 0 else line_end


def _strip_types(src: str) -> str:
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            nxt = _skip_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            nxt = _skip_comment(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "[" and i + 1 < n and src[i + 1] in "=[":
            nxt = _skip_long_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if _at_line_start_keyword(src, i, "export") and src.startswith("type", _skip_ws(src, i + 6)):
            i = _skip_type_alias(src, _skip_ws(src, i + 6))
            continue
        if _at_line_start_keyword(src, i, "type"):
            j = _skip_ws(src, i + 4)
            if j < n and _is_ident_start(src[j]):
                i = _skip_type_alias(src, i)
                continue
        if ch in " \t":
            j = _skip_ws(src, i)
            if src.startswith("::", j):
                i = _skip_type(src, j + 2)
                continue
        if src.startswith("::", i):
            i = _skip_type(src, i + 2)
            continue
        if ch == ":" and not _is_method_colon(src, i):
            prev = _previous_code(src, i)
            if prev in IDENT_CHARS or prev in ")]":
                i = _skip_type(src, i + 1)
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def _lua_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def _convert_interpolations(src: str) -> str:
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            nxt = _skip_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            nxt = _skip_comment(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "[" and i + 1 < n and src[i + 1] in "=[":
            nxt = _skip_long_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch != "`":
            out.append(ch)
            i += 1
            continue
        i += 1
        parts: list[str] = []
        buf: list[str] = []
        while i < n and src[i] != "`":
            if src[i] == "{" and not src.startswith("{{", i):
                if buf:
                    parts.append(_lua_string("".join(buf)))
                    buf = []
                depth = 1
                i += 1
                start = i
                while i < n and depth:
                    if src[i] in "'\"":
                        i = _skip_string(src, i)
                        continue
                    if src[i] == "{":
                        depth += 1
                    elif src[i] == "}":
                        depth -= 1
                        if depth == 0:
                            break
                    i += 1
                parts.append("tostring(" + src[start:i].strip() + ")")
                if i < n and src[i] == "}":
                    i += 1
                continue
            if src.startswith("{{", i):
                buf.append("{")
                i += 2
                continue
            if src.startswith("}}", i):
                buf.append("}")
                i += 2
                continue
            buf.append(src[i])
            i += 1
        if buf:
            parts.append(_lua_string("".join(buf)))
        if i < n and src[i] == "`":
            i += 1
        out.append(" (" + " .. ".join(parts or ['""']) + ") ")
    return "".join(out)


def _convert_compounds(src: str) -> str:
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            nxt = _skip_string(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            nxt = _skip_comment(src, i)
            out.append(src[i:nxt])
            i = nxt
            continue
        if src.startswith("+=", i):
            start = len(out)
            while start > 0 and out[start - 1] in " \t":
                start -= 1
            name_end = start
            while start > 0 and (out[start - 1].isalnum() or out[start - 1] in "._"):
                start -= 1
            target = "".join(out[start:name_end]).strip()
            if target:
                out.append(" = " + target + " + ")
                i += 2
                continue
        out.append(ch)
        i += 1
    return "".join(out)


class _Tok:
    __slots__ = ("kind", "val")

    def __init__(self, kind: str, val: str) -> None:
        self.kind = kind
        self.val = val


def _tokenize(src: str) -> list[_Tok]:
    toks: list[_Tok] = []
    i = 0
    n = len(src)
    multi = ["..=", "+=", "-=", "*=", "/=", "==", "~=", "<=", ">=", "..", "::", "->"]
    while i < n:
        ch = src[i]
        if ch in " \t\r\n":
            j = i
            while j < n and src[j] in " \t\r\n":
                j += 1
            toks.append(_Tok("WS", src[i:j]))
            i = j
            continue
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            j = _skip_comment(src, i)
            toks.append(_Tok("COMMENT", src[i:j]))
            i = j
            continue
        if ch in "'\"":
            j = _skip_string(src, i)
            toks.append(_Tok("STRING", src[i:j]))
            i = j
            continue
        if ch == "[" and i + 1 < n and src[i + 1] in "=[":
            j = _skip_long_string(src, i)
            toks.append(_Tok("STRING", src[i:j]))
            i = j
            continue
        hit = next((op for op in multi if src.startswith(op, i)), None)
        if hit:
            toks.append(_Tok("OP", hit))
            i += len(hit)
            continue
        if _is_ident_start(ch):
            j = _skip_ident(src, i)
            word = src[i:j]
            toks.append(_Tok("KW" if word in KEYWORDS else "IDENT", word))
            i = j
            continue
        if ch.isdigit() or (ch == "." and i + 1 < n and src[i + 1].isdigit()):
            j = i
            if src.startswith("0x", i) or src.startswith("0X", i):
                j += 2
                while j < n and src[j] in "0123456789abcdefABCDEF":
                    j += 1
            else:
                while j < n and (src[j].isdigit() or src[j] == "."):
                    j += 1
                if j < n and src[j] in "eE":
                    j += 1
                    if j < n and src[j] in "+-":
                        j += 1
                    while j < n and src[j].isdigit():
                        j += 1
            toks.append(_Tok("NUM", src[i:j]))
            i = j
            continue
        toks.append(_Tok("OP", ch))
        i += 1
    return toks


class _Parser:
    def __init__(self, toks: list[_Tok]) -> None:
        self.t = toks
        self.n = len(toks)

    def skip(self, i: int) -> int:
        while i < self.n and self.t[i].kind in {"WS", "COMMENT"}:
            i += 1
        return i

    def join(self, a: int, b: int) -> str:
        return "".join(tok.val for tok in self.t[a:b])

    def kw(self, i: int, word: str) -> bool:
        i = self.skip(i)
        return i < self.n and self.t[i].kind == "KW" and self.t[i].val == word

    def parse_if_expr(self, i: int) -> tuple[str, int]:
        i = self.skip(i)
        if i >= self.n or self.t[i].val != "if":
            raise ValueError("missing if")
        i += 1
        cond, i = self.parse_exp(i)
        i = self.skip(i)
        if not self.kw(i, "then"):
            raise ValueError("missing then")
        i = self.skip(i) + 1
        then_e, i = self.parse_exp(i)
        parts = [f"if {cond} then return {then_e}"]
        while self.kw(i, "elseif"):
            i = self.skip(i) + 1
            econd, i = self.parse_exp(i)
            i = self.skip(i)
            if not self.kw(i, "then"):
                raise ValueError("missing elseif then")
            i = self.skip(i) + 1
            ebody, i = self.parse_exp(i)
            parts.append(f"elseif {econd} then return {ebody}")
        if not self.kw(i, "else"):
            raise ValueError("missing else")
        i = self.skip(i) + 1
        else_e, i = self.parse_exp(i)
        parts.append(f"else return {else_e} end")
        return "(function() " + " ".join(parts) + " end)()", i

    def parse_exp(self, i: int) -> tuple[str, int]:
        text, i = self.parse_prefix(i)
        while True:
            j = self.skip(i)
            if j >= self.n:
                break
            tok = self.t[j]
            op = None
            if tok.kind == "KW" and tok.val in {"and", "or"}:
                op = tok.val
            elif tok.kind == "OP" and tok.val in BINOPS:
                op = tok.val
            else:
                break
            right, nxt = self.parse_prefix(j + 1)
            text = text + self.join(i, j) + op + self.join(j + 1, self.skip(j + 1)) + right
            i = nxt
        return text, i

    def parse_prefix(self, i: int) -> tuple[str, int]:
        raw = i
        i = self.skip(i)
        lead = self.join(raw, i)
        if i >= self.n:
            return lead, i
        tok = self.t[i]
        if tok.kind == "KW" and tok.val == "not":
            body, i = self.parse_prefix(i + 1)
            return lead + "not" + body, i
        if tok.kind == "OP" and tok.val in {"#", "-"}:
            body, i = self.parse_prefix(i + 1)
            return lead + tok.val + body, i
        if tok.kind == "KW" and tok.val == "if":
            transformed, i = self.parse_if_expr(i)
            suff, i = self.parse_suffix(i)
            return lead + transformed + suff, i
        if tok.kind == "KW" and tok.val == "function":
            end = self._skip_block(i, kind="function")
            suff, i = self.parse_suffix(end)
            return lead + self.join(i and self.skip(raw), end)[0:0] + self.join(self.skip(raw), end) + suff, i
        if tok.kind == "OP" and tok.val == "(":
            inner, i = self.parse_exp(i + 1)
            i = self.skip(i)
            close = ""
            if i < self.n and self.t[i].val == ")":
                close = ")"
                i += 1
            suff, i = self.parse_suffix(i)
            return lead + "(" + inner + close + suff, i
        if tok.kind == "OP" and tok.val == "{":
            end = self._skip_braces(i)
            suff, i = self.parse_suffix(end)
            return lead + self.join(self.skip(raw), end) + suff, i
        if tok.kind in {"IDENT", "NUM", "STRING", "KW"}:
            text = tok.val
            i += 1
            suff, i = self.parse_suffix(i)
            return lead + text + suff, i
        return lead + tok.val, i + 1

    def parse_suffix(self, i: int) -> tuple[str, int]:
        text = ""
        while True:
            j = self.skip(i)
            if j >= self.n:
                return text, i
            tok = self.t[j]
            if tok.kind == "OP" and tok.val == ".":
                k = self.skip(j + 1)
                if k < self.n and self.t[k].kind in {"IDENT", "KW"}:
                    text += self.join(i, k + 1)
                    i = k + 1
                    continue
                return text, i
            if tok.kind == "OP" and tok.val == "[":
                inner, nxt = self.parse_exp(j + 1)
                nxt = self.skip(nxt)
                close = ""
                if nxt < self.n and self.t[nxt].val == "]":
                    close = "]"
                    nxt += 1
                text += self.join(i, j) + "[" + inner + close
                i = nxt
                continue
            if tok.kind == "OP" and tok.val == "(":
                args, nxt = self._parse_args(j)
                text += self.join(i, j) + args
                i = nxt
                continue
            if tok.kind == "OP" and tok.val == ":":
                k = self.skip(j + 1)
                if k < self.n and self.t[k].kind in {"IDENT", "KW"}:
                    name_end = k + 1
                    kws = self.skip(name_end)
                    if kws < self.n and self.t[kws].val == "(":
                        args, nxt = self._parse_args(kws)
                        text += self.join(i, kws) + args
                        i = nxt
                        continue
                return text, i
            if tok.kind == "STRING":
                text += self.join(i, j + 1)
                i = j + 1
                continue
            if tok.kind == "OP" and tok.val == "{":
                end = self._skip_braces(j)
                text += self.join(i, end)
                i = end
                continue
            return text, i

    def _parse_args(self, i: int) -> tuple[str, int]:
        i = self.skip(i)
        if i >= self.n or self.t[i].val != "(":
            return "", i
        out = ["("]
        i += 1
        head = i
        i = self.skip(i)
        if i < self.n and self.t[i].val == ")":
            return "()", i + 1
        first = True
        i = head
        while i < self.n:
            if not first:
                s = self.skip(i)
                if s < self.n and self.t[s].val == ",":
                    out.append(self.join(i, s + 1))
                    i = s + 1
                elif s < self.n and self.t[s].val == ")":
                    out.append(self.join(i, s) + ")")
                    return "".join(out), s + 1
                else:
                    break
            first = False
            arg, i = self.parse_exp(i)
            out.append(arg)
        s = self.skip(i)
        if s < self.n and self.t[s].val == ")":
            out.append(self.join(i, s) + ")")
            return "".join(out), s + 1
        return "".join(out), i

    def _skip_braces(self, i: int) -> int:
        i = self.skip(i)
        if i >= self.n or self.t[i].val != "{":
            return i
        depth = 0
        while i < self.n:
            tok = self.t[i]
            if tok.kind == "OP" and tok.val == "{":
                depth += 1
            elif tok.kind == "OP" and tok.val == "}":
                depth -= 1
                i += 1
                if depth <= 0:
                    return i
                continue
            i += 1
        return i

    def _skip_block(self, i: int, kind: str) -> int:
        i = self.skip(i)
        depth = 0
        while i < self.n:
            tok = self.t[i]
            if tok.kind == "KW" and tok.val in {"function", "if", "for", "while", "repeat", "do"}:
                if tok.val == "do" and kind == "ignore-do":
                    i += 1
                    continue
                depth += 1
            elif tok.kind == "KW" and tok.val == "end":
                depth -= 1
                i += 1
                if depth <= 0:
                    return i
                continue
            elif tok.kind == "KW" and tok.val == "until":
                depth -= 1
                i += 1
                if depth <= 0:
                    return i
                continue
            i += 1
        return i


def _prev_code(toks: list[_Tok], i: int) -> _Tok | None:
    j = i - 1
    while j >= 0 and toks[j].kind in {"WS", "COMMENT"}:
        j -= 1
    return toks[j] if j >= 0 else None


def _convert_if_expressions(src: str) -> str:
    toks = _tokenize(src)
    parser = _Parser(toks)
    out: list[str] = []
    i = 0
    n = len(toks)
    while i < n:
        tok = toks[i]
        if tok.kind == "KW" and tok.val == "if":
            prev = _prev_code(toks, i)
            expr = False
            if prev is not None:
                if prev.kind == "KW" and prev.val in {"return", "and", "or"}:
                    expr = True
                elif prev.kind == "OP" and prev.val in EXPR_PREV_OP:
                    expr = True
            if expr:
                try:
                    text, nxt = parser.parse_if_expr(i)
                    out.append(text)
                    i = nxt
                    continue
                except Exception:
                    pass
        out.append(tok.val)
        i += 1
    return "".join(out)
