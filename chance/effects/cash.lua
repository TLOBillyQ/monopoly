local utils = require("chance.utils")

local cash_effects = {}

function cash_effects.register(registry)
  registry:register("add_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = utils.adjust_chance_delta(game, p, card.amount)
          utils.apply_cash_change(game, p, delta)
          utils.emit_event(utils.monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 获得 " .. utils.number_utils.format_integer_part(delta) .. " 金币",
          })
        end
      end
    else
      local delta = utils.adjust_chance_delta(game, player, card.amount)
      utils.apply_cash_change(game, player, delta)
      utils.emit_event(utils.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 获得 " .. utils.number_utils.format_integer_part(delta) .. " 金币",
      })
    end
  end)

  registry:register("pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = utils.adjust_chance_delta(game, p, -card.amount)
          local reason = p.name .. " 支付机会卡费用 " .. utils.abs_value(delta) .. " 后破产"
          utils.apply_cash_and_maybe_bankrupt(game, p, delta, reason)
          utils.emit_event(utils.monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 支付 " .. utils.number_utils.format_integer_part(utils.abs_value(delta)) .. " 金币",
          })
        end
      end
    else
      local delta = utils.adjust_chance_delta(game, player, -card.amount)
      local reason = player.name .. " 支付机会卡费用 " .. utils.abs_value(delta) .. " 后破产"
      utils.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
      utils.emit_event(utils.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 支付 " .. utils.number_utils.format_integer_part(utils.abs_value(delta)) .. " 金币",
      })
    end
  end)

  registry:register("percent_pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local fee = math.floor(game:player_balance(p, "金币") * (card.percent / 100))
          local delta = utils.adjust_chance_delta(game, p, -fee)
          local reason = p.name .. " 按比例支付机会卡费用 " .. utils.abs_value(delta) .. " 后破产"
          utils.apply_cash_and_maybe_bankrupt(game, p, delta, reason)
          utils.emit_event(utils.monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 按比例支付 " .. utils.number_utils.format_integer_part(utils.abs_value(delta)) .. " 金币",
          })
        end
      end
    else
      local fee = math.floor(game:player_balance(player, "金币") * (card.percent / 100))
      local delta = utils.adjust_chance_delta(game, player, -fee)
      local reason = player.name .. " 按比例支付机会卡费用 " .. utils.abs_value(delta) .. " 后破产"
      utils.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
      utils.emit_event(utils.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 按比例支付 " .. utils.number_utils.format_integer_part(utils.abs_value(delta)) .. " 金币",
      })
    end
  end)

  registry:register("pay_others", function(game, player, card)
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if game:player_has_deity(player, "poor") then
          fee = fee * 2
        end
        if not game:player_is_in_mountain(other) then
          local reason = player.name .. " 向他人支付后破产"
          utils.apply_cash_and_maybe_bankrupt(game, player, -fee, reason)
          utils.apply_cash_change(game, other, fee)
        end
      end
    end
    utils.emit_event(utils.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 向每位玩家支付 " .. utils.number_utils.format_integer_part(card.amount),
    })
  end)

  registry:register("collect_from_others", function(game, player, card)
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if game:player_has_deity(player, "rich") then
          fee = fee * 2
        end
        if not game:player_is_in_mountain(player) then
          local other_cash = game:player_balance(other, "金币")
          if other_cash < fee then
            fee = other_cash
          end
          utils.apply_cash_change(game, other, -fee)
          utils.apply_cash_change(game, player, fee)
        end
      end
    end
    utils.emit_event(utils.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 收取每位玩家 " .. utils.number_utils.format_integer_part(card.amount),
    })
  end)
end

return cash_effects
