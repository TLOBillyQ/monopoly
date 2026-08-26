local player_colors = {}

local default_color = 0xcfcfcf
local index_colors = {
  [1] = 0xe57373,
  [2] = 0xffeb3b,
  [3] = 0x4fc3f7,
  [4] = 0xba68c8,
}
local owner_colors = {}

function player_colors.set_owner_colors(colors_by_owner_id)
  if type(colors_by_owner_id) ~= "table" then
    return
  end
  owner_colors = {}
  for owner_id, color in pairs(colors_by_owner_id) do
    owner_colors[owner_id] = color
  end
end

local function _remap_color_for(player, index)
  if player and player.id ~= nil and index_colors[index] then
    return player.id, index_colors[index]
  end
  return nil
end

function player_colors.remap_by_index(players)
  if type(players) ~= "table" then
    return
  end
  owner_colors = {}
  for index, player in ipairs(players) do
    if index > 4 then break end
    local player_id, color = _remap_color_for(player, index)
    if player_id ~= nil then
      owner_colors[player_id] = color
    end
  end
end

function player_colors.resolve_owner_color(owner_id)
  return owner_colors[owner_id] or default_color
end

return player_colors

--[[ mutate4lua-manifest
version=4
projectHash=509f180907599540
scope.0.id=chunk:src/ui/view/player_colors.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=48
scope.0.semanticHash=34f9a3abf5f5b8a5
scope.1.id=function:player_colors.set_owner_colors
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=20
scope.1.semanticHash=863553266ddeb6c3
scope.2.id=function:_remap_color_for
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=27
scope.2.semanticHash=8f68e84d79c1edb6
scope.3.id=function:player_colors.remap_by_index
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=41
scope.3.semanticHash=057c54f10f699359
scope.4.id=function:player_colors.resolve_owner_color
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=45
scope.4.semanticHash=b04681464a9a8042
]]
