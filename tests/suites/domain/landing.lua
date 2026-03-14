local support = require("support.domain_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _resolve_landing = support.resolve_landing
local _resolve_choice_first = support.resolve_choice_first
local _get_choice = support.get_choice
local _first_land_tile = support.first_land_tile
local _first_tile_by_type = support.first_tile_by_type
local _tile_state = support.tile_state
local _with_patches = support.with_patches
local _assert_eq = support.assert_eq
local land = require("src.game.flow.turn.phases.land")
local chance_cfg = require("src.config.content.chance_cards")
local item_inventory = require("src.rules.items.inventory")
local land_rules = require("src.rules.land.rules")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local monopoly_event = require("src.core.events.monopoly_events")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local move_followup = require("src.game.flow.turn.phases.move_followup")
local landing_visual_hold = require("src.state.state_access.landing_visual_hold")

local function _install_narrow_ports(game, ui_port)
  game.ui_port = ui_port
  game.anim_gate_port = {
    wait_move_anim = ui_port and ui_port.wait_move_anim == true,
    wait_action_anim = ui_port and ui_port.wait_action_anim == true,
  }
  game.popup_port = {
    push_popup = function(_, payload, popup_opts)
      if ui_port and type(ui_port.push_popup) == "function" then
        return ui_port:push_popup(payload, popup_opts)
      end
      return false
    end,
  }
  game.tile_feedback_port = {
    on_tile_upgraded = function(_, tile_id, level)
      if ui_port and type(ui_port.on_tile_upgraded) == "function" then
        return ui_port:on_tile_upgraded(tile_id, level) == true
      end
      return false
    end,
  }
end

local function _set_ui_port(game, overrides)
  _install_narrow_ports(game, _build_ui_port(overrides))
end

local function _test_land_on_start_reward()
  local g = _new_game()
  local p = g:current_player()
  local idx, _ = _first_tile_by_type(g.board, "start")
  g:update_player_position(p, idx)
  local before = p.cash
  local res = _resolve_landing(g, p, g.board:get_tile(idx), {})
  assert(not res, "landing resolver should not wait")
  assert(p.cash > before, "landing on start should grant reward")
end

local function _test_pass_players_without_steal_does_not_crash()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  local idx, _ = _first_tile_by_type(g.board, "start")
  local next_idx = idx + 1
  if next_idx > g.board:length() then
    next_idx = 1
  end
  g:update_player_position(p1, idx)
  g:update_player_position(p2, next_idx)
  local res = _resolve_landing(g, p1, g.board:get_tile(idx), {
    encountered_players = { p2.id },
  })
  assert(not res, "landing resolver should not wait without steal")
  assert(_get_choice(g) == nil, "should not open choice without steal")
end

local function _test_landing_optional_waits_with_ui()
  local g = _new_game()
  _set_ui_port(g)
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = _resolve_landing(g, p, tile_ref, {})
  assert(res and res.waiting, "landing resolver should wait when UI is available")
  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice for landing optional")
end

local function _test_landing_optional_waits_without_ui_and_can_resolve()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local before_cash = p.cash
  local res = _resolve_landing(g, p, tile_ref, {})
  assert(res and res.waiting, "landing resolver should wait without manual UI interaction")
  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected")
  local resolved = _resolve_choice_first(g, pending)
  assert(resolved, "expected at least one optional effect")
  assert(_tile_state(g, tile_ref).owner_id == p.id, "land should be purchased after resolving choice")
  assert(p.cash < before_cash, "cash deducted for purchase")
end

local function _test_landing_optional_stale_choice_is_blocked()
  local g = _new_game()
  _set_ui_port(g)
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = _resolve_landing(g, p, tile_ref, {})
  assert(res and res.waiting, "should open choice")
  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected")

  g:set_player_cash(p, 0)

  local choice_resolver = support.choice_resolver
  choice_resolver.resolve(g, pending, { option_id = "buy_land" })
  assert(_tile_state(g, tile_ref).owner_id == nil, "stale buy_land should be blocked")
end

local function _test_zero_cash_no_buy_choice()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  g:set_player_cash(p, 0)
  local res = _resolve_landing(g, p, tile_ref, {})
  assert(res and res.waiting, "buy choice should appear even when cash is zero")
  assert(_get_choice(g) ~= nil, "pending choice should exist")
end

local function _test_turn_land_bridges_to_wait_action_anim_for_chance()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  landing_visual_hold.start(g)
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)
  local old_lua_api = LuaAPI
  local patched = old_lua_api or {}
  _with_patches({
    { key = "LuaAPI", value = patched },
    { target = patched, key = "rand", value = function() return 0 end },
  }, function()
    local next_state, next_args = land({ game = g }, { player = p, move_result = {} })
    assert(next_state == "wait_landing_visual", "chance landing should defer visual release before action anim")
    assert(next_args and next_args.next_state == "wait_action_anim",
      "chance landing should resume into wait_action_anim after visual hold")
    assert(g.turn.action_anim and g.turn.action_anim.kind == "chance", "chance action anim should be queued")
  end)
