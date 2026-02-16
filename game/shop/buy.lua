local entry = require("game.shop.entry")
local validate = require("game.shop.validate")
local inventory = require("game.item.inventory")
local agent = require("game.rule.agent")
local choice_spec = require("game.land.choice_spec")
local game_event = require("game.event")
local paid_currency_bridge = require("game.commerce.paid_bridge")
local logger = require("core.logger")

local buy = {}

local function _emit(event, payload)
  game_event.emit(event, payload)
end

local function _try_charge(game, player, currency, price)
  if paid_currency_bridge.is_managed_currency(game, currency) then
    return paid_currency_bridge.consume_currency(game, player, currency, price)
  end
  game:deduct_player_balance(player, currency, price)
  return true
end

function buy.execute(game, player, product_id, opts)
  opts = opts or {}
  if type(product_id) ~= "number" or product_id <= 0 then
    logger.warn("invalid market product id:", tostring(product_id))
    return false
  end

  local e = entry.get(product_id)
  assert(e ~= nil, "missing market entry: " .. tostring(product_id))

  if not entry.is_vehicle_enabled(e) then
    _emit(game_event.market.buy_failed, {
      player = player, entry = e, reason = "vehicle_disabled",
      popup = { title = "黑市", body = player.name .. " 当前对局已关闭载具功能" },
    })
    return { ok = false }
  end

  if not entry.is_market_enabled(e) then
    _emit(game_event.market.buy_failed, {
      player = player, entry = e, reason = "disabled",
      popup = { title = "黑市", body = player.name .. " 该商品暂不可购买" },
    })
    return { ok = false }
  end

  if validate.remaining_limit(game, product_id) <= 0 then
    _emit(game_event.market.buy_failed, {
      player = player, entry = e, reason = "sold_out",
      popup = { title = "黑市", body = player.name .. " 该商品已售罄" },
    })
    return { ok = false }
  end

  local price = entry.price(e)
  local currency = entry.currency(e)

  if game:player_balance(player, currency) < price then
    local opened_panel = false
    if paid_currency_bridge.is_managed_currency(game, currency) and not agent.is_auto_player(player) then
      opened_panel = paid_currency_bridge.open_purchase_panel(game, player, currency)
    end
    _emit(game_event.market.buy_failed, {
      player = player, entry = e, reason = "insufficient_balance",
      popup = { title = "黑市", body = player.name .. (opened_panel and " 余额不足，已打开购买面板" or " 余额不足") },
    })
    return { ok = false }
  end

  if e.kind == "item" then
    if inventory.is_full(player) then
      _emit(game_event.market.buy_failed, {
        player = player, entry = e, reason = "inventory_full",
        popup = { title = "黑市", body = player.name .. " 卡槽已满" },
      })
      return { ok = false }
    end
    if not _try_charge(game, player, currency, price) then
      _emit(game_event.market.buy_failed, {
        player = player, entry = e, reason = "charge_failed",
        popup = { title = "黑市", body = player.name .. " 支付失败" },
      })
      return { ok = false }
    end
    inventory.give(player, product_id)
    validate.consume_limit(game, product_id)
    _emit(game_event.market.bought_item, {
      player = player, entry = e, price = price, currency = currency,
      text = player.name .. " 在黑市购买 " .. entry.name(e) .. " 花费 " .. price .. " " .. currency,
    })
    return true
  end

  -- 载具购买
  if player.seat_id and not opts.skip_vehicle_prompt then
    return {
      ok = false,
      intent = {
        kind = "need_choice",
        choice_spec = choice_spec.build_use_skip(
          "market_vehicle_replace",
          "是否更换座驾",
          {
            "当前座驾：" .. entry.vehicle_name(player.seat_id),
            "新座驾：" .. entry.name(e),
            "价格：" .. tostring(price) .. " " .. currency,
          },
          { player_id = player.id, product_id = e.product_id },
          { use = "更换", skip = "算了" }
        ),
      },
    }
  end

  if not _try_charge(game, player, currency, price) then
    _emit(game_event.market.buy_failed, {
      player = player, entry = e, reason = "charge_failed",
      popup = { title = "黑市", body = player.name .. " 支付失败" },
    })
    return { ok = false }
  end

  game:set_player_seat(player, product_id)
  validate.consume_limit(game, product_id)
  _emit(game_event.market.bought_vehicle, {
    player = player, entry = e, price = price, currency = currency,
    text = player.name .. " 在黑市购买座驾 " .. entry.name(e) .. " 花费 " .. price .. " " .. currency,
  })
  return true
end

return buy
