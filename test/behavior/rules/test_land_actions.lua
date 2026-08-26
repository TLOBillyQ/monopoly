-- luacheck: ignore 211
local lu = require("luaunit")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local _with_patches = support.with_patches
local function _new_game()
  return support.new_game({ map = default_map })
end
local _first_land_tile = support.first_land_tile
local _tile_state = support.tile_state
local _assert_eq = support.assert_eq
local _resolve_landing = support.resolve_landing
local land_actions = require("src.rules.land.actions")
local pricing = require("src.rules.land.pricing")
local choice_resolver = require("src.rules.choice.resolver")

local _config_reset = require("test.support.config_reset")

local function _action_anim_count(game)
  local count = 0
  if game.turn.action_anim then
    count = count + 1
  end
  return count + #(game.turn.action_anim_queue or {})
end

TestLandActions = {}

function TestLandActions:setUp()
  _config_reset.reset_all()
end

function TestLandActions:test_land_rent_graph_adjacency_breaks_path_neighbors(self)
  local g = _new_game()
  local owner = g.players[1]
  local tenant = g.players[2]
  local idx_a = g.board:index_of_tile_id(27)
  local idx_b = g.board:index_of_tile_id(28)
  lu.assertEvalToTrue(idx_a and idx_b, "expected tile ids 27/28")
  local tile_a = g.board:get_tile(idx_a)
  local tile_b = g.board:get_tile(idx_b)
  lu.assertEvalToTrue(tile_a and tile_b, "expected land tiles")

  g:set_tile_owner(tile_a, owner.id)
  g:set_tile_owner(tile_b, owner.id)
  g:set_tile_level(tile_a, 1)
  g:set_tile_level(tile_b, 2)
  g:set_player_property(owner, tile_a.id, true)
  g:set_player_property(owner, tile_b.id, true)

  g:update_player_position(tenant, idx_a)
  local before = g:player_cash(tenant)
  land_actions.execute_pay_rent(g, tenant.id, tile_a.id)
  local expected = pricing.rent_for_level(tile_a, 1)
  _assert_eq(before - g:player_cash(tenant), expected, "graph adjacency rent excludes non-neighbors")
end

function TestLandActions:test_pending_free_rent_consumed_on_rent_settlement(self)
  local land = require("src.rules.land.executors")
  local g = _new_game()
  local tenant = g.players[1]
  local owner = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)

  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(tenant, idx)
  g:set_player_status(tenant, "pending_free_rent", true)

  local before = g:player_cash(tenant)
  land.executors.pay_rent.apply({ game = g, player = tenant, tile = tile_ref })
  _assert_eq(g:player_cash(tenant), before, "pending free rent must skip the rent payment")
  lu.assertFalse(g:has_pending_free_rent(tenant), "free rent flag must be consumed by the settlement")
end

function TestLandActions:test_rent_owner_missing_skips_payment(self)
  local land = require("src.rules.land.executors")
  local g = _new_game()
  local tenant = g.players[1]
  local owner = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)

  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(tenant, idx)

  g:set_player_status(tenant, "pending_free_rent", true)
  g:player_relocate(owner, { tile_type = "mountain", move_dir_mode = "clear" })
  g:player_apply_location_effect(owner, "mountain")
  local before = g:player_cash(tenant)
  land.executors.pay_rent.apply({ game = g, player = tenant, tile = tile_ref })
  _assert_eq(g:player_cash(tenant), before, "rent skipped when owner in mountain")
  lu.assertTrue(g:has_pending_free_rent(tenant), "pending_free_rent should remain when owner missing")

  g:set_player_status(tenant, "pending_free_rent", false)
  owner.eliminated = true
  local before2 = g:player_cash(tenant)
  local ok = land_actions.execute_pay_rent(g, tenant.id, tile_ref.id)
  _assert_eq(ok, false, "execute_pay_rent should return false when owner missing")
  _assert_eq(g:player_cash(tenant), before2, "rent skipped when owner missing")
end

