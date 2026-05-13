--- Log-marker protocol: capture structured results from editor-cli exec.
---
--- editor-cli's `exec` command does not return the value of the executed
--- Lua expression. To get a result back, the caller appends a well-known
--- prefix to a log line, and we scan `editor-cli --json logs` for that
--- marker.
---
--- Protocol contract:
---   1. Caller's Lua source must end with:
---        EditorAPI.log("__E2E_RESULT__:" .. json.encode(payload))
---   2. wrap_with_marker() can do that wrapping automatically when given
---      a Lua expression that evaluates to the payload value.
---   3. capture() runs clear-logs → exec → logs, then scans newest
---      lines for the marker prefix and decodes the JSON tail.

local json_reader = require("shared.lib.json_reader")

local MARKER = "__E2E_RESULT__:"
local DEFAULT_LOG_LIMIT = 200

local M = {}

--- The prefix used to identify result lines inside the editor log stream.
M.marker = MARKER

--- Wrap a Lua expression `expr_src` so that when executed it logs the
--- marker line carrying its JSON-encoded value. Requires the editor side
--- to expose a `json.encode`-compatible function as global `json`.
---@param expr_src string  -- a Lua expression like `EditorAPI.scene.get_units()`
---@return string lua_src  -- self-contained statement(s) to feed exec
function M.wrap_with_marker(expr_src)
  return table.concat({
    "local __ok, __val = pcall(function() return ",
    expr_src,
    " end); ",
    "EditorAPI.log(\"" .. MARKER .. "\" .. ",
    "(__ok and (json and json.encode({ok=true, value=__val}) or tostring(__val)) ",
    "or (json and json.encode({ok=false, err=tostring(__val)}) or (\"ERR:\" .. tostring(__val)))))",
  })
end

local function _decode_marker_payload(line)
  local _, marker_end = line:find(MARKER, 1, true)
  if not marker_end then return nil end
  local tail = line:sub(marker_end + 1)
  -- Be lenient: the editor log may add a trailing newline or timestamp suffix.
  local trimmed = tail:gsub("%s+$", "")
  local ok, decoded = pcall(json_reader.decode, trimmed)
  if ok then return decoded end
  return { ok = false, err = "marker_decode_failed", raw = trimmed }
end

local function _iter_log_lines(logs_json_text)
  -- editor-cli --json logs is expected to return either:
  --   { "entries": [ { "message": "...", ... }, ... ] }
  -- or a flat array of strings. We accept both and fall back to splitting
  -- the raw text on newlines if JSON parsing fails entirely.
  local ok, decoded = pcall(json_reader.decode, logs_json_text)
  local lines = {}
  if ok and type(decoded) == "table" then
    local entries = decoded.entries or decoded.logs or decoded
    if type(entries) == "table" then
      for _, entry in ipairs(entries) do
        if type(entry) == "string" then
          lines[#lines + 1] = entry
        elseif type(entry) == "table" then
          lines[#lines + 1] = entry.message or entry.text or entry.line or ""
        end
      end
      return lines
    end
  end
  -- Fallback: raw text, split on newlines.
  for line in tostring(logs_json_text):gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end
  return lines
end

--- Run a clear → exec → logs round-trip and return the decoded marker payload.
---@param adapter table  -- exposes clear_logs(), exec(lua_src), logs(opts)
---@param lua_src string -- complete Lua statement(s); must emit the marker
---@param opts table?    -- { log_limit = number, timeout_ms = number }
---@return table payload -- { ok=bool, value=any, err=string? }
function M.capture(adapter, lua_src, opts)
  opts = opts or {}
  local limit = opts.log_limit or DEFAULT_LOG_LIMIT

  adapter.clear_logs()
  local exec_stdout = adapter.exec(lua_src)

  local logs_text = adapter.logs({ limit = limit, json = true })
  local lines = _iter_log_lines(logs_text)

  -- Scan from newest to oldest. editor-cli typically returns chronological;
  -- the marker we want is the latest one emitted in this call.
  for index = #lines, 1, -1 do
    local line = lines[index]
    if line and line:find(MARKER, 1, true) then
      local payload = _decode_marker_payload(line)
      if payload ~= nil then
        return payload
      end
    end
  end

  return {
    ok = false,
    err = "marker_not_found",
    exec_stdout = exec_stdout,
    log_sample = table.concat(lines, "\n", math.max(1, #lines - 10), #lines),
  }
end

return M
