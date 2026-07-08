local angel_feedback = require("src.rules.items.angel_feedback")
local coin_settlement = require("src.rules.commerce.coin_settlement")

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
    coin_settlement.charge(game, target, common.abs_value(delta), { reason = reason })
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
    return math.floor(game:player_cash(target) * (card.percent / 100))
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
          coin_settlement.charge(game, player, fee, {
            reason = player.name .. " 向他人支付后破产",
            cash_opts = { suppress_cash_receive_anim = true },
          })
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
          local settled = coin_settlement.transfer(game, other, player, fee, {
            reason = other.name .. " 被收款资金不足破产",
            cash_opts = { suppress_cash_receive_anim = true },
          })
          total_collected = total_collected + settled.moved
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
projectHash=f9a5da9276f28de0
scope.0.id=chunk:src/rules/chance/cash_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=137
scope.0.semanticHash=0dd78cc9f7a837f7
scope.1.id=function:anonymous@19:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=28
scope.1.semanticHash=f18e213474a32a26
scope.2.id=function:anonymous@17:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=40
scope.2.semanticHash=f12db4f60c3f3e66
scope.3.id=function:_apply_payment:42
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=53
scope.3.semanticHash=effb291769d3b308
scope.4.id=function:anonymous@57:57
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=63
scope.4.semanticHash=745724e933b18a5e
scope.5.id=function:_dispatch_payment:55
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=67
scope.5.semanticHash=b8b611aabfb71c6f
scope.6.id=function:_fee_flat:69
scope.6.kind=function
scope.6.startLine=69
scope.6.endLine=69
scope.6.semanticHash=a95c7c89770a8336
scope.7.id=function:_fee_percent:70
scope.7.kind=function
scope.7.startLine=70
scope.7.endLine=72
scope.7.semanticHash=76f7a89991faf25d
scope.8.id=function:anonymous@74:74
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=76
scope.8.semanticHash=a010c205852f6a60
scope.9.id=function:anonymous@78:78
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=80
scope.9.semanticHash=c28ee76cc0bffb56
scope.10.id=function:anonymous@106:106
scope.10.kind=function
scope.10.startLine=106
scope.10.endLine=134
scope.10.semanticHash=9b82a730f3ae190b
]]
