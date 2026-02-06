local t = dofile(".agents/tests/v2/helpers/testkit.lua")

local function _test_landing_buy_choice()
  local service = t.new_service()
  local state = service:state()
  local land_index, tile_id = t.find_first_land(state)
  state.players[1].position = land_index
  local res = t.services.landing.resolve(state, 1, {})
  t.assert_true(res and res.waiting, "空地应弹购买选择")
  t.assert_eq(res.choice.kind, "landing_optional_effect", "选择类型应为落地可选效果")
  t.assert_eq(res.choice.meta.tile_id, tile_id, "选择应绑定当前地块")
end

local function _test_landing_buy_resolve_by_command()
  local service = t.new_service()
  local state = service:state()
  local land_index, tile_id = t.find_first_land(state)
  state.players[1].position = land_index
  local res = t.services.landing.resolve(state, 1, {})
  state.turn.pending_interaction = res.choice
  state.turn.phase = "wait_choice"
  local before = state.players[1].cash
  t.dispatch(service, t.commands.types.choice_select, {
    seat_id = 1,
    issued_at = 0,
    payload = { option_id = "buy_land" },
  })
  t.assert_eq(state.board.tile_states[tile_id].owner_id, 1, "购买后所有权应归当前玩家")
  t.assert_true(state.players[1].cash < before, "购买后应扣钱")
end

local function _test_landing_upgrade_choice()
  local service = t.new_service()
  local state = service:state()
  local land_index, tile_id = t.find_first_land(state)
  t.set_land_owner(state, tile_id, 1, 1)
  state.players[1].position = land_index
  local res = t.services.landing.resolve(state, 1, {})
  t.assert_true(res and res.waiting, "自有地应可升级")
  t.assert_eq(res.choice.kind, "landing_optional_effect", "应走落地可选效果")
end

local function _test_rent_transfer_cash()
  local service = t.new_service()
  local state = service:state()
  local land_index, tile_id = t.find_first_land(state)
  t.set_land_owner(state, tile_id, 2, 1)
  state.players[1].position = land_index
  state.players[1].cash = 15000
  state.players[2].cash = 15000
  local before1 = state.players[1].cash
  local before2 = state.players[2].cash
  t.services.landing.resolve(state, 1, {})
  t.assert_true(state.players[1].cash < before1, "租金应扣除")
  t.assert_true(state.players[2].cash > before2, "房东应收租")
end

local function _test_free_rent_prompt()
  local service = t.new_service()
  local state = service:state()
  local land_index, tile_id = t.find_first_land(state)
  t.set_land_owner(state, tile_id, 2, 1)
  state.players[1].position = land_index
  state.players[1].status.pending_free_rent = true
  local res = t.services.landing.resolve(state, 1, {})
  t.assert_true(res and res.waiting, "持有免费效果应弹窗确认")
  t.assert_eq(res.choice.kind, "rent_card_prompt", "应弹免费卡提示")
end

local function _test_strong_card_prompt()
  local service = t.new_service()
  local state = service:state()
  local land_index, tile_id = t.find_first_land(state)
  t.set_land_owner(state, tile_id, 2, 2)
  state.players[1].position = land_index
  state.players[1].cash = 500000
  t.give_item(state, 1, 2009)
  local res = t.services.landing.resolve(state, 1, {})
  t.assert_true(res and res.waiting, "强征卡应弹窗")
  t.assert_eq(res.choice.kind, "rent_card_prompt", "应复用租金提示流程")
end

local function _test_tax_free_prompt()
  local service = t.new_service()
  local state = service:state()
  local tax_index = t.find_tile_index_by_type(state, "tax")
  state.players[1].position = tax_index
  state.players[1].status.pending_tax_free = true
  local res = t.services.landing.resolve(state, 1, {})
  t.assert_true(res and res.waiting, "免税效果应弹窗")
  t.assert_eq(res.choice.kind, "tax_card_prompt", "应弹免税卡选择")
end

local function _test_bankruptcy_resets_owned_tiles()
  local service = t.new_service()
  local state = service:state()
  local rent_index, rent_tile_id = t.find_first_land(state)
  local own_index = rent_index + 1
  if own_index > #state.board.path then
    own_index = 1
  end
  local own_tile_id = state.board.path[own_index]
  if state.board.tile_defs[own_tile_id].type ~= "land" then
    own_index, own_tile_id = t.find_first_land(state)
    rent_index = own_index + 1
    if rent_index > #state.board.path then
      rent_index = 1
    end
    rent_tile_id = state.board.path[rent_index]
  end

  t.set_land_owner(state, own_tile_id, 1, 1)
  t.set_land_owner(state, rent_tile_id, 2, 3)
  state.players[1].position = rent_index
  state.players[1].cash = 50

  t.services.landing.resolve(state, 1, {})

  t.assert_true(state.players[1].eliminated == true, "破产后应出局")
  t.assert_eq(state.board.tile_states[own_tile_id].owner_id, nil, "破产后应清空名下地块")
  t.assert_eq(state.board.tile_states[own_tile_id].level, 0, "破产后地块等级应归零")
end

return {
  { name = "land/landing_buy_choice", run = _test_landing_buy_choice },
  { name = "land/landing_buy_resolve", run = _test_landing_buy_resolve_by_command },
  { name = "land/landing_upgrade_choice", run = _test_landing_upgrade_choice },
  { name = "land/rent_transfer_cash", run = _test_rent_transfer_cash },
  { name = "land/free_rent_prompt", run = _test_free_rent_prompt },
  { name = "land/strong_card_prompt", run = _test_strong_card_prompt },
  { name = "land/tax_free_prompt", run = _test_tax_free_prompt },
  { name = "land/bankruptcy_resets_tiles", run = _test_bankruptcy_resets_owned_tiles },
}
