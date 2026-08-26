local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local number_utils = require("src.foundation.number")

local dice_multiplier = {}

function dice_multiplier.apply_roll_total(game, raw_total, player)
  -- player_pending_dice_multiplier normalizes to >= 1, so multiplying is a
  -- no-op when no multiplier is pending.
  return raw_total * game:player_pending_dice_multiplier(player)
end

-- 守卫：倍数不加成时原样返回（未挂倍数 / 无原始步数 / 步数已被改动）。
local function _should_skip_multiplier(total, raw_total, pending_multiplier)
  return pending_multiplier <= 1 or raw_total == nil or total ~= raw_total
end

function dice_multiplier.apply_move_total(game, player, total, raw_total)
  local pending_multiplier = game:player_pending_dice_multiplier(player)
  if _should_skip_multiplier(total, raw_total, pending_multiplier) then
    return total
  end

  local new_total = raw_total * game:consume_pending_dice_multiplier(player)
  if game.last_turn then
    game.last_turn.total = new_total
  end
  event_feed.publish(game, {
    kind = event_kinds.item_used,
    text = player.name
      .. " 骰子加倍卡生效，步数 "
      .. number_utils.format_integer_part(raw_total)
      .. " → "
      .. number_utils.format_integer_part(new_total),
  })
  return new_total
end

return dice_multiplier

--[[ mutate4lua-manifest
version=4
projectHash=1d51ce67f3cdf178
scope.0.id=chunk:src/turn/phases/dice_multiplier.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=5b6bfa7494579f19
scope.1.id=function:dice_multiplier.apply_roll_total
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=11
scope.1.semanticHash=7b9c67e0abc95981
scope.2.id=function:_should_skip_multiplier
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=6c7202c4f8218e35
scope.3.id=function:dice_multiplier.apply_move_total
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=37
scope.3.semanticHash=67df69eaf0211fba
]]
