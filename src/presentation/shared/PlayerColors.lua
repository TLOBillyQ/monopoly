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
