local IntentDispatcher = require("src.util.intent_dispatcher")

local LandChoiceHandler = {}

function LandChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice

  local function handle_rent_prompt(game, choice, action)
    local LandEffect = require("src.gameplay.land")
    local meta = choice.meta or {}
    local player_id = meta.player_id
    local tile_id = meta.tile_id
    local card_kind = meta.card_kind

    local use_card = (action and action.option_id == "use") and not is_cancel(action)

    if use_card and card_kind == "strong" then
      -- 使用强征卡
      LandEffect.execute_strong_card(game, player_id, tile_id)
    elseif use_card and card_kind == "free" then
      -- 使用免费卡（免租）
      LandEffect.execute_free_card(game, player_id, tile_id)
    else
      if card_kind == "strong" then
        local player = player_id and game.players[player_id] or nil
        local free_idx = player and player.inventory and player.inventory:find_index(function(it) return it.id == 2001 end)
        if free_idx then
          IntentDispatcher.dispatch(game, {
            kind = "need_choice",
            choice_spec = {
              kind = "rent_card_prompt",
              title = "是否使用免费卡",
              body_lines = { "免除本次租金" },
              options = {
                { id = "use", label = "使用" },
                { id = "skip", label = "放弃" },
              },
              allow_cancel = false,
              meta = { player_id = player_id, tile_id = tile_id, card_kind = "free" },
            },
          })
          return { stay = true }
        end
      end
      -- 跳过当前卡 → 直接支付租金
      LandEffect.execute_pay_rent(game, player_id, tile_id)
    end

    return finish_choice(game, false)
  end

  local function handle_tax_prompt(game, choice, action)
    local LandEffect = require("src.gameplay.land")
    local meta = choice.meta or {}
    local player_id = meta.player_id

    local use_card = (action and action.option_id == "use") and not is_cancel(action)

    if use_card then
      -- 使用免税卡
      LandEffect.execute_tax_free_card(game, player_id)
    else
      -- 跳过 → 直接支付税金
      LandEffect.execute_pay_tax(game, player_id)
    end

    return finish_choice(game, false)
  end

  return {
    rent_card_prompt = handle_rent_prompt,
    tax_card_prompt = handle_tax_prompt,
  }
end

return LandChoiceHandler
