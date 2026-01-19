local random = {}

function random.weighted_choice(list, weight_key, rng)
  weight_key = weight_key or "weight"
  local total = 0
  for _, item in ipairs(list) do
    total = total + (item[weight_key] or 0)
  end
  if total <= 0 then
    return list[1]
  end
  local pick
  if rng and rng.next_float then
    pick = rng:next_float() * total
  else
    pick = math.random() * total
  end
  for _, item in ipairs(list) do
    pick = pick - (item[weight_key] or 0)
    if pick <= 0 then
      return item
    end
  end
  return list[#list]
end

return random