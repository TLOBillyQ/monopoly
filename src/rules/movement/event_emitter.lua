local constants = require("src.config.content.constants")
local monopoly_event = require("src.core.events.monopoly_events")
local number_utils = require("src.core.utils.number_utils")

local event_emitter = {}
local _emit_event = monopoly_event.emit

local function _build_other_action_prompt_text()
  return "玩家正在行动"
end

local function _tile_label(tile)
  return tile.name
end

local function _emit_move_events(ctx, landing_tile)
  _emit_event(monopoly_event.movement.moved, {
    player = ctx.player,
    from_tile = ctx.start_tile,
    to_tile = landing_tile,
    steps = ctx.steps,
    text = ctx.player.name .. " 从 " .. _tile_label(ctx.start_tile) .. " 移动到 " .. _tile_label(landing_tile),
    prompt_text = _build_other_action_prompt_text(),
  })
  if ctx.pass_start <= 0 then
    return
  end
  local bonus = ctx.pass_start * constants.pass_start_bonus
  ctx.game:add_player_cash(ctx.player, bonus)
  _emit_event(monopoly_event.movement.passed_start, {
    player = ctx.player,
    count = ctx.pass_start,
    bonus = bonus,
    text = ctx.player.name .. " 经过起点，获得 " .. number_utils.format_integer_part(bonus) .. " 金币",
    prompt_text = _build_other_action_prompt_text(),
  })
end

event_emitter.emit = _emit_move_events

return event_emitter
