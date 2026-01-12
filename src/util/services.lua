local Services = {}

function Services.get(game, key)
  return game and game.services and game.services[key]
end

function Services.status(game)
  return Services.get(game, "status")
end

function Services.bankruptcy(game)
  return Services.get(game, "bankruptcy")
end

function Services.movement(game)
  return Services.get(game, "movement")
end

function Services.item(game)
  return Services.get(game, "item")
end

function Services.market(game)
  return Services.get(game, "market")
end

function Services.tile(game)
  return Services.get(game, "tile")
end

function Services.chance(game)
  return Services.get(game, "chance")
end

return Services
