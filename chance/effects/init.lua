local effects = {}

function effects.register(registry)
  require("chance.effects.cash").register(registry)
  require("chance.effects.move").register(registry)
  require("chance.effects.item").register(registry)
  require("chance.effects.property").register(registry)
  require("chance.effects.vehicle").register(registry)
end

return effects
