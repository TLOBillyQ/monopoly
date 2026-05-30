local player_colors = {}

local default_color = 0xcfcfcf
local index_colors = {
  [1] = 0xe57373,
  [2] = 0xffeb3b,
  [3] = 0x4fc3f7,
  [4] = 0xba68c8,
}
local owner_colors = {
  [1] = 0xe57373,
  [2] = 0xffeb3b,
  [3] = 0x4fc3f7,
  [4] = 0xba68c8,
}

function player_colors.set_owner_colors(colors_by_owner_id)
  if type(colors_by_owner_id) ~= "table" then
    return
  end
  owner_colors = {}
  for owner_id, color in pairs(colors_by_owner_id) do
    owner_colors[owner_id] = color
  end
end

function player_colors.remap_by_index(players)
  if type(players) ~= "table" then
    return
  end
  owner_colors = {}
  for index, player in ipairs(players) do
    if index > 4 then break end
    if player and player.id ~= nil and index_colors[index] then
      owner_colors[player.id] = index_colors[index]
    end
  end
end

function player_colors.resolve_owner_color(owner_id)
  return owner_colors[owner_id] or default_color
end

return player_colors

--[[ mutate4lua-manifest
version=2
projectHash=afd01a3ce20b20d0
scope.0.id=chunk:src/ui/view/player_colors.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=45
scope.0.semanticHash=1f1e013f18d0c2cd
scope.1.id=function:player_colors.resolve_owner_color:40
scope.1.kind=function
scope.1.startLine=40
scope.1.endLine=42
scope.1.semanticHash=e97c80bef0a2c1bd
]]
