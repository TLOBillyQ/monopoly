local choice_registry = require("src.game.systems.choices.ChoiceRegistry")
local chance_registry = require("src.game.systems.chance.ChanceRegistry")
local item_registry = require("src.game.systems.items.ItemRegistry")

local bootstrap = {}
local is_initialized = false

function bootstrap.ensure_defaults()
  if is_initialized then
    return
  end
  is_initialized = true
  item_registry.register_defaults()
  choice_registry.register_defaults(require("src.game.systems.choices.ChoiceResolver").helpers())
  chance_registry.register_defaults()
end

return bootstrap
