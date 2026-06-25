local land_settlement = require("src.rules.land.settlement")

local M = {}

local function _build(helpers)
  local finish_choice = helpers.finish_choice

  local function _finish_landing_choice(game, result)
    if result and result.stay then
      return result
    end
    return finish_choice(game, false)
  end

  local function _handle_landing_choice(game, choice, action)
    return _finish_landing_choice(game, land_settlement.resolve_landing_settlement_choice(game, choice, action))
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
version=2
projectHash=560caedf8d16cbb7
scope.0.id=chunk:src/rules/choice_handlers/land.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=71
scope.0.semanticHash=97727233a10f429b
scope.1.id=function:_handle_rent_prompt:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=33
scope.1.semanticHash=11974675365b7d42
scope.2.id=function:_handle_tax_prompt:35
scope.2.kind=function
scope.2.startLine=35
scope.2.endLine=47
scope.2.semanticHash=6d1b746dcf21d89e
scope.3.id=function:_build:7
scope.3.kind=function
scope.3.startLine=7
scope.3.endLine=61
scope.3.semanticHash=2b526bc0ce9c46fa
]]
