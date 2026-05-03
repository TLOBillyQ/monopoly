local cash_handlers = {}

function cash_handlers.register(handlers, common)
  local deps = common.dependencies()
  local monopoly_event = deps.monopoly_event
  local number_utils = deps.number_utils

  local function _apply_to_all_players(game, fn)
    for _, p in ipairs(game.players) do
      if not p.eliminated then
        fn(p)
      end
    end
  end

  handlers.add_cash = function(game, player, card)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        local delta = common.adjust_chance_delta(game, p, card.amount)
        common.apply_cash_change(game, p, delta)
        common.emit_event(game, monopoly_event.chance.applied, {
          player = p,
          card = card,
          effect = card.effect,
          text = "💰 " .. p.name .. " 获得 " .. number_utils.format_integer_part(delta) .. " 金币",
        })
      end)
      return
    end

    local delta = common.adjust_chance_delta(game, player, card.amount)
    common.apply_cash_change(game, player, delta)
    common.emit_event(game, monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "💰 " .. player.name .. " 获得 " .. number_utils.format_integer_part(delta) .. " 金币",
    })
  end

  handlers.pay_cash = function(game, player, card)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        local delta = common.adjust_chance_delta(game, p, -card.amount)
        local reason = p.name .. " 支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
        common.apply_cash_and_maybe_bankrupt(game, p, delta, reason)
        common.emit_event(game, monopoly_event.chance.applied, {
          player = p,
          card = card,
          effect = card.effect,
          text = "💰 " .. p.name .. " 支付 " .. number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
        })
      end)
      return
    end

    local delta = common.adjust_chance_delta(game, player, -card.amount)
    local reason = player.name .. " 支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
    common.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
    common.emit_event(game, monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "💰 " .. player.name .. " 支付 " .. number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
    })
  end

  handlers.percent_pay_cash = function(game, player, card)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        local fee = math.floor(game:player_balance(p, "金币") * (card.percent / 100))
        local delta = common.adjust_chance_delta(game, p, -fee)
        local reason = p.name .. " 按比例支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
        common.apply_cash_and_maybe_bankrupt(game, p, delta, reason)
        common.emit_event(game, monopoly_event.chance.applied, {
          player = p,
          card = card,
          effect = card.effect,
          text = "💰 " .. p.name .. " 按比例支付 " .. number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
        })
      end)
      return
    end

    local fee = math.floor(game:player_balance(player, "金币") * (card.percent / 100))
    local delta = common.adjust_chance_delta(game, player, -fee)
    local reason = player.name .. " 按比例支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
    common.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
    common.emit_event(game, monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "💰 " .. player.name .. " 按比例支付 " .. number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
    })
  end

  handlers.pay_others = function(game, player, card)
    for _, other in ipairs(game.players) do
      if player.eliminated then
        break
      end
      if other.id ~= player.id and not other.eliminated then
        local fee = math.abs(common.adjust_chance_delta(game, player, -card.amount))
        if not game:player_is_in_mountain(other) then
          local reason = player.name .. " 向他人支付后破产"
          common.apply_cash_change(game, player, -fee, { suppress_cash_receive_anim = true })
          common.handle_bankruptcy_if_non_positive(game, player, reason)
          common.apply_cash_change(game, other, fee, { suppress_cash_receive_anim = true })
        end
      end
    end
    common.emit_event(game, monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "💰 " .. player.name .. " 向每位玩家支付 " .. number_utils.format_integer_part(card.amount),
    })
  end

  handlers.collect_from_others = function(game, player, card)
    local total_collected = 0
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = common.adjust_chance_delta(game, player, card.amount)
        if not game:player_is_in_mountain(player) then
          local other_cash = game:player_balance(other, "金币")
          if other_cash < fee then
            fee = other_cash
          end
          common.apply_cash_change(game, other, -fee, { suppress_cash_receive_anim = true })
          common.apply_cash_change(game, player, fee, { suppress_cash_receive_anim = true })
          total_collected = total_collected + fee
        end
      end
    end
    if total_collected > 0 then
      common.queue_action_anim(game, {
        kind = "cash_receive",
        player_id = player.id,
        amount = total_collected,
      })
    end
    common.emit_event(game, monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "💰 " .. player.name .. " 收取每位玩家 " .. number_utils.format_integer_part(card.amount),
    })
  end
end

return cash_handlers
