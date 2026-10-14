--- Neutral command prefix; interpreter selection remains at foundation.
local path = require("foundation.path")
local interpreter = require("foundation.lua54")
local M = {}
M.detect_lua54 = interpreter.detect_lua54
M.lua54_bin = interpreter.lua54_bin
function M.runner_path()
  local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
  local dir = source:match("^(.*)/[^/]+$") or "tools/packages/test_runner"
  return path.normalize_path(path.join_path(dir, "runner.lua"))
end
function M.argv_prefix()
  return { M.lua54_bin(), M.runner_path() }
end
return M
