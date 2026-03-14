local intent_output_port = require("src.rules.ports.intent_output_port")
local inventory = require("src.rules.items.inventory")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")

local use_broadcast = {}

function use_broadcast.dispatch(game, player, item_id)
  if not (game and player and item_id) then
    return false
  end
  local popup_port = game.popup_port
  if popup_port == nil and type(game.ensure_popup_port) == "function" then
    popup_port = game:ensure_popup_port()
  end
  if popup_port == nil then
    return false
  end
  intent_output_port.push_popup(game, {
    title = "道具卡",
    body = player.name .. " 使用了 " .. inventory.item_name(item_id),
    kind = "item_card",
    image_ref = item_id,
    auto_close_seconds = gameplay_rules.action_anim_default_seconds,
  })
  return true
end

return use_broadcast
