local item_use_broadcast = require("src.rules.items.use_broadcast")
local remote_dice = require("src.rules.items.remote_dice")
local normalize = require("src.rules.choice_handlers.item.normalize")
local completions = require("src.rules.choice_handlers.item.completions")

local M = {}

function M.build(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local value = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local dice_count = meta.dice_count or game:player_dice_count(player)
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = remote_dice.apply(game, player, dice_count, value)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    remote_dice_value = completions.item_target_handler("remote_dice_value", _handle, complete, {
      normalize_meta = normalize.remote_dice_meta,
      meta_validator = normalize.validate_remote_dice_meta,
    }),
  }
end

return M
