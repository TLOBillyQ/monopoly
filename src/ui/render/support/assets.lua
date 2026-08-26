local runtime = require("src.ui.render.support.runtime_ui")
local player_colors = require("src.ui.view.player_colors")
local ui_nodes = require("src.ui.render.support.node_ops")
local base_nodes = require("src.ui.schema.base")
local permanent_nodes = require("src.ui.schema.permanent")
local number_utils = require("src.foundation.number")
local runtime_assets = require("src.config.runtime_assets")

local M = {}

function M.init_ui_assets(state)
  assert(state ~= nil, "missing state")
  state.runtime_assets = runtime_assets
  state.runtime_asset_context = {}

  runtime.for_each_role_or_global(function()
    for index = 1, 5 do
      local icon = runtime_assets.startup_item_slot_icon(index)
      assert(icon.ok == true, "missing item icon: " .. tostring(icon.lookup_key))
      ui_nodes.set_item_slot_image(permanent_nodes.item_slots[index], icon.image_key)
    end
  end)
  runtime.set_client_role(nil)
end

local function _capture_base_panel_colors(colors_by_index)
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

local function _run_color_capture(capture_fn)
  if type(runtime.with_client_role) == "function" then
    runtime.with_client_role(nil, capture_fn)
  else
    runtime.set_client_role(nil)
    capture_fn()
  end
  runtime.set_client_role(nil)
end

local function _map_player_colors(players, colors_by_index)
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
  return owner_colors, mapped_count, unique_colors
end

local function _count_unique(unique_colors)
  local count = 0
  for _ in pairs(unique_colors) do
    count = count + 1
  end
  return count
end

local function _game_players(game)
  return game and game.players or nil
end

-- 命中「按 owner 设置」:至少映射到一个玩家,且唯一色可区分
-- (单个玩家或唯一色多于 1 种)。
local function _should_set_owner_colors(mapped_count, unique_colors)
  if mapped_count <= 0 then
    return false
  end
  return mapped_count == 1 or _count_unique(unique_colors) > 1
end

function M.capture_player_colors(state, game)
  assert(state ~= nil, "missing state")
  local players = _game_players(game)
  if type(players) ~= "table" then
    return
  end
  local colors_by_index = {}
  _run_color_capture(function() _capture_base_panel_colors(colors_by_index) end)
  local owner_colors, mapped_count, unique_colors = _map_player_colors(players, colors_by_index)
  if _should_set_owner_colors(mapped_count, unique_colors) then
    player_colors.set_owner_colors(owner_colors)
    return
  end
  player_colors.remap_by_index(players)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=09d6083770d9a40c
scope.0.id=chunk:src/ui/render/support/assets.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=103
scope.0.semanticHash=b1dc2f2a99c9429e
scope.1.id=function:M.init_ui_assets
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=24
scope.1.semanticHash=dcb953b86de0b992
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=22
scope.2.semanticHash=03e3e1081cb0678f
scope.3.id=function:_capture_base_panel_colors
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=37
scope.3.semanticHash=8158bfc58756e503
scope.4.id=function:_run_color_capture
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=47
scope.4.semanticHash=0e0a4125c87c32b5
scope.5.id=function:_map_player_colors
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=63
scope.5.semanticHash=f8c39b5c9268519a
scope.6.id=function:_count_unique
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=71
scope.6.semanticHash=7bb4d26e39a6d097
scope.7.id=function:_game_players
scope.7.kind=function
scope.7.startLine=73
scope.7.endLine=75
scope.7.semanticHash=616a2ca60599c94f
scope.8.id=function:_should_set_owner_colors
scope.8.kind=function
scope.8.startLine=79
scope.8.endLine=84
scope.8.semanticHash=80c4bf60fafabd1a
scope.9.id=function:M.capture_player_colors
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=100
scope.9.semanticHash=157dc953bd861ee1
scope.10.id=function:<anonymous>#2
scope.10.kind=function
scope.10.startLine=93
scope.10.endLine=93
scope.10.semanticHash=600a75ce96a391b3
]]
