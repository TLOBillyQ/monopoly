local tablex = {}

function tablex.shallow_copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

function tablex.clone_array(list)
  local out = {}
  for i, v in ipairs(list) do
    out[i] = v
  end
  return out
end

function tablex.remove_first(list, predicate)
  for i, v in ipairs(list) do
    if predicate(v) then
      table.remove(list, i)
      return v
    end
  end
  return nil
end

return tablex
