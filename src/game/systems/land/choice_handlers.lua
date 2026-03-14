local land_choice_specs = require("src.game.systems.land.choice_specs")
local inventory = require("src.game.systems.items.inventory")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local intent_output_port = require("src.game.ports.intent_output_port")

local land_choice_handler = {}
local item_ids = gameplay_rules.item_ids

function land_choice_handler.build(helpers)
  local finish_choice = helpers.finish_choice
  local land_actions = require("src.game.systems.land.actions")

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
          intent_output_port.open_choice(game, land_choice_specs.rent_prompt(player_id, tile_id, "free"))
          return { stay = true }
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

return land_choice_handler
