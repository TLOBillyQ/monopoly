local providers = {}

local registry = {
  list = {},
}

function registry.register(provider)
  assert(type(provider) == "function", "missing provider")
  registry.list[#registry.list + 1] = provider
end

function registry.build_specs(state)
  local specs = {}
  for _, provider in ipairs(registry.list) do
    local result = provider(state) or {}
    for _, spec in ipairs(result) do
      specs[#specs + 1] = spec
    end
  end
  return specs
end

providers.registry = registry

return providers
