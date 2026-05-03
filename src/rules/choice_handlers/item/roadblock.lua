local intent_output_port = require("src.rules.ports.intent_output")
local item_use_broadcast = require("src.rules.items.use_broadcast")
local logger = require("src.foundation.log.logger")
local roadblock = require("src.rules.items.roadblock")
local normalize = require("src.rules.choice_handlers.item.normalize")
local completions = require("src.rules.choice_handlers.item.completions")

local M = {}

function M.build(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    if not roadblock.is_ui_candidate(game, player, index) then
      logger.warn(player.name .. " 选择了无效的路障位置: " .. tostring(index))
      return { stay = true }
    end
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = roadblock.apply(game, player, index)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
      intent_output_port.dispatch(game, result)
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    roadblock_target = {
      required_meta = { "player_id", "item_id" },
      cancel = {
        resolve = function(game, choice)
          return complete.followup_cancel(game, choice)
        end,
      },
      normalize_meta = normalize.target_picker_meta,
      meta_validator = normalize.validate_item_owner_meta,
      normalize_action = function(_, _, action)
        return normalize.choice_action_option_id("roadblock_target", action)
      end,
      execute = _handle,
    },
  }
end

return M
