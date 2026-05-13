local normalize = require("src.rules.choice_handlers.item.normalize")
local completions = require("src.rules.choice_handlers.item.completions")

local M = {}

function M.build(helpers)
  local complete = completions.build(helpers)
  local use_item = helpers.use_item

  local function _handle(game, choice, action)
    local target_id = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = meta.item_id
    local result = use_item(game, player, item_id, {
      target_id = target_id,
      item_preconsumed = meta.item_preconsumed == true,
    })
    assert(result ~= nil, "missing use_item result")
    if result.waiting then
      return { stay = true }
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    item_target_player = completions.item_target_handler("item_target_player", _handle, complete),
  }
end

return M
