local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")
local inventory = require("src.game.systems.items.ItemInventory")
local gameplay_rules = require("src.core.config.GameplayRules")

local item_use_broadcast = {}

function item_use_broadcast.dispatch(game, player, item_id)
  if not (game and game.ui_port and player and item_id) then
    return false
  end
  intent_dispatcher.dispatch(game, {
    kind = "push_popup",
    payload = {
      title = "道具卡",
      body = player.name .. " 使用了 " .. inventory.item_name(item_id),
      kind = "item_card",
      image_ref = item_id,
      auto_close_seconds = gameplay_rules.action_anim_default_seconds,
    },
  })
  return true
end

return item_use_broadcast
