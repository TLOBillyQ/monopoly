local land_settlement = require("src.rules.land.settlement")
local landing_result = require("src.rules.choice_handlers.landing_result")

local M = {}

local function _build(helpers)
  local finish_choice = helpers.finish_choice

  local function _handle_landing_choice(game, choice, action)
    local result = land_settlement.resolve_landing_settlement_choice(game, choice, action)
    return landing_result.settle(finish_choice, game, result)
  end

  return {
    rent_card_prompt = {
      required_meta = { "player_id", "tile_id" },
      cancel = { mode = "select_option", option_id = "skip" },
      execute = _handle_landing_choice,
    },
    tax_card_prompt = {
      required_meta = { "player_id" },
      cancel = { mode = "select_option", option_id = "skip" },
      execute = _handle_landing_choice,
    },
  }
end

function M.register(registry, helpers)
  local handlers = _build(helpers)
  for kind, handler in pairs(handlers) do
    registry[kind] = handler
  end
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=68e857e1f41aa4c7
scope.0.id=chunk:src/rules/choice_handlers/land.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=36
scope.0.semanticHash=710dae4c417e2819
scope.1.id=function:_build
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=26
scope.1.semanticHash=8a1a270f7b6b5e87
scope.2.id=function:_handle_landing_choice
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=12
scope.2.semanticHash=71206cb0abf25ee1
scope.3.id=function:M.register
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=33
scope.3.semanticHash=eeb3a7c61f5feb12
]]
