--- Public client for editor-cli — the bridge that lets e2e specs talk to
--- a running Eggy editor instance.
---
--- Design constraint: tests run on the same Windows host as the editor, so
--- this module only knows how to invoke a local `editor-cli.exe` binary via
--- io.popen. No SSH / HTTP transport abstraction.
---
--- Public surface:
---   M.run(args)               -- raw call, returns stdout text
---   M.is_available()          -- can we even reach editor-cli?
---   M.status()                -- decoded JSON from `--json status`
---   M.clear_logs()            -- clears the editor log buffer
---   M.logs(opts)              -- raw stdout from `--json logs`
---   M.exec(lua_src)           -- edit-mode Lua, fire-and-forget
---   M.exec_capture(expr_src)  -- edit-mode Lua, marker-based result
---   M.game_exec(play_src)     -- play-mode Lua, fire-and-forget
---   M.game_exec_capture(expr_src) -- play-mode Lua, marker-based result
---   M.run_game()              -- start play mode
---   M.stop_game()             -- stop play mode

local escape = require("editor_cli.escape")
local result_capture = require("editor_cli.result_capture")
local json_reader = require("shared.lib.json_reader")

local M = {}

local function _binary()
  local override = os.getenv("EDITOR_CLI_BIN")
  if override and override ~= "" then
    return override
  end
  return escape.is_windows() and "editor-cli.exe" or "editor-cli"
end

--- Low-level: run editor-cli with the given pre-escaped argument string.
--- Returns (stdout, exit_code). Raises on io.popen failure.
function M.run(args)
  local cmd = _binary() .. " " .. args
  local handle, popen_err = io.popen(cmd .. " 2>&1", "r")
  if not handle then
    error("editor_cli: io.popen failed: " .. tostring(popen_err))
  end
  local stdout = handle:read("*a") or ""
  local ok, _, code = handle:close()
  if not ok then
    return stdout, code or -1
  end
  return stdout, 0
end

--- Best-effort availability probe. Returns true if `editor-cli status`
--- exits cleanly, false otherwise. Useful as a fixture pre-flight check.
function M.is_available()
  local ok, _, code = pcall(M.run, "status")
  return ok and code == 0
end

function M.status()
  local stdout, code = M.run("--json status")
  if code ~= 0 then
    error("editor_cli: status failed (exit=" .. tostring(code) .. "):\n" .. stdout)
  end
  local ok, decoded = pcall(json_reader.decode, stdout)
  if ok then return decoded end
  return { raw = stdout }
end

function M.clear_logs()
  local stdout, code = M.run("clear-logs")
  if code ~= 0 then
    error("editor_cli: clear-logs failed (exit=" .. tostring(code) .. "):\n" .. stdout)
  end
  return true
end

function M.logs(opts)
  opts = opts or {}
  local args = {}
  if opts.json ~= false then
    args[#args + 1] = "--json"
  end
  args[#args + 1] = "logs"
  if opts.limit then
    args[#args + 1] = "-n"
    args[#args + 1] = tostring(opts.limit)
  end
  local stdout, code = M.run(table.concat(args, " "))
  if code ~= 0 then
    error("editor_cli: logs failed (exit=" .. tostring(code) .. "):\n" .. stdout)
  end
  return stdout
end

--- Fire edit-mode Lua. Returns stdout text. No result capture.
function M.exec(lua_src)
  local arg = escape.shell_arg(lua_src)
  local stdout, code = M.run("exec " .. arg)
  if code ~= 0 then
    error("editor_cli: exec failed (exit=" .. tostring(code) .. "):\n" .. stdout)
  end
  return stdout
end

--- Fire play-mode Lua via `game_execute(...)`. Returns stdout text.
function M.game_exec(play_src)
  return M.exec(escape.wrap_game_execute(play_src))
end

local function _make_adapter()
  return {
    clear_logs = M.clear_logs,
    exec = M.exec,
    logs = M.logs,
  }
end

--- Edit-mode Lua expression with marker-based result capture.
--- Returns the decoded payload table: { ok=bool, value=any, err=string? }.
function M.exec_capture(expr_src)
  local wrapped = result_capture.wrap_with_marker(expr_src)
  return result_capture.capture(_make_adapter(), wrapped)
end

--- Play-mode Lua expression with marker-based result capture.
--- The expression is evaluated inside game_execute(...) on the play runtime;
--- the result marker is still emitted via EditorAPI.log on the edit runtime
--- by way of a shared global. Caller's `expr_src` must be a Lua expression.
function M.game_exec_capture(expr_src)
  -- Play side computes value, edit side logs the marker. To bridge them
  -- we have play code store the value on a global, then edit code reads
  -- and emits the marker.
  local play_lua = "_G.__E2E_LAST_RESULT = (" .. expr_src .. ")"
  M.game_exec(play_lua)
  local edit_lua = result_capture.wrap_with_marker("_G.__E2E_LAST_RESULT")
  return result_capture.capture(_make_adapter(), edit_lua)
end

function M.run_game()
  local stdout, code = M.run("run-game")
  if code ~= 0 then
    error("editor_cli: run-game failed (exit=" .. tostring(code) .. "):\n" .. stdout)
  end
  return stdout
end

function M.stop_game()
  local stdout, code = M.run("stop-game")
  if code ~= 0 then
    error("editor_cli: stop-game failed (exit=" .. tostring(code) .. "):\n" .. stdout)
  end
  return stdout
end

return M
