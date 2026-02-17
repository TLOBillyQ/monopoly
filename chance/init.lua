local registry = require("chance.registry")
local resolver = require("chance.resolver")

local chance = {
  registry = registry,
  resolve = resolver.resolve,
}

return chance