function TestLandActions:test_choice_resolver_executes_canonical_landing_optional_effect(self)
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)

  local res = _resolve_landing(g, p, tile_ref, {})
  lu.assertEvalToTrue(res and res.waiting, "landing resolver should wait for optional effect")

  local pending = g.turn.pending_choice
  lu.assertEvalToTrue(pending and pending.kind == "landing_optional_effect", "expected canonical optional choice")

  local before_cash = g:player_cash(p)
  local action = {
    type = "choice_select",
    choice_id = pending.id,
    option_id = "buy_land",
  }

  local resolved = choice_resolver.resolve(g, pending, action)
  lu.assertEvalToTrue(resolved and resolved.status == "resolved", "canonical optional choice should resolve successfully")
  lu.assertEvalToTrue(g:player_cash(p) < before_cash, "canonical optional choice should still execute buy_land")
  lu.assertEvalToTrue(_tile_state(g, tile_ref).owner_id == p.id, "canonical optional choice should still purchase land")
end

function TestLandActions:test_land_actions_execute_strong_card_triggers_event(self)
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  local owner = g.players[2]
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(p, idx)
  inventory.give(p, item_ids.strong, { game = g }) -- strong card

  local events = {}
  local ok
  _with_patches({
    { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
      events[#events + 1] = result
    end },
  }, function()
    ok = land_actions.execute_strong_card(g, p.id, tile_ref.id)
  end)

  _assert_eq(ok, true, "execute_strong_card should return true on success")
  lu.assertEvalToTrue(#events > 0, "execute_strong_card should trigger land events")
  local strong_used = false
  for _, event in ipairs(events) do
    if event.event == "strong_card_used" then strong_used = true end
  end
  lu.assertEvalToTrue(strong_used, "strong card should emit the strong_card_used event kind")
end

-- 强征卡的成交价是「地块累计投入」。买不起要留卡拒绝,买得起要把产权账两侧
-- 同时翻过来。这三条此前都没测:拒绝路径整条没驱动过,产权翻转只验了 owner_id,
-- 没验双方的 player_property 台账。
local function _strong_card_setup(g)
  local buyer = g.players[1]
  local owner = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(buyer, idx)
  inventory.give(buyer, item_ids.strong, { game = g })
  return buyer, owner, tile_ref, require("src.rules.land.board_utils").total_invested(tile_ref, 1)
end

function TestLandActions:test_strong_card_rejects_when_the_buyer_cannot_cover_the_invested_total(self)
  local g = _new_game()
  local land_rules = require("src.rules.land.landing_rules")
  local buyer, owner, tile_ref, total_value = _strong_card_setup(g)
  g:set_player_cash(buyer, total_value - 1)

  local result = land_rules.execute_strong_card(g, buyer.id, tile_ref.id)

  _assert_eq(result.ok, false, "one coin short must reject the strong card")
  _assert_eq(result.reason, "insufficient_balance", "rejection reason should be stable")
  _assert_eq(_tile_state(g, tile_ref).owner_id, owner.id, "a rejected strong card must not move the tile")
  lu.assertNotNil(inventory.find_index(buyer, item_ids.strong), "a rejected strong card must stay in the bag")
end

function TestLandActions:test_strong_card_succeeds_when_cash_exactly_covers_the_invested_total(self)
  local g = _new_game()
  local land_rules = require("src.rules.land.landing_rules")
  local buyer, owner, tile_ref, total_value = _strong_card_setup(g)
  g:set_player_cash(buyer, total_value)

  local result = land_rules.execute_strong_card(g, buyer.id, tile_ref.id)

  -- 边界就在这一格:恰好付得起是成交,不是拒绝。
  _assert_eq(result.ok, true, "exact cash must be enough for the strong card")
  _assert_eq(_tile_state(g, tile_ref).owner_id, buyer.id, "the tile must change hands")
  _assert_eq(g:player_cash(buyer), 0, "the buyer pays the full invested total")
end

function TestLandActions:test_strong_card_refuses_an_unowned_tile(self)
  local g = _new_game()
  local land_rules = require("src.rules.land.landing_rules")
  local buyer = g.players[1]
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(buyer, idx)
  inventory.give(buyer, item_ids.strong, { game = g })

  -- 强征卡是「从别人手里买」,无主地块没有对手方。守卫失灵会让转账目标为 nil。
  local ok, err = pcall(land_rules.execute_strong_card, g, buyer.id, tile_ref.id)

  _assert_eq(ok, false, "an unowned tile must not be strong-carded")
  lu.assertNotNil(tostring(err):find("missing owner", 1, true),
    "the guard must name the missing owner, got: " .. tostring(err))
end

function TestLandActions:test_strong_card_flips_the_property_ledger_on_both_sides(self)
  local g = _new_game()
  local land_rules = require("src.rules.land.landing_rules")
  local buyer, owner, tile_ref = _strong_card_setup(g)

  land_rules.execute_strong_card(g, buyer.id, tile_ref.id)

  _assert_eq(buyer.properties[tile_ref.id], true, "the buyer must gain the property entry")
  _assert_eq(owner.properties[tile_ref.id], nil, "the seller must lose the property entry")
end

function TestLandActions:test_land_actions_execute_free_card_triggers_event(self)
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  local owner = g.players[2]
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(p, idx)
  inventory.give(p, item_ids.free_rent, { game = g }) -- free_rent card

  local events = {}
  local ok
  _with_patches({
    { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
      events[#events + 1] = result
    end },
  }, function()
    ok = land_actions.execute_free_card(g, p.id, tile_ref.id)
  end)

  _assert_eq(ok, true, "execute_free_card should return true on success")
  lu.assertEvalToTrue(#events > 0, "execute_free_card should trigger land events")
  local free_used = false
  for _, event in ipairs(events) do
    if event.event == "free_rent_used" then free_used = true end
  end
  lu.assertEvalToTrue(free_used, "free card should emit the free_rent_used event kind")
end

function TestLandActions:test_land_actions_execute_tax_free_card_triggers_event(self)
  local g = _new_game()
  local p = g:current_player()
  inventory.give(p, item_ids.tax_free, { game = g })
  g:set_player_status(p, "pending_tax_free", true)

  local events = {}
  local ok
  _with_patches({
    { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
      events[#events + 1] = result
    end },
  }, function()
    ok = land_actions.execute_tax_free_card(g, p.id)
  end)

  _assert_eq(ok, true, "execute_tax_free_card should return true on success")
  lu.assertEvalToTrue(#events > 0, "tax_free with pending status should apply a land event")
  local tax_free_used = false
  for _, event in ipairs(events) do
    if event.event == "tax_free" then tax_free_used = true end
  end
  lu.assertEvalToTrue(tax_free_used, "tax free card should emit the tax_free event kind")
end

function TestLandActions:test_land_actions_execute_pay_rent_queues_cash_anim_for_both_players(self)
  local g = _new_game()
  local owner = g.players[1]
  local tenant = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(tenant, idx)

  local ok = land_actions.execute_pay_rent(g, tenant.id, tile_ref.id)

  lu.assertEvalToTrue(ok == true, "execute_pay_rent should succeed")
  lu.assertEvalToTrue(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "rent should queue cash_receive anim")
  _assert_eq(g.turn.action_anim.player_id, tenant.id, "rent first anim should play on payer")
  _assert_eq(_action_anim_count(g), 2, "rent should queue one anim per changed player")
  _assert_eq(g.turn.action_anim_queue[1].player_id, owner.id, "rent second anim should play on owner")
end

function TestLandActions:test_land_actions_execute_pay_rent_bankruptcy_queues_cash_anim_for_both_players(self)
  local g = _new_game()
  local owner = g.players[1]
  local tenant = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(tenant, idx)
  g:set_player_cash(tenant, 1)

  local ok = land_actions.execute_pay_rent(g, tenant.id, tile_ref.id)

  lu.assertEvalToTrue(ok == true, "execute_pay_rent should still resolve on bankruptcy")
  lu.assertEvalToTrue(tenant.eliminated == true, "rent bankruptcy should eliminate tenant")
  _assert_eq(_action_anim_count(g), 2, "rent bankruptcy should still queue both payer and owner cash anims")
  _assert_eq(g.turn.action_anim.player_id, tenant.id, "rent bankruptcy first anim should play on payer")
  _assert_eq(g.turn.action_anim_queue[1].player_id, owner.id, "rent bankruptcy second anim should play on owner")
end

function TestLandActions:test_land_actions_safe_tile_state_returns_state(self)
  local g = _new_game()
  local idx, tile_ref = _first_land_tile(g.board)

  local st = land_actions.safe_tile_state(g, tile_ref)

  lu.assertEvalToTrue(type(st) == "table", "safe_tile_state should return a table")
  lu.assertNil(st.owner_id, "safe_tile_state should return nil owner_id for unowned land")
  lu.assertEvalToTrue(st.level == 0, "safe_tile_state should return level 0 for unowned land")
end

function TestLandActions:test_land_actions_safe_tile_state_guards_non_land_inputs(self)
  local g = _new_game()

  local missing_tile = land_actions.safe_tile_state(g, nil)
  lu.assertNil(missing_tile.owner_id, "nil tile should default to unowned")
  lu.assertEvalToTrue(missing_tile.level == 0, "nil tile should default to level 0")

  local non_land = land_actions.safe_tile_state(g, { type = "market" })
  lu.assertNil(non_land.owner_id, "non-land tile should default to unowned")
  lu.assertEvalToTrue(non_land.level == 0, "non-land tile should default to level 0")
end

function TestLandActions:test_land_actions_resolve_rent_owner_returns_owner(self)
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  local owner = g.players[2]
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(p, idx)

  local resolved_owner, st = land_actions.resolve_rent_owner(g, tile_ref, nil)

  lu.assertNotNil(resolved_owner, "resolve_rent_owner should return owner for owned land")
  lu.assertEvalToTrue(resolved_owner.id == owner.id, "resolve_rent_owner should return correct owner")
end

function TestLandActions:test_land_actions_resolve_rent_owner_skips_mountain_owner(self)
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  local owner = g.players[2]
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:player_relocate(owner, { tile_type = "mountain", move_dir_mode = "clear" })
  g:player_apply_location_effect(owner, "mountain")
  g:update_player_position(p, idx)

  local events = {}
  _with_patches({
    { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
      events[#events + 1] = result
    end },
  }, function()
    local resolved_owner, st = land_actions.resolve_rent_owner(g, tile_ref, nil)
    lu.assertNil(resolved_owner, "resolve_rent_owner should return nil for mountain owner")
    lu.assertEvalToTrue(#events == 1, "resolve_rent_owner should emit rent_skipped_mountain event")
    lu.assertEvalToTrue(events[1].event == "rent_skipped_mountain", "event should be rent_skipped_mountain")
    _assert_eq(events[1].ok, false, "mountain skip event must carry ok=false to distinguish from success")
  end)
end

function TestLandActions:test_execute_pay_rent_skips_mountain_owner_and_emits_event(self)
  local g = _new_game()
  local owner = g.players[1]
  local tenant = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(tenant, idx)
  g:player_relocate(owner, { tile_type = "mountain", move_dir_mode = "clear" })
  g:player_apply_location_effect(owner, "mountain")

  local events = {}
  local before_cash = g:player_cash(tenant)
  local ok
  _with_patches({
    { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
      events[#events + 1] = result
    end },
  }, function()
    ok = land_actions.execute_pay_rent(g, tenant.id, tile_ref.id)
  end)

  _assert_eq(ok, false, "execute_pay_rent should return false when owner in mountain")
  _assert_eq(#events, 1, "execute_pay_rent should emit rent_skipped_mountain event for mountain owner")
  _assert_eq(events[1].event, "rent_skipped_mountain", "event kind must be rent_skipped_mountain")
  _assert_eq(events[1].ok, false, "mountain skip event must carry ok=false")
  _assert_eq(g:player_cash(tenant), before_cash, "tenant cash should not change when owner in mountain")
end


return TestLandActions
