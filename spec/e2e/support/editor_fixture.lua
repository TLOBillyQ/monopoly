--- Lifecycle helpers for e2e specs.
---
--- Busted injects `pending` / `describe` / `it` as locals into each spec
--- file's chunk environment — they are not in `_G`, so a support module
--- cannot reach them directly. Specs therefore wire them in like this:
---
---   local fixture = require("spec.e2e.support.editor_fixture")
---   -- Forwarding closure: busted's file-load `pending` is a different
---   -- function than the one injected inside `it()`. Only the latter
---   -- actually pends the test, so we capture it lazily by name.
---   local hooks = fixture.bind({ pending = function(msg) pending(msg) end })
---
---   describe("...", function()
---     before_each(hooks.clean_logs)
---
---     it("plain edit-mode test", function()
---       hooks.skip_if_unavailable()      -- only valid inside it()
---       ...
---     end)
---
---     it("wrapped edit-mode test", hooks.with_edit_mode(function(client)
---       client.exec("...")               -- skip_if_unavailable is implicit
---     end))
---   end)
---
--- Note: busted's `pending` is not supported inside `before_each`, so
--- skip_if_unavailable must run from inside the `it()` body (either
--- directly or through the `with_*` wrappers).

local client = require("editor_cli.client")
local escape = require("editor_cli.escape")

local M = {}

M.client = client

local _availability_cache = nil

local function _editor_available()
  if _availability_cache == nil then
    _availability_cache = client.is_available()
  end
  return _availability_cache
end

local function _poll_until(predicate, timeout_ms, interval_ms)
  timeout_ms = timeout_ms or 30000
  interval_ms = interval_ms or 250
  local deadline = os.time() + math.ceil(timeout_ms / 1000)
  while os.time() <= deadline do
    if predicate() then return true end
    -- Crude sleep via os.execute; good enough at 250 ms granularity.
    if escape.is_windows() then
      os.execute("ping -n 1 -w " .. interval_ms .. " 127.0.0.1 > nul")
    else
      os.execute("sleep " .. (interval_ms / 1000))
    end
  end
  return false
end

local function _status_mode()
  local status = client.status()
  if type(status) ~= "table" then return nil end
  return status.mode or status.state or (status.playing and "playing") or "idle"
end

--- Bind busted-injected functions (currently just `pending`) and return a
--- table of test hooks the spec can pass to `before_each` / `it`.
---@param env table  -- { pending = function }
function M.bind(env)
  local pending_fn = env and env.pending
  if type(pending_fn) ~= "function" then
    error("editor_fixture.bind: expected env.pending to be a function (got " .. type(pending_fn) .. ")")
  end

  local hooks = {}

  --- Call from inside an `it()` body. Pends the current test (does not
  --- return on the pend path — busted's pending raises).
  function hooks.skip_if_unavailable()
    if not escape.is_windows() and not os.getenv("EDITOR_CLI_FORCE") then
      pending_fn("e2e: requires Windows host (set EDITOR_CLI_FORCE=1 to attempt anyway)")
      return
    end
    if not _editor_available() then
      pending_fn("e2e: editor-cli unreachable — start the editor before running this lane")
      return
    end
  end

  --- Safe for `before_each`: no-op when the editor is unreachable.
  function hooks.clean_logs()
    if _editor_available() then
      client.clear_logs()
    end
  end

  --- Wrap an edit-mode test body. Pends if prerequisites are missing,
  --- otherwise stops any leftover play-mode session and runs `fn(client)`.
  function hooks.with_edit_mode(fn)
    return function()
      hooks.skip_if_unavailable()
      if _status_mode() == "playing" then
        client.stop_game()
        _poll_until(function() return _status_mode() ~= "playing" end, 15000)
      end
      fn(client)
    end
  end

  --- Wrap a play-mode test body. Pends if prerequisites are missing,
  --- otherwise enters play mode, runs `fn(client)`, then leaves cleanly.
  function hooks.with_play_mode(fn)
    return function()
      hooks.skip_if_unavailable()
      if _status_mode() ~= "playing" then
        client.run_game()
        assert(
          _poll_until(function() return _status_mode() == "playing" end, 30000),
          "with_play_mode: editor did not reach playing state within 30s"
        )
      end
      local ok, err = pcall(fn, client)
      client.stop_game()
      _poll_until(function() return _status_mode() ~= "playing" end, 15000)
      if not ok then error(err) end
    end
  end

  hooks.client = client

  return hooks
end

--- Internal hook for tests that want to bypass caching.
function M._reset_availability_cache()
  _availability_cache = nil
end

return M
