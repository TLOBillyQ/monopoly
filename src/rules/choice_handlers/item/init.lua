local M = {}

local handler_module_paths = {
  "src.rules.choice_handlers.item.phase",
  "src.rules.choice_handlers.item.demolish",
  "src.rules.choice_handlers.item.roadblock",
  "src.rules.choice_handlers.item.target_player",
  "src.rules.choice_handlers.item.remote_dice",
}

function M.register(registry, helpers)
  for _, modname in ipairs(handler_module_paths) do
    local builder = require(modname)
    local handlers = builder.build(helpers)
    for kind, handler in pairs(handlers) do
      registry[kind] = handler
    end
  end
end

return M
