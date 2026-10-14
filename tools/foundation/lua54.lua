--- Shared, version-checked interpreter selection for every test backend.
local fs = require("foundation.fs")
local proc = require("foundation.proc")
local M = {}
local cached, resolved
local function available(value)
  if value:find("[/\\]") or value:match("^%a:") then return fs.path_exists(value) end
  return proc.command_exists(value)
end
local function is_lua54(value)
  if not available(value) then return false end
  local result = proc.run_command({ value, "-v" })
  return result.ok == true and tostring(result.output or ""):find("Lua 5%.4") ~= nil
end
function M.detect_lua54()
  if resolved then return cached end
  resolved = true
  local override = os.getenv("LUA54_BIN")
  if override and override ~= "" then
    if is_lua54(override) then cached = override end
    return cached
  end
  for _, candidate in ipairs({ "lua5.4", "lua54", "lua" }) do
    if is_lua54(candidate) then cached = candidate; return cached end
  end
end
function M.lua54_bin()
  return assert(M.detect_lua54(), "Lua 5.4 interpreter required; check LUA54_BIN")
end
return M
