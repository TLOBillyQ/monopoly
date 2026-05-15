local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local item_slot_data = require("src.turn.actions.item_slot_data")
local output_state_adapter = require("src.turn.output.state_adapter")
local role_id_utils = require("src.foundation.identity")
local defaults = require("src.turn.actions.dispatch.defaults")

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

return {
  resolve_dispatch_context = resolve_dispatch_context,
  resolve_timestamp_now = resolve_timestamp_now,
  resolve_timestamp_diff_seconds = resolve_timestamp_diff_seconds,
  resolve_actor_player = resolve_actor_player,
}
