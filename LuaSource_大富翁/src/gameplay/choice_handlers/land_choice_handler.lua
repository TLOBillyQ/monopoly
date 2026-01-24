local IntentDispatcher = require("src.util.intent_dispatcher")
local LandChoiceSpecs = require("src.gameplay.land_choice_specs")
local Inventory = require("src.gameplay.item_inventory")
local gameplay_constants = require("src.gameplay.constants")

local LandChoiceHandler = {}
local ITEM_IDS = gameplay_constants.item_ids

function LandChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice
  local LandActions = require("src.gameplay.land_actions")

  local function handle_rent_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id
    local tile_id = meta.tile_id
    local card_kind = meta.card_kind

    local use_card = (action and action.option_id == "use") and not is_cancel(action)

    if use_card and card_kind == "strong" then
      LandActions.execute_strong_card(game, player_id, tile_id)
    elseif use_card and card_kind == "free" then
      LandActions.execute_free_card(game, player_id, tile_id)
    else
      if card_kind == "strong" then
        local player = game.players[player_id]
        if Inventory.find_index(player, ITEM_IDS.free_rent) then
          IntentDispatcher.dispatch(game, {
            kind = "need_choice",
            choice_spec = LandChoiceSpecs.rent_prompt(player_id, tile_id, "free"),
          })
          return { stay = true }
        end
      end
      LandActions.execute_pay_rent(game, player_id, tile_id)
    end

    return finish_choice(game, false)
  end

  local function handle_tax_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id

    local use_card = (action and action.option_id == "use") and not is_cancel(action)

    if use_card then
      LandActions.execute_tax_free_card(game, player_id)
    else
      LandActions.execute_pay_tax(game, player_id)
    end

    return finish_choice(game, false)
  end

  return {
    rent_card_prompt = handle_rent_prompt,
    tax_card_prompt = handle_tax_prompt,
  }
end

return LandChoiceHandler
