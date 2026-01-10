local random = {}

function random.weighted_choice(list, weight_key)
  weight_key = weight_key or "weight"
  local total = 0
  for _, item in ipairs(list) do
    total = total + (item[weight_key] or 0)
  end
  if total <= 0 then
    return list[1]
  end
  local pick = math.random() * total
  for _, item in ipairs(list) do
    pick = pick - (item[weight_key] or 0)
    if pick <= 0 then
      return item
    end
  end
  return list[#list]
end

return random
