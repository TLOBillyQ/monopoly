--- Shell and Lua escaping helpers for editor_cli bridge.
---
--- Two layers of escaping are at play when we call editor-cli:
---
---   1. Shell-level: the Lua source we pass via `exec "..."` must survive
---      cmd.exe / sh parsing.
---   2. Lua-level: when the inner action is `game_execute(<lua_src>)`, the
---      play-side Lua is itself a string literal inside another Lua program.
---
--- This module isolates both transforms so client.lua and result_capture.lua
--- never have to think about quoting hell.

local M = {}

local function _is_windows()
  return package.config:sub(1, 1) == "\\"
end

--- Quote a single argument so the shell will pass it verbatim to the
--- child process. Handles both POSIX sh and Windows cmd.exe + MSVCRT
--- argv parsing.
---@param arg string
---@return string
function M.shell_arg(arg)
  if arg == nil then
    return '""'
  end
  if _is_windows() then
    -- MSVCRT argv parsing: wrap in double quotes; escape backslashes that
    -- precede a quote, and escape internal quotes with backslash.
    local out = tostring(arg)
    out = out:gsub('(\\*)"', function(slashes) return slashes .. slashes .. "\\\"" end)
    out = out:gsub('(\\+)$', function(slashes) return slashes .. slashes end)
    return '"' .. out .. '"'
  end
  -- POSIX: single-quote and split around any embedded single quotes.
  return "'" .. tostring(arg):gsub("'", "'\\''") .. "'"
end

--- Pick a Lua long-bracket level that does not appear inside `src`.
--- Starts at `[==[ ... ]==]` (level 2) and escalates as needed so the
--- caller never has to worry about collisions with `]]` inside the
--- payload.
---@param src string
---@return string opener
---@return string closer
function M.pick_long_bracket(src)
  local level = 2
  while true do
    local equals = string.rep("=", level)
    local closer = "]" .. equals .. "]"
    if not string.find(src, closer, 1, true) then
      return "[" .. equals .. "[", closer
    end
    level = level + 1
    if level > 16 then
      error("editor_cli.escape: could not find non-colliding long bracket level for payload")
    end
  end
end

--- Wrap play-side Lua source `play_src` so that running the result as
--- edit-mode Lua will invoke `game_execute(play_src)` against the play
--- runtime. Uses dynamic long-bracket level so the payload is allowed
--- to contain arbitrary `]]` or `]==]` sequences.
---@param play_src string
---@return string edit_src
function M.wrap_game_execute(play_src)
  local opener, closer = M.pick_long_bracket(play_src)
  return "game_execute(" .. opener .. play_src .. closer .. ")"
end

--- Detect Windows host. Exposed for callers that want to branch on it.
function M.is_windows()
  return _is_windows()
end

return M
