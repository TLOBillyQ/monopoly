--- e2e profile-lane live adapter -- ENVIRONMENTALLY UNSUITABLE BOUNDARY.
---
--- This module is the thin transport that drives one test profile against a
--- running Eggy editor via editor-cli and hands the captured state back to the
--- pure lane reducer (src.app.testing.e2e_profile_lane). It can only be
--- validated against a live Windows editor; the headless lane pends. Keep ALL
--- judgment out of here -- enumeration lives in lane.partition, the per-field
--- comparison in lane.match, the state distillation in lane.observe. The only
--- thing this file owns is "how to talk to the editor".
---
--- LIVE-VALIDATION NOTES (must be confirmed on a real editor, see the
--- e2e-profile-lane handoff):
---   * The boot source pins STARTUP_TEST_PROFILE in the edit runtime; the play
---     boot must read it. If the editor isolates edit/play Lua state, the boot
---     hook may need to move into the play snippet.
---   * The drive forces every player onto the AI policy and pumps the real loop;
---     the acting player must fire its held item during the item phase for the
---     mirrored invariant to reproduce.
---   * Switching profiles in one session assumes the editor rebuilds app state
---     on a fresh play boot. Phase 1 runs a single profile, so this is untested.

local M = {}

local LANE_MODULE = "src.app.testing.e2e_profile_lane"
local HANDLE_MODULE = "src.app.testing.live_handle"

-- Serialize an expect table into a Lua literal so the in-editor observe call
-- can read exactly the fields the lane asserts. Handles the expect shape only:
-- nested tables with integer/string keys and string/number/boolean leaves.
local function _to_lua(value)
  local kind = type(value)
  if kind == "table" then
    local parts = {}
    for key, item in pairs(value) do
      local key_src
      if type(key) == "number" then
        key_src = "[" .. tostring(key) .. "]"
      else
        key_src = "[" .. string.format("%q", key) .. "]"
      end
      parts[#parts + 1] = key_src .. "=" .. _to_lua(item)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif kind == "string" then
    return string.format("%q", value)
  else
    return tostring(value)
  end
end

M._to_lua = _to_lua

--- Edit-mode snippet: pin the profile the next play boot will load.
function M.boot_source(profile_name)
  return "_G.STARTUP_TEST_PROFILE = " .. string.format("%q", profile_name)
end

--- Play-mode expression: force AI self-play, seed the rng deterministically,
--- record published events, pump the real loop for exactly one turn, then
--- distil the observed state via the shared lane.observe reducer. Returns the
--- observed table as the expression's value.
function M.drive_and_observe_source(expect, opts)
  opts = opts or {}
  local seed = opts.seed or 1
  local max_ticks = opts.max_ticks or 2000
  local dt = opts.dt or 0.1
  return ([[(function()
    local lane = require(%q)
    local lh = require(%q)
    local loop = require("src.turn.loop")
    local game, state = lh.get(), lh.get_state()
    if not game or not state then error("e2e: live game/state handle is empty") end
    local _seed = %d
    local function _rand(_, lo, hi)
      _seed = (_seed * 1103515245 + 12345) %% 2147483648
      return lo + (_seed %% (hi - lo + 1))
    end
    game.rng = { next_int = _rand }
    if state.auto_runner and state.auto_runner.set_enabled then state.auto_runner:set_enabled(true) end
    state.auto_all = true
    local recorded = {}
    local prev = game.event_feed_port
    game.event_feed_port = { publish = function(_, g, event)
      recorded[#recorded + 1] = event
      if prev and prev.publish then return prev:publish(g, event) end
      return true
    end }
    local start_turn = (game.turn and game.turn.turn_count) or 0
    local ticks = 0
    while ticks < %d do
      loop.tick(game, state, %s)
      ticks = ticks + 1
      local now = (game.turn and game.turn.turn_count) or start_turn
      if now > start_turn then break end
    end
    return lane.observe(game, recorded, %s)
  end)()]]):format(LANE_MODULE, HANDLE_MODULE, seed, max_ticks, tostring(dt), _to_lua(expect))
end

--- Drive one profile end-to-end and return the decoded observed table. The
--- caller must already be in play mode for the right profile (the lane manages
--- the play-mode lifecycle and profile pinning).
function M.observe_profile(client, expect, opts)
  local payload = client.game_exec_capture(M.drive_and_observe_source(expect, opts))
  if type(payload) ~= "table" then
    error("e2e profile_driver: expected a payload table, got " .. type(payload))
  end
  if payload.ok == false then
    error("e2e profile_driver: drive failed -- " .. tostring(payload.err))
  end
  return payload.value
end

return M
