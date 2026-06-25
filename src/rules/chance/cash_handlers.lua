local angel_feedback = require("src.rules.items.angel_feedback")

local cash_handlers = {}

function cash_handlers.register(handlers, common)
  local deps = common.dependencies()

  local function _apply_to_all_players(game, fn)
    for _, p in ipairs(game.players) do
      if not p.eliminated then
        fn(p)
      end
    end
  end

  local function _record_cash_received(game, player, amount)
    if type(common.record_cash_received) == "function" then
      common.record_cash_received(game, player, amount)
    end
  end

  local function _transfer_cash_capped(game, payer, receiver, amount, opts)
    if type(game.transfer_player_cash) == "function" then
      local payer_after, receiver_after, moved = game:transfer_player_cash(payer, receiver, amount, opts)
      return payer_after, receiver_after, moved, true
    end
    local liquid = math.min(game:player_balance(payer, "金币"), amount)
    common.apply_cash_change(game, payer, -amount, opts)
    common.apply_cash_change(game, receiver, liquid, opts)
    return game:player_balance(payer, "金币"), game:player_balance(receiver, "金币"), liquid, false
  end

  handlers.add_cash = function(game, player, card)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        local delta = common.adjust_chance_delta(game, p, card.amount)
        common.apply_cash_change(game, p, delta)
        common.emit_event(game, deps.monopoly_event.chance.applied, {
          player = p,
          card = card,
          effect = card.effect,
          text = "￥ " .. p.name .. " 获得 " .. deps.number_utils.format_integer_part(delta) .. " 金币",
        })
      end)
      return
    end

    local delta = common.adjust_chance_delta(game, player, card.amount)
    common.apply_cash_change(game, player, delta)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 获得 " .. deps.number_utils.format_integer_part(delta) .. " 金币",
    })
  end

  local function _apply_payment(game, target, card, compute_fee, reason_label, text_label)
    local fee = compute_fee(game, target, card)
    local delta = common.adjust_chance_delta(game, target, -fee)
    local reason = target.name .. " " .. reason_label .. " " .. common.abs_value(delta) .. " 后破产"
    common.apply_cash_and_maybe_bankrupt(game, target, delta, reason)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = target,
      card = card,
      effect = card.effect,
      text = "￥ " .. target.name .. " " .. text_label .. " " .. deps.number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
    })
  end

  local function _dispatch_payment(game, player, card, compute_fee, reason_label, text_label)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        if card.negative and game:player_has_angel(p) then
          angel_feedback.publish(game, p, "机会卡扣费")
          return
        end
        _apply_payment(game, p, card, compute_fee, reason_label, text_label)
      end)
      return
    end
    _apply_payment(game, player, card, compute_fee, reason_label, text_label)
  end

  local function _fee_flat(_, _, card) return card.amount end
  local function _fee_percent(game, target, card)
    return math.floor(game:player_balance(target, "金币") * (card.percent / 100))
  end

  handlers.pay_cash = function(game, player, card)
    _dispatch_payment(game, player, card, _fee_flat, "支付机会卡费用", "支付")
  end

  handlers.percent_pay_cash = function(game, player, card)
    _dispatch_payment(game, player, card, _fee_percent, "按比例支付机会卡费用", "按比例支付")
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
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 向每位玩家支付 " .. deps.number_utils.format_integer_part(card.amount),
    })
  end

  handlers.collect_from_others = function(game, player, card)
    local total_collected = 0
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = common.adjust_chance_delta(game, player, card.amount)
        if not game:player_is_in_mountain(player) then
          local _, _, liquid, used_settlement = _transfer_cash_capped(
            game,
            other,
            player,
            fee,
            { suppress_cash_receive_anim = true, allow_partial = true }
          )
          if used_settlement then
            _record_cash_received(game, player, liquid)
          end
          total_collected = total_collected + liquid
          local reason = other.name .. " 被收款资金不足破产"
          common.handle_bankruptcy_if_non_positive(game, other, reason)
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
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 收取每位玩家 " .. deps.number_utils.format_integer_part(card.amount),
    })
  end
end

return cash_handlers

--[[ mutate4lua-manifest
version=2
projectHash=f7debb99bfd04988
scope.0.id=chunk:src/rules/chance/cash_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=160
scope.0.semanticHash=916514566b2323ce
scope.1.id=function:_record_cash_received:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=20
scope.1.semanticHash=e4af983bec64ce6e
scope.2.id=function:_transfer_cash_capped:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=31
scope.2.semanticHash=864fc069589a009e
scope.3.id=function:anonymous@35:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=44
scope.3.semanticHash=f18e213474a32a26
scope.4.id=function:anonymous@33:33
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=56
scope.4.semanticHash=f12db4f60c3f3e66
scope.5.id=function:_apply_payment:58
scope.5.kind=function
scope.5.startLine=58
scope.5.endLine=69
scope.5.semanticHash=1f9cd53d983d4b6a
scope.6.id=function:anonymous@73:73
scope.6.kind=function
scope.6.startLine=73
scope.6.endLine=79
scope.6.semanticHash=745724e933b18a5e
scope.7.id=function:_dispatch_payment:71
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=83
scope.7.semanticHash=b8b611aabfb71c6f
scope.8.id=function:_fee_flat:85
scope.8.kind=function
scope.8.startLine=85
scope.8.endLine=85
scope.8.semanticHash=a95c7c89770a8336
scope.9.id=function:_fee_percent:86
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=88
scope.9.semanticHash=f4806f818e79518d
scope.10.id=function:anonymous@90:90
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=92
scope.10.semanticHash=a010c205852f6a60
scope.11.id=function:anonymous@94:94
scope.11.kind=function
scope.11.startLine=94
scope.11.endLine=96
scope.11.semanticHash=c28ee76cc0bffb56
scope.12.id=function:anonymous@121:121
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=157
scope.12.semanticHash=09e3cbc1903e75d1
]]
