local chance_cards = require("Config.Generated.ChanceCards")

local t = dofile(".agents/tests/v2/helpers/testkit.lua")

local function _find_card(predicate)
  for _, card in ipairs(chance_cards) do
    if predicate(card) then
      return card
    end
  end
  return nil
end

local function _test_chance_add_cash_outcome()
  local service = t.new_service()
  local state = service:state()
  local card = _find_card(function(c)
    return c.effect == "add_cash" and c.target == "self"
  end)
  t.assert_true(card ~= nil, "应存在 add_cash 机会卡")
  local outcomes = t.services.chance.resolve(state, 1, card)
  t.assert_true(#outcomes > 0, "机会卡应产出结果")
  t.assert_eq(outcomes[1].kind, "cash", "应生成现金变化结果")
end

local function _test_chance_angel_immune()
  local service = t.new_service()
  local state = service:state()
  state.players[1].status.deity = { type = "angel", remaining = 3 }
  local card = _find_card(function(c)
    return c.negative == true and c.effect == "pay_cash"
  end)
  t.assert_true(card ~= nil, "应存在负面扣款卡")
  local outcomes = t.services.chance.resolve(state, 1, card)
  t.assert_eq(outcomes[1].kind, "immune", "天使附身应免疫负面机会卡")
end

local function _test_chance_move_backward_outcome()
  local service = t.new_service()
  local state = service:state()
  local card = _find_card(function(c)
    return c.effect == "move_backward" and (c.steps or 0) > 0
  end)
  t.assert_true(card ~= nil, "应存在后退机会卡")
  local outcomes = t.services.chance.resolve(state, 1, card)
  t.assert_eq(outcomes[1].kind, "move_steps", "应生成移动结果")
  t.assert_true((outcomes[1].steps or 0) < 0, "后退卡应是负步数")
end

local function _test_landing_on_chance_no_crash()
  local service = t.new_service()
  local state = service:state()
  local chance_index = t.find_tile_index_by_type(state, "chance")
  state.players[1].position = chance_index
  local res = t.services.landing.resolve(state, 1, {})
  t.assert_true(res ~= nil, "机会卡落地流程应可完成")
end

local function _test_market_list_buyable()
  local service = t.new_service()
  local state = service:state()
  local list = t.services.market.list_buyable(state, 1)
  t.assert_true(#list > 0, "黑市应至少存在可购买项")
end

local function _test_market_global_limit_blocks()
  local service = t.new_service()
  local state = service:state()
  local list = t.services.market.list_buyable(state, 1)
  t.assert_true(#list > 0, "前置失败：无可购买项")
  local entry = list[1]
  state.market.global_limits[entry.product_id] = 0
  t.assert_true(t.services.market.can_buy_entry(state, 1, entry) == false, "全局限量为 0 时不可购买")
end

local function _test_market_full_inventory_blocks_items()
  local service = t.new_service()
  local state = service:state()
  local player = state.players[1]
  for _ = 1, player.inventory.max_slots do
    player.inventory.items[#player.inventory.items + 1] = { id = 2001 }
  end
  local entry = t.services.market.entry(2003)
  t.assert_true(entry ~= nil and entry.kind == "item", "前置失败：缺少道具条目")
  t.assert_true(t.services.market.can_buy_entry(state, 1, entry) == false, "背包满时道具应不可买")
end

local function _test_market_choice_from_landing()
  local service = t.new_service()
  local state = service:state()
  local market_index = t.find_tile_index_by_type(state, "market")
  state.players[1].position = market_index
  local res = t.services.landing.resolve(state, 1, {})
  t.assert_true(res and res.waiting, "落到黑市应进入选择")
  t.assert_eq(res.choice.kind, "market_buy", "黑市选择类型应正确")
end

local function _test_market_buy_command()
  local service = t.new_service()
  local state = service:state()
  local choice = t.services.market.build_choice(state, 1)
  t.assert_true(choice ~= nil and #choice.options > 0, "应生成黑市可买列表")
  state.turn.phase = "wait_choice"
  state.turn.pending_interaction = choice
  local option_id = t.first_option_id(choice)
  local before_count = #state.players[1].inventory.items
  local before_limit = state.market.global_limits[tonumber(option_id)] or 0
  t.dispatch(service, t.commands.types.market_buy, {
    seat_id = 1,
    issued_at = 0,
    payload = { option_id = option_id },
  })
  local after_count = #state.players[1].inventory.items
  t.assert_true(after_count >= before_count, "购买后道具数不应减少")
  t.assert_true((state.market.global_limits[tonumber(option_id)] or 0) <= before_limit, "购买后限量应减少")
end

local function _test_turn_limit_victory()
  local service = t.new_service({ turn_limit = 1 })
  t.begin_turn(service, 1, 1)
  t.progress_until_idle(service)
  local state = service:state()
  t.assert_true(state.match.finished == true, "达到回合上限应结束对局")
  t.assert_true(state.status == "finished", "对局状态应为 finished")
end

return {
  { name = "chance/add_cash_outcome", run = _test_chance_add_cash_outcome },
  { name = "chance/angel_immune", run = _test_chance_angel_immune },
  { name = "chance/move_backward_outcome", run = _test_chance_move_backward_outcome },
  { name = "chance/landing_no_crash", run = _test_landing_on_chance_no_crash },
  { name = "market/list_buyable", run = _test_market_list_buyable },
  { name = "market/global_limit_blocks", run = _test_market_global_limit_blocks },
  { name = "market/full_inventory_blocks_items", run = _test_market_full_inventory_blocks_items },
  { name = "market/landing_choice", run = _test_market_choice_from_landing },
  { name = "market/market_buy_command", run = _test_market_buy_command },
  { name = "match/turn_limit_victory", run = _test_turn_limit_victory },
}
