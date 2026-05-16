local shared = {}

function shared.ensure_player(world)
  if not world.player then
    world.player = { cash = 0, tiles = {}, items = {}, deities = {} }
  end
  return world.player
end

function shared.parse_number_list(text)
  local values = {}
  for v in tostring(text):gmatch("[^,]+") do
    values[#values + 1] = tonumber(v)
  end
  return values
end

return shared
