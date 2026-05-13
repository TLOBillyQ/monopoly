local runtime = require("src.ui.render.runtime_ui")
local player_colors = require("src.ui.view.player_colors")
local ui_nodes = require("src.ui.render.node_ops")
local base_nodes = require("src.ui.schema.base")
local permanent_nodes = require("src.ui.schema.permanent")
local number_utils = require("src.foundation.lang.number")
local runtime_refs = require("src.config.content.runtime_refs")

local M = {}

function M.init_ui_assets(state)
  assert(state ~= nil, "missing state")
  local refs = runtime_refs
  local image_refs = refs.images or {}
  state.ui_refs = refs

  runtime.for_each_role_or_global(function()
    for index = 1, 5 do
      local ref_id = tostring(3000 + index)
      local image_key = image_refs[ref_id]
      assert(image_key ~= nil, "missing item icon: " .. tostring(ref_id))
      ui_nodes.set_item_slot_image(permanent_nodes.item_slots[index], image_key)
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
  local colors_by_index = {}
  local function capture_base_panel_colors()
    for index = 1, 4 do
      local node_name = string.format(base_nodes.player_color, index)
      local ok, node = pcall(runtime.query_node, node_name)
      if ok and node then
        local color = number_utils.to_integer(node.image_color)
        if color ~= nil then
          colors_by_index[index] = color
        end
      end
    end
  end

  if type(runtime.with_client_role) == "function" then
    runtime.with_client_role(nil, capture_base_panel_colors)
  else
    runtime.set_client_role(nil)
    capture_base_panel_colors()
  end
  runtime.set_client_role(nil)

  local owner_colors = {}
  local mapped_count = 0
  local unique_colors = {}
  for index = 1, 4 do
    local player = players[index]
    local color = colors_by_index[index]
    if player and player.id ~= nil and color ~= nil then
      owner_colors[player.id] = color
      mapped_count = mapped_count + 1
      unique_colors[color] = true
    end
  end

  local unique_count = 0
  for _ in pairs(unique_colors) do
    unique_count = unique_count + 1
  end

  if mapped_count > 0 and (mapped_count == 1 or unique_count > 1) then
    player_colors.set_owner_colors(owner_colors)
    return
  end

  player_colors.remap_by_index(players)
end

return M
