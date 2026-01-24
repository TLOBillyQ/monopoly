local Convert = {}

function Convert.to_number(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    return tonumber(v)
  end
  return nil
end

return Convert