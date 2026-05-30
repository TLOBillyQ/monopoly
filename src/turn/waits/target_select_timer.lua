-- 道具目标选择阶段独立超时。借用 DeadlineService 的 target_select scope；
-- 进入 `_item_phase_ask_active=true` 后注册 deadline，到点调 deadlines.resolve_target_select。
local timing = require("src.config.gameplay.timing")
local deadlines = require("src.turn.deadlines")
local NumberUtils = require("src.foundation.number")

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
    if deadlines.is_active(state, "target_select") then
      deadlines.cancel(state, "target_select")
    end
    return
  end
  if not deadlines.is_active(state, "target_select") then
    deadlines.start(state, "target_select", {
      timeout_seconds = _resolve_target_select_timeout(),
      priority = 80,
      on_timeout = function()
        local choice = game and game.turn and game.turn.pending_choice or nil
        deadlines.resolve_target_select(game, state, { choice = choice }, "tick_timeout")
      end,
    })
  end
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=0ab2d1abc0248ec8
scope.0.id=chunk:src/turn/waits/target_select_timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=44
scope.0.semanticHash=eedfc7a475d6bf71
scope.1.id=function:_resolve_target_select_timeout:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=15
scope.1.semanticHash=9c28b74f40eb630b
scope.2.id=function:_is_target_select_active:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=b176e4529a7af3f6
scope.3.id=function:anonymous@35:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=38
scope.3.semanticHash=e0aec17cb655b65b
scope.4.id=function:M.step:21
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=41
scope.4.semanticHash=5fb80900fc35ffff
]]
