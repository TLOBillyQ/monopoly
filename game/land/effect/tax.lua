local inventory = require("game.item.inventory")
local choice_spec = require("game.land.choice_spec")
local action = require("game.land.action")
local logger = require("core.logger")
local gameplay_rules = require("cfg.GameplayRules")

local tax_effect = {}

local item_ids = gameplay_rules.item_ids

local function _can_tax(ctx)
  assert(ctx.tile ~= nil, "missing tile")
  return ctx.tile.type == "tax"
end

local function _apply_tax(ctx)
  local player = ctx.player

  if player.status.pending_tax_free then
    logger.event(player.name .. " 使用免税卡，本次免税")
    ctx.game:set_player_status(player, "pending_tax_free", false)
    return
  end

  local tax_idx = inventory.find_index(player, item_ids.tax_free)
  if tax_idx then
    return {
      waiting = true,
      reason = "tax_choice",
      intent = {
        kind = "need_choice",
        choice_spec = choice_spec.tax_prompt(player.id),
      },
    }
  end

  action.execute_pay_tax(ctx.game, player.id)
end

function tax_effect.executor()
  return { can_apply = _can_tax, apply = _apply_tax }
end

return tax_effect
