local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local land_actions = require("src.rules.land.actions")

local M = {}

local function _build(helpers)
  local finish_choice = helpers.finish_choice

  local function _handle_rent_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id
    local tile_id = meta.tile_id
    local card_kind = meta.card_kind
    local use_card = action.option_id == "use"

    if use_card and card_kind == "strong" then
      land_actions.execute_strong_card(game, player_id, tile_id)
    elseif use_card and card_kind == "free" then
      land_actions.execute_free_card(game, player_id, tile_id)
    else
      if card_kind == "strong" then
        local player = assert(game:find_player_by_id(player_id), "missing player: " .. tostring(player_id))
        if inventory.find_index(player, item_ids.free_rent) then
          land_actions.execute_free_card(game, player_id, tile_id)
          return finish_choice(game, false)
        end
      end
      land_actions.execute_pay_rent(game, player_id, tile_id)
    end

    return finish_choice(game, false)
  end

  local function _handle_tax_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id
    local use_card = action.option_id == "use"

    if use_card then
      land_actions.execute_tax_free_card(game, player_id)
    else
      land_actions.execute_pay_tax(game, player_id)
    end

    return finish_choice(game, false)
  end

  return {
    rent_card_prompt = {
      required_meta = { "player_id", "tile_id" },
      cancel = { mode = "select_option", option_id = "skip" },
      execute = _handle_rent_prompt,
    },
    tax_card_prompt = {
      required_meta = { "player_id" },
      cancel = { mode = "select_option", option_id = "skip" },
      execute = _handle_tax_prompt,
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
