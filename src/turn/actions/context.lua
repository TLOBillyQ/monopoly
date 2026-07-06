local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local item_slot_data = require("src.turn.actions.item_slot_data")
local output_state_adapter = require("src.turn.output.state_adapter")
local role_id_utils = require("src.foundation.identity")
local defaults = require("src.turn.actions.defaults")

local function resolve_dispatch_context(state, context)
  if context then
    return context
  end
  local output_ports = defaults.resolve_port_group(state, "output") or output_state_adapter
  local ui_sync_ports = defaults.resolve_port_group(state, "ui_sync") or defaults.default_ui_sync_ports
  local clock_ports = defaults.resolve_port_group(state, "clock") or defaults.default_clock_ports
  local ui_state = ui_sync_ports.get_ui_state and ui_sync_ports.get_ui_state(state) or nil
  local item_slot_source = item_slot_data.from_ui_state(ui_state)
  return {
    output_ports = output_ports,
    ui_sync_ports = ui_sync_ports,
    clock_ports = clock_ports,
    item_slot_source = item_slot_source,
  }
end

local function resolve_timestamp_now(dispatch_ctx)
  local clock_ports = dispatch_ctx and dispatch_ctx.clock_ports or nil
  if clock_ports and type(clock_ports.wall_now_seconds) == "function" then
    local ok, ts = pcall(clock_ports.wall_now_seconds)
    if ok and number_utils.is_numeric(ts) then
      return ts
    end
  end
  return 0
end

local function resolve_timestamp_diff_seconds(dispatch_ctx, timestamp_1, timestamp_2)
  local clock_ports = dispatch_ctx and dispatch_ctx.clock_ports or nil
  if clock_ports and type(clock_ports.wall_diff_seconds) == "function" then
    local ok, diff = pcall(clock_ports.wall_diff_seconds, timestamp_1, timestamp_2)
    if ok and number_utils.is_numeric(diff) then
      return diff
    end
  end
  if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
    return timestamp_1 - timestamp_2
  end
  return 0
end

local function resolve_actor_player(game, action)
  assert(game ~= nil and game.players ~= nil, "missing game.players")
  local actor_role_id = role_id_utils.normalize(action and action.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action and action.id))
    return nil
  end
  local player = game:find_player_by_id(actor_role_id)
  if not player then
    logger.warn("ui_button actor_role_id not mapped:", tostring(action and action.id), tostring(actor_role_id))
    return nil
  end
  return player
end

local function resolve_pending_choice(game, state, ctx)
  local turn_choice = game and game.turn and game.turn.pending_choice or nil
  if turn_choice ~= nil then
    return turn_choice
  end
  local output_ports = ctx and ctx.output_ports or nil
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
version=2
projectHash=40fd82b4f75e8094
scope.0.id=chunk:src/turn/actions/context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=84
scope.0.semanticHash=23a81f87333c9b64
scope.1.id=function:resolve_dispatch_context:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=23
scope.1.semanticHash=337377034f5bd1ba
scope.2.id=function:resolve_timestamp_now:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=34
scope.2.semanticHash=d7801dc789029f9c
scope.3.id=function:resolve_timestamp_diff_seconds:36
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=48
scope.3.semanticHash=b96119ba7475d364
scope.4.id=function:resolve_actor_player:50
scope.4.kind=function
scope.4.startLine=50
scope.4.endLine=63
scope.4.semanticHash=bd5e5bec3798f64e
scope.5.id=function:resolve_pending_choice:65
scope.5.kind=function
scope.5.startLine=65
scope.5.endLine=75
scope.5.semanticHash=37259071047e736b
]]
