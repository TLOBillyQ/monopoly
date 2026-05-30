local intent_output_port = require("src.rules.ports.intent_output")
local inventory = require("src.rules.items.inventory")
local timing = require("src.config.gameplay.timing")

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
    auto_close_seconds = timing.popup_dwell_default_seconds,
  })
  return true
end

return use_broadcast

--[[ mutate4lua-manifest
version=2
projectHash=ac55608095934fb8
scope.0.id=chunk:src/rules/items/use_broadcast.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=29
scope.0.semanticHash=cd6d4112bf3904d2
scope.1.id=function:use_broadcast.dispatch:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=26
scope.1.semanticHash=b7bee07c643d9308
]]
