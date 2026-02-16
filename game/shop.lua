local entry = require("game.shop.entry")
local validate = require("game.shop.validate")
local buy = require("game.shop.buy")
local agent = require("game.rule.agent")
local game_event = require("game.event")

local shop = {}

function shop.list_buyable(player, game)
  local list = {}
  for _, e in ipairs(entry.all()) do
    if validate.can_buy(game, player, e) then
      table.insert(list, e)
    end
  end
  return list
end

function shop.build_choice_spec(player, game)
  local options = {}
  local body_lines = {}
  local visible = {}
  local buyable = {}

  for _, e in ipairs(entry.all()) do
    if validate.can_buy(game, player, e) then
      table.insert(buyable, e)
    end
  end

  for _, e in ipairs(entry.all()) do
    local can_buy = validate.can_buy(game, player, e)
    table.insert(visible, { entry = e, can_buy = can_buy })
    if #visible >= 10 then
      break
    end
  end

  for _, slot in ipairs(visible) do
    local e = slot.entry
    local name = entry.name(e)
    local price = entry.price(e)
    local currency = entry.currency(e)
    local label = name .. " - " .. price .. " " .. currency
    table.insert(body_lines, label)
    table.insert(options, { id = e.product_id, label = label, can_buy = slot.can_buy })
  end

  if #buyable == 0 then
    return nil, { kind = "push_popup", payload = { title = "黑市", body = player.name .. " 暂无可购买商品" } }
  end

  return {
    kind = "market_buy",
    title = "黑市",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "不买",
    meta = { player_id = player.id },
  }
end

function shop.buy_with_opts(game, player, product_id, opts)
  return buy.execute(game, player, product_id, opts)
end

function shop.auto_buy(game, player)
  if agent.is_auto_player(player) then
    game_event.emit(game_event.market.auto_skip, {
      player = player,
      text = player.name .. " (AI) 到达黑市，选择不购买",
    })
    return
  end

  local list = shop.list_buyable(player, game)
  table.sort(list, function(a, b)
    return (entry.price(a) or 0) < (entry.price(b) or 0)
  end)

  if #list > 0 then
    local chosen = nil
    for _, e in ipairs(list) do
      if e.kind ~= "vehicle" or not player.seat_id then
        chosen = e
        break
      end
    end
    if chosen then
      shop.buy_with_opts(game, player, chosen.product_id, { skip_vehicle_prompt = true })
    end
  end
end

return shop
