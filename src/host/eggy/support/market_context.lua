local module_name = table.concat({ "src", "rules", "market", "query", "context" }, ".")

local proxy = {}

return setmetatable(proxy, {
  __index = function(_, key)
    return require(module_name)[key]
  end,
  __newindex = function(_, key, value)
    require(module_name)[key] = value
  end,
})
