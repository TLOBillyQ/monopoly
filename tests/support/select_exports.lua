local function pick(source, keys)
  local out = {}
  for _, key in ipairs(keys or {}) do
    out[key] = source[key]
  end
  return out
end

return pick
