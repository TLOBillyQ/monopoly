-- 道具目标选择阶段独立超时。借用 DeadlineService 的 target_select scope；
-- 进入 `_item_phase_ask_active=true` 后注册 deadline，到点调 force_resolve.resolve_target_select。
local timing = require("src.config.gameplay.timing")
local DeadlineService = require("src.turn.deadlines.service")
local NumberUtils = require("src.foundation.lang.number")

local M = {}

local function _resolve_target_select_timeout()
  local timeouts = timing.scope_timeouts
  if type(timeouts) == "table" and NumberUtils.is_numeric(timeouts.target_select) and timeouts.target_select > 0 then
    return timeouts.target_select
  end
  return 15
end

local function _is_target_select_active(state)
  return type(state) == "table" and state._item_phase_ask_active == true
end

function M.step(game, state, dt)
  if type(state) ~= "table" then
    return
  end
  if not _is_target_select_active(state) then
    if DeadlineService.is_active(state, "target_select") then
      DeadlineService.cancel(state, "target_select")
    end
    return
  end
  if not DeadlineService.is_active(state, "target_select") then
    DeadlineService.start(state, "target_select", {
      timeout_seconds = _resolve_target_select_timeout(),
      priority = 80,
      on_timeout = function()
        local force_resolve = require("src.turn.deadlines.force_resolve")
        local choice = game and game.turn and game.turn.pending_choice or nil
        force_resolve.resolve_target_select(game, state, { choice = choice }, "tick_timeout")
      end,
    })
  end
end

return M
