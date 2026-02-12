local player_colors = {}

local default_color = 0xcfcfcf
local owner_colors = {
  [1] = 0x4fc3f7,
  [2] = 0x81c784,
  [3] = 0xffb74d,
  [4] = 0xe57373,
}

function player_colors.resolve_owner_color(owner_id)
  return owner_colors[owner_id] or default_color
end

return player_colors
