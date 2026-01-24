local Tables = {}

function Tables.deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local res = {}
  for k, v in pairs(value) do
    res[k] = Tables.deep_copy(v)
  end
  return res
end

return Tables