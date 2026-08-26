local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local output_state_adapter = require("src.turn.output.state_adapter")
local role_id_utils = require("src.foundation.identity")
local defaults = require("src.turn.actions.defaults")

local function _resolve_ports(state, group, fallback)
  return defaults.resolve_port_group(state, group) or fallback
end

-- 槽位 → 道具的解析不再经 UI 镜像（item_slot_click 直读行动者背包），
-- 因此 dispatch context 不再携带 item_slot_source。
local function resolve_dispatch_context(state, context)
  if context then
    return context
  end
  return {
    output_ports = _resolve_ports(state, "output", output_state_adapter),
    ui_sync_ports = _resolve_ports(state, "ui_sync", defaults.default_ui_sync_ports),
    clock_ports = _resolve_ports(state, "clock", defaults.default_clock_ports),
  }
end

local function _clock_ports(dispatch_ctx)
  return dispatch_ctx and dispatch_ctx.clock_ports or nil
end

local function _safe_wall_now(wall_now_seconds)
  local ok, ts = pcall(wall_now_seconds)
  if ok and number_utils.is_numeric(ts) then
    return ts
  end
  return nil
end

local function _clock_wall_now(clock_ports)
  if clock_ports and type(clock_ports.wall_now_seconds) == "function" then
    return _safe_wall_now(clock_ports.wall_now_seconds)
  end
  return nil
end

local function resolve_timestamp_now(dispatch_ctx)
  return _clock_wall_now(_clock_ports(dispatch_ctx)) or 0
end

local function _wall_diff(clock_ports, timestamp_1, timestamp_2)
  if clock_ports and type(clock_ports.wall_diff_seconds) == "function" then
    local ok, diff = pcall(clock_ports.wall_diff_seconds, timestamp_1, timestamp_2)
    if ok and number_utils.is_numeric(diff) then
      return diff
    end
  end
  return nil
end

local function _numeric_diff(timestamp_1, timestamp_2)
  if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
    return timestamp_1 - timestamp_2
  end
  return nil
end

local function resolve_timestamp_diff_seconds(dispatch_ctx, timestamp_1, timestamp_2)
  return _wall_diff(_clock_ports(dispatch_ctx), timestamp_1, timestamp_2) or _numeric_diff(timestamp_1, timestamp_2) or 0
end

local function _action_id(action)
  return action and action.id or nil
end

local function _action_actor_role_id(action)
  return action and action.actor_role_id or nil
end

local function resolve_actor_player(game, action)
  assert(game ~= nil and game.players ~= nil, "missing game.players")
  local actor_role_id = role_id_utils.normalize(_action_actor_role_id(action))
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(_action_id(action)))
    return nil
  end
  local player = game:find_player_by_id(actor_role_id)
  if not player then
    logger.warn("ui_button actor_role_id not mapped:", tostring(_action_id(action)), tostring(actor_role_id))
    return nil
  end
  return player
end

local function _turn_pending_choice(game)
  return game and game.turn and game.turn.pending_choice or nil
end

local function _output_ports(ctx)
  return ctx and ctx.output_ports or nil
end

local function resolve_pending_choice(game, state, ctx)
  local turn_choice = _turn_pending_choice(game)
  if turn_choice ~= nil then
    return turn_choice
  end
  local output_ports = _output_ports(ctx)
  if output_ports and type(output_ports.get_pending_choice) == "function" then
    return output_ports.get_pending_choice(state)
  end
  return nil
end

return {
  resolve_dispatch_context = resolve_dispatch_context,
  resolve_timestamp_now = resolve_timestamp_now,
  resolve_timestamp_diff_seconds = resolve_timestamp_diff_seconds,
  resolve_actor_player = resolve_actor_player,
  resolve_pending_choice = resolve_pending_choice,
}

--[[ mutate4lua-manifest
version=4
projectHash=e68ee182bf6fabf8
scope.0.id=chunk:src/turn/actions/context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=d10be1a782dceab3
scope.1.id=function:_resolve_ports
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=21d9b02f421567dd
scope.2.id=function:resolve_dispatch_context
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=22
scope.2.semanticHash=7c8af2793304124f
scope.3.id=function:resolve_timestamp_now
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=33
scope.3.semanticHash=8e1434c3f931f6ec
scope.4.id=function:resolve_timestamp_diff_seconds
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=47
scope.4.semanticHash=37ed74c009b24783
scope.5.id=function:_action_id
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=51
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:_action_actor_role_id
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=55
scope.6.semanticHash=616a2ca60599c94f
scope.7.id=function:resolve_actor_player
scope.7.kind=function
scope.7.startLine=57
scope.7.endLine=70
scope.7.semanticHash=6434f60865215847
scope.8.id=function:resolve_pending_choice
scope.8.kind=function
scope.8.startLine=72
scope.8.endLine=82
scope.8.semanticHash=1c4d7b8ad2c9dc7e
]]
