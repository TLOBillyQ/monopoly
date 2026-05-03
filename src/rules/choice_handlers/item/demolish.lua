local demolish = require("src.rules.items.demolish")
local intent_output_port = require("src.rules.ports.intent_output")
local item_use_broadcast = require("src.rules.items.use_broadcast")
local normalize = require("src.rules.choice_handlers.item.normalize")
local completions = require("src.rules.choice_handlers.item.completions")

local M = {}

function M.build(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = demolish.apply(game, player, index, {
      injure = meta.injure,
      title = meta.title,
      item_id = meta.item_id,
    })
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    local intent = result.intent or {}
    intent_output_port.dispatch(game, intent)
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    demolish_target = {
      required_meta = { "player_id", "item_id" },
      cancel = {
        resolve = function(game, choice)
          return complete.followup_cancel(game, choice)
        end,
      },
      normalize_meta = normalize.item_target_meta,
      meta_validator = normalize.validate_item_owner_meta,
      normalize_action = function(_, _, action)
        return normalize.choice_action_option_id("demolish_target", action)
      end,
      execute = _handle,
    },
  }
end

return M
