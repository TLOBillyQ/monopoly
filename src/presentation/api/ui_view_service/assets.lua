local runtime = require("src.presentation.api.UIRuntimePort")
local player_colors = require("src.presentation.shared.PlayerColors")
local ui_nodes = require("src.presentation.shared.UINodes")
local core = require("src.presentation.api.ui_view_service.core")

local M = {}

function M.init_ui_assets(state)
  assert(state ~= nil, "missing state")
  local refs = require("Config.RuntimeRefs")
  state.ui_refs = refs

  runtime.for_each_role_or_global(function()
    for index = 1, 5 do
      local ref_id = tostring(3000 + index)
      local image_key = refs[ref_id]
      assert(image_key ~= nil, "missing item icon: " .. tostring(ref_id))
      core.set_item_slot_image("基础_道具槽位" .. tostring(index), image_key)
    end
  end)
  runtime.set_client_role(nil)
end

function M.capture_player_colors(state, game)
  assert(state ~= nil, "missing state")
  local players = game and game.players or nil
  if type(players) ~= "table" then
    return
  end
  local colors_by_owner = {}
  for index, player in ipairs(players) do
    if index > 4 then
      break
    end
    if player and player.id ~= nil then
      local node = runtime.query_node(string.format(ui_nodes.base.player_color, index))
      local color = node and node.image_color or nil
      if color ~= nil then
        colors_by_owner[player.id] = color
      end
    end
  end
  player_colors.set_owner_colors(colors_by_owner)
end

return M