end

local function _test_turn_land_bridges_to_wait_action_anim_for_item()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  landing_visual_hold.start(g)
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "item")
  g:update_player_position(p, idx)
  _with_patches({
    { target = item_inventory, key = "draw_random", value = function()
      return { id = 2001, name = item_inventory.item_name(2001) }
    end },
  }, function()
    local next_state, next_args = land({ game = g }, { player = p, move_result = {} })
    assert(next_state == "wait_landing_visual", "item landing should defer visual release before action anim")
    assert(next_args and next_args.next_state == "wait_action_anim",
      "item landing should resume into wait_action_anim after visual hold")
    assert(g.turn.action_anim and g.turn.action_anim.kind == "item_use", "item action anim should be queued")
    assert(g.turn.action_anim and g.turn.action_anim.item_id == 2001, "item action anim item_id mismatch")
  end)
end

local function _test_item_landing_pushes_popup_on_success()
  local g = _new_game()
  local popups = {}
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "item")
  g:update_player_position(p, idx)
  _with_patches({
    { target = item_inventory, key = "draw_random", value = function()
      return { id = 2001, name = item_inventory.item_name(2001) }
    end },
  }, function()
    local res = _resolve_landing(g, p, tile_ref, {})
    assert(not res, "item landing should not wait")
  end)
  assert(#popups == 1, "item landing should push one popup")
  assert(popups[1].title == "道具卡", "item landing popup title mismatch")
  assert(string.find(popups[1].body, p.name, 1, true), "item landing popup should include player name")
  assert(string.find(popups[1].body, "免费卡", 1, true), "item landing popup should include item name")
  assert(popups[1].image_ref == 2001, "item landing popup image_ref mismatch")
  assert(popups[1].auto_close_seconds == gameplay_rules.action_anim_default_seconds, "item popup auto close mismatch")
end

local function _test_item_landing_full_inventory_no_duplicate_success_popup()
  local g = _new_game()
  local popups = {}
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  local p = g:current_player()
  while not p.inventory:is_full() do
    local ok = p.inventory:add({ id = 2001 })
    assert(ok == true, "preload inventory failed")
  end
  local idx, tile_ref = _first_tile_by_type(g.board, "item")
  g:update_player_position(p, idx)
  _with_patches({
    { target = item_inventory, key = "draw_random", value = function()
      return { id = 2002, name = item_inventory.item_name(2002) }
    end },
  }, function()
    local res = _resolve_landing(g, p, tile_ref, {})
    assert(not res, "item landing should not wait")
  end)
  assert(#popups == 1, "full inventory should only keep existing fail popup")
  assert(popups[1].title == "道具", "full inventory popup title mismatch")
  assert(string.find(popups[1].body, "背包已满", 1, true), "full inventory popup body mismatch")
end

local function _test_chance_landing_pushes_popup()
  local g = _new_game()
  local popups = {}
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)
  local old_lua_api = LuaAPI
  local patched = old_lua_api or {}
  _with_patches({
    { key = "LuaAPI", value = patched },
    { target = patched, key = "rand", value = function() return 0 end },
  }, function()
    local res = _resolve_landing(g, p, tile_ref, {})
    assert(not res, "chance landing should not wait")
  end)
  local card_desc = chance_cfg[1] and chance_cfg[1].description or ""
  assert(#popups == 1, "chance landing should push one popup")
  assert(popups[1].title == "机会卡", "chance landing popup title mismatch")
  assert(string.find(popups[1].body, p.name, 1, true), "chance landing popup should include player name")
  assert(string.find(popups[1].body, card_desc, 1, true), "chance landing popup should include card description")
  assert(popups[1].image_ref == chance_cfg[1].id, "chance landing popup image_ref mismatch")
  assert(popups[1].auto_close_seconds == gameplay_rules.action_anim_default_seconds, "chance popup auto close mismatch")
end

local function _test_upgrade_land_emits_tile_upgraded_event()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  g:set_tile_owner(tile_ref, p.id)
  g:set_player_property(p, tile_ref.id, true)
  g:set_tile_level(tile_ref, 0)
  g:set_player_cash(p, 200000)

  local captured_kind = nil
  local captured_payload = nil
  _with_patches({
    { target = monopoly_event, key = "emit", value = function(kind, payload)
      captured_kind = kind
      captured_payload = payload
    end },
  }, function()
    local res = _resolve_landing(g, p, tile_ref, {})
    assert(res and res.waiting, "upgrade path should open landing optional choice")
    local pending = _get_choice(g)
    assert(pending and pending.kind == "landing_optional_effect", "pending optional choice expected")
    local choice_resolver = support.choice_resolver
    choice_resolver.resolve(g, pending, { option_id = "upgrade_land" })
  end)

  assert(_tile_state(g, tile_ref).level == 1, "upgrade should raise land level to 1")
  assert(captured_kind == monopoly_event.land.tile_upgraded, "upgrade should emit tile_upgraded event")
  assert(captured_payload and captured_payload.tile_id == tile_ref.id, "event payload tile_id mismatch")
  assert(captured_payload and captured_payload.level == 1, "event payload level mismatch")
end

local function _test_upgrade_land_prefers_direct_ui_notify_before_event_bridge()
  local g = _new_game()
  local direct_calls = 0
  _set_ui_port(g, {
    on_tile_upgraded = function(_, tile_id, level)
      direct_calls = direct_calls + 1
      assert(tile_id ~= nil and level ~= nil, "direct tile upgraded callback should receive payload")
      return true
    end,
  })
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  g:set_tile_owner(tile_ref, p.id)
  g:set_player_property(p, tile_ref.id, true)
  g:set_tile_level(tile_ref, 0)
  g:set_player_cash(p, 200000)

  local emitted = false
  _with_patches({
    { target = monopoly_event, key = "emit", value = function()
      emitted = true
      return true
    end },
  }, function()
    local res = _resolve_landing(g, p, tile_ref, {})
    assert(res and res.waiting, "upgrade path should open landing optional choice")
    local pending = _get_choice(g)
    assert(pending and pending.kind == "landing_optional_effect", "pending optional choice expected")
    local choice_resolver = support.choice_resolver
    choice_resolver.resolve(g, pending, { option_id = "upgrade_land" })
  end)

  assert(direct_calls == 1, "upgrade should notify ui runtime directly once")
  assert(emitted == false, "direct ui notify should skip event bridge fallback")
end

local function _test_execute_strong_card_pushes_item_card_popup()
  local g = _new_game()
  local popups = {}
  local player = g.players[1]
  local owner = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  g:set_tile_owner(tile_ref, owner.id)
  g:set_player_property(owner, tile_ref.id, true)
  g:set_tile_level(tile_ref, 1)
  g:set_player_cash(player, 100000)
  player.inventory:add({ id = gameplay_rules.item_ids.strong })

  local res = land_rules.execute_strong_card(g, player.id, tile_ref.id)

  _assert_eq(res and res.ok, true, "strong card should execute successfully")
  _assert_eq(#popups, 1, "strong card should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "strong card broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, gameplay_rules.item_ids.strong, "strong card broadcast image_ref mismatch")
end

local function _test_execute_free_card_pushes_item_card_popup()
  local g = _new_game()
  local popups = {}
  local player = g.players[1]
  local idx, tile_ref = _first_land_tile(g.board)
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  player.inventory:add({ id = gameplay_rules.item_ids.free_rent })

  local res = land_rules.execute_free_card(g, player.id, tile_ref.id)

  _assert_eq(res and res.ok, true, "free card should execute successfully")
  _assert_eq(#popups, 1, "free card should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "free card broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, gameplay_rules.item_ids.free_rent, "free card broadcast image_ref mismatch")
end

local function _test_execute_tax_free_card_pushes_item_card_popup()
  local g = _new_game()
  local popups = {}
  local player = g.players[1]
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  player.inventory:add({ id = gameplay_rules.item_ids.tax_free })

  local res = land_rules.execute_tax_free_card(g, player.id)

  _assert_eq(res and res.ok, true, "tax_free card should execute successfully")
  _assert_eq(#popups, 1, "tax_free card should push one broadcast popup")
  _assert_eq(popups[1].kind, "item_card", "tax_free broadcast should use item_card kind")
  _assert_eq(popups[1].image_ref, gameplay_rules.item_ids.tax_free, "tax_free broadcast image_ref mismatch")
end

local function _test_hospital_landing_emits_status_feedback_event()
  local g = _new_game()
  local emitted = {}
  local idx, tile_ref = _first_tile_by_type(g.board, "hospital")
  local player = g.players[1]
  g:update_player_position(player, idx)

  _with_patches({
    {
      target = runtime_event_bridge,
      key = "emit_custom_event",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    local res = _resolve_landing(g, player, tile_ref, {})
    assert(not res, "hospital landing should resolve synchronously")
  end)

  assert(#emitted >= 1, "hospital landing should emit at least one event")
  _assert_eq(emitted[1].kind, monopoly_event.feedback.status_applied, "hospital should emit status feedback event")
  _assert_eq(emitted[1].payload.cue_name, "hospital_shock", "hospital cue mismatch")
  _assert_eq(emitted[1].payload.tile_index, idx, "hospital feedback should preserve landing index")
end

local function _test_mountain_landing_emits_status_feedback_event()
  local g = _new_game()
  local emitted = {}
  local idx, tile_ref = _first_tile_by_type(g.board, "mountain")
  local player = g.players[1]
  g:update_player_position(player, idx)

  _with_patches({
    {
      target = runtime_event_bridge,
      key = "emit_custom_event",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    local res = _resolve_landing(g, player, tile_ref, {})
    assert(not res, "mountain landing should resolve synchronously")
  end)

  assert(#emitted >= 1, "mountain landing should emit at least one event")
  _assert_eq(emitted[1].kind, monopoly_event.feedback.status_applied, "mountain should emit status feedback event")
  _assert_eq(emitted[1].payload.cue_name, "mountain_stun", "mountain cue mismatch")
  _assert_eq(emitted[1].payload.tile_index, idx, "mountain feedback should preserve landing index")
end

local function _test_mine_landing_defers_hospital_effect_until_move_followup()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local player = g.players[1]
  local idx = player.position
  g.board:place_mine(idx, {
    owner_id = g.players[2].id,
    armed = true,
  })

  local next_state, next_args = land({ game = g }, { player = player, move_result = {} })

  _assert_eq(next_state, "wait_action_anim", "mine landing should wait for move effect animation")
  _assert_eq(next_args.next_state, "move_followup", "mine landing should resume through move_followup")
  _assert_eq(player.status.stay_turns or 0, 0, "mine landing should not hospitalize before move followup")

  local resumed_state, _ = move_followup.run({ game = g }, next_args.next_args)
  _assert_eq(resumed_state, "post_action", "mine move followup should resume into post_action")
  assert((player.status.stay_turns or 0) > 0, "mine move followup should apply hospital stay")
end

return {
  name = "landing",
  tests = {
    { name = "land_on_start_reward", run = _test_land_on_start_reward },
    { name = "pass_players_without_steal_does_not_crash", run = _test_pass_players_without_steal_does_not_crash },
    { name = "landing_optional_waits_with_ui", run = _test_landing_optional_waits_with_ui },
    { name = "landing_optional_waits_without_ui_and_can_resolve", run = _test_landing_optional_waits_without_ui_and_can_resolve },
    { name = "landing_optional_stale_choice_is_blocked", run = _test_landing_optional_stale_choice_is_blocked },
    { name = "zero_cash_no_buy_choice", run = _test_zero_cash_no_buy_choice },
    {
      name = "turn_land_bridges_to_wait_action_anim_for_chance",
      run = _test_turn_land_bridges_to_wait_action_anim_for_chance,
    },
    {
      name = "turn_land_bridges_to_wait_action_anim_for_item",
      run = _test_turn_land_bridges_to_wait_action_anim_for_item,
    },
    { name = "item_landing_pushes_popup_on_success", run = _test_item_landing_pushes_popup_on_success },
    { name = "item_landing_full_inventory_no_duplicate_success_popup", run = _test_item_landing_full_inventory_no_duplicate_success_popup },
    { name = "chance_landing_pushes_popup", run = _test_chance_landing_pushes_popup },
    { name = "upgrade_land_emits_tile_upgraded_event", run = _test_upgrade_land_emits_tile_upgraded_event },
    {
      name = "upgrade_land_prefers_direct_ui_notify_before_event_bridge",
      run = _test_upgrade_land_prefers_direct_ui_notify_before_event_bridge,
    },
    { name = "hospital_landing_emits_status_feedback_event", run = _test_hospital_landing_emits_status_feedback_event },
    { name = "mountain_landing_emits_status_feedback_event", run = _test_mountain_landing_emits_status_feedback_event },
    {
      name = "mine_landing_defers_hospital_effect_until_move_followup",
      run = _test_mine_landing_defers_hospital_effect_until_move_followup,
    },
    { name = "execute_strong_card_pushes_item_card_popup", run = _test_execute_strong_card_pushes_item_card_popup },
    { name = "execute_free_card_pushes_item_card_popup", run = _test_execute_free_card_pushes_item_card_popup },
    { name = "execute_tax_free_card_pushes_item_card_popup", run = _test_execute_tax_free_card_pushes_item_card_popup },
  },
}
