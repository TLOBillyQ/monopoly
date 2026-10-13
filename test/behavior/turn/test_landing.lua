-- luacheck: ignore 211
-- 原生 LuaUnit 改写：describe 拍平为 Test* 类，before_each → setUp（31 例），
-- 语句位裸 assert(cond, msg) → lu.assertEvalToTrue，表达式位内建 assert 保留。
local check = require("luassert")
local support = require("test.support.shared_support")
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
local land = require("src.turn.phases.land")
local chance_cfg = require("src.config.content.chance_cards")
local item_inventory = require("src.rules.items.inventory")
local land_rules = require("src.rules.land.landing_rules")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local constants = require("src.config.content.constants")
local monopoly_event = require("src.foundation.events")
local move_followup = require("src.turn.phases.move_followup")
local landing_visual_hold = require("src.state.visual_hold")
local movement = require("src.rules.movement")
local _config_reset = require("test.support.config_reset")

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

local function _run_roadblock_stopped_landing(g, p, idx)
  g:update_player_position(p, idx - 1)
  g.board:place_roadblock(idx)
  local move_result = movement.move(g, p, 3, { branch_parity = 1 })
  _assert_eq(move_result.stopped_on_roadblock, true, "roadblock should truncate movement on the land tile")
  _assert_eq(p.position, idx, "roadblock stop should leave player on the land tile")
  local followup_state, followup_args = move_followup.run({ game = g }, {
    mode = "resume_turn_move",
    player = p,
    raw_total = 3,
    move_result = move_result,
  })
  _assert_eq(followup_state, "landing", "roadblock stop should continue into landing")
  land.run({ game = g }, followup_args)
  local pending = _get_choice(g)
  check.is_truthy(pending and pending.kind == "landing_optional_effect", "roadblock-stopped landing should open landing optional choice")
  return pending
end

local function _choice_offers(pending, option_id)
  for _, option in ipairs(pending.options or {}) do
    if (type(option) == "table" and option.id or option) == option_id then
      return true
    end
  end
  return false
end

describe("TestLanding", function()

before_each(function()
  _config_reset.reset_all()
end)

it("test_black_market_angel_clears_mine_then_opens_market", function()
  local g = _new_game()
  local player = g.players[1]
  local idx, _ = _first_tile_by_type(g.board, "market")
  g:update_player_position(player, idx)
  g:set_player_deity(player, "angel", 1)
  g.board:place_mine(idx, {
    owner_id = g.players[2].id,
    armed = true,
  })

  local next_state, _ = land.run({ game = g }, { player = player, move_result = {} })
  local pending = _get_choice(g)

  _assert_eq(next_state, "wait_choice", "protected black market mine should still fall through to market choice")
  _assert_eq(pending and pending.kind, "market_buy", "protected black market mine should reopen market choice")
  _assert_eq(g.board:has_mine(idx), false, "protected black market mine should still clear")
  _assert_eq(player.position, idx, "protected black market mine should not relocate player")
end)

it("test_black_market_mine_resolves_before_market_choice", function()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local player = g.players[1]
  local idx, _ = _first_tile_by_type(g.board, "market")
  g:update_player_position(player, idx)
  g.board:place_mine(idx, {
    owner_id = g.players[2].id,
    armed = true,
  })

  local next_state, next_args = land.run({ game = g }, { player = player, move_result = {} })

  _assert_eq(next_state, "wait_action_anim", "black market mine should resolve before market choice")
  _assert_eq(next_args.next_state, "move_followup", "black market mine should continue through move_followup")
  _assert_eq(_get_choice(g), nil, "black market mine should not open market choice before resolving")
  _assert_eq(g.board:has_mine(idx), false, "black market mine should clear immediately when triggered")
  _assert_eq(player.position == idx, false, "black market mine should relocate player before market opens")
end)

it("test_black_market_roadblock_then_mine_skips_market_and_clears_mine", function()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  g.last_turn = {}
  local player = g.players[1]
  local market_idx, _ = _first_tile_by_type(g.board, "market")
  local approach_idx = assert(g.board:index_of_tile_id(27), "missing market approach tile")
  g:update_player_position(player, approach_idx)
  g:set_player_status(player, "move_dir", "right")
  g.board:place_roadblock(market_idx)
  g.board:place_mine(market_idx, {
    owner_id = g.players[2].id,
    armed = true,
  })

  local move_result = movement.move(g, player, 1, {
    branch_parity = 1,
    skip_market_check = true,
  })

  _assert_eq(move_result.stopped_on_roadblock, true, "roadblock should stop movement on black market")
  _assert_eq(player.position, market_idx, "roadblock stop should leave player on black market tile")
  _assert_eq(g.board:has_roadblock(market_idx), false, "roadblock should clear on trigger")
  _assert_eq(g.board:has_mine(market_idx), true, "mine should remain until landing resolves")

  local followup_state, followup_args = move_followup.run({ game = g }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 1,
    move_result = move_result,
  })
  _assert_eq(followup_state, "landing", "roadblock stop should continue into landing")

  local next_state, next_args = land.run({ game = g }, followup_args)

  _assert_eq(next_state, "wait_landing_visual", "landing should release visual hold before mine anim on black market")
  _assert_eq(next_args.next_state, "wait_action_anim", "visual hold should chain into action anim wait")
  _assert_eq(next_args.next_args.next_state, "move_followup", "roadblock plus mine should continue through move_followup")
  _assert_eq(_get_choice(g), nil, "roadblock plus mine should skip market choice after hospitalization")
  _assert_eq(g.board:has_mine(market_idx), false, "mine should clear after post-roadblock landing resolves")
end)

it("test_chance_landing_pushes_popup", function()
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
  g.rng = {
    next_int = function(_, min, max)
      check.is_truthy(min == 1, "chance landing rng should start at 1")
      check.is_truthy(max > 0, "chance landing rng should use a positive upper bound")
      return 1
    end,
  }
  local old_lua_api = LuaAPI
  local patched = old_lua_api or {}
  _with_patches({
    { key = "LuaAPI", value = patched },
    { target = patched, key = "rand", value = function()
      error("chance landing should not call LuaAPI.rand")
    end },
  }, function()
    local res = _resolve_landing(g, p, tile_ref, {})
    check.is_truthy(not res, "chance landing should not wait")
  end)
  local card_desc = chance_cfg[1] and chance_cfg[1].description or ""
  check.is_truthy(#popups == 1, "chance landing should push one popup")
  check.is_truthy(popups[1].title == "机会卡", "chance landing popup title mismatch")
  check.is_truthy(string.find(popups[1].body, p.name, 1, true), "chance landing popup should include player name")
  check.is_truthy(string.find(popups[1].body, card_desc, 1, true), "chance landing popup should include card description")
  check.is_truthy(popups[1].image_ref == chance_cfg[1].id, "chance landing popup image_ref mismatch")
  check.is_truthy(popups[1].auto_close_seconds == timing.action_anim_default_seconds, "chance popup auto close mismatch")
end)

it("test_execute_free_card_does_not_push_item_card_popup", function()
  local g = _new_game()
  local popups = {}
  local player = g.players[1]
  local idx, tile_ref = _first_land_tile(g.board)
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  player.inventory:add({ id = item_ids.free_rent })

  local res = land_rules.execute_free_card(g, player.id, tile_ref.id)

  _assert_eq(res and res.ok, true, "free card should execute successfully")
  _assert_eq(#popups, 0, "free card should not push a card popup")
end)

it("test_execute_strong_card_does_not_push_item_card_popup", function()
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
  player.inventory:add({ id = item_ids.strong })

  local res = land_rules.execute_strong_card(g, player.id, tile_ref.id)

  _assert_eq(res and res.ok, true, "strong card should execute successfully")
  _assert_eq(#popups, 0, "strong card should not push a card popup")
end)

it("test_execute_tax_free_card_does_not_push_item_card_popup", function()
  local g = _new_game()
  local popups = {}
  local player = g.players[1]
  _set_ui_port(g, {
    push_popup = function(_, payload)
      popups[#popups + 1] = payload
    end,
  })
  player.inventory:add({ id = item_ids.tax_free })

  local res = land_rules.execute_tax_free_card(g, player.id)

  _assert_eq(res and res.ok, true, "tax_free card should execute successfully")
  _assert_eq(#popups, 0, "tax_free card should not push a card popup")
end)

it("test_hospital_landing_emits_status_feedback_event", function()
  local g = _new_game()
  local emitted = {}
  local idx, tile_ref = _first_tile_by_type(g.board, "hospital")
  local player = g.players[1]
  g:update_player_position(player, idx)

  _with_patches({
    {
      target = monopoly_event,
      key = "emit",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    local res = _resolve_landing(g, player, tile_ref, {})
    check.is_truthy(not res, "hospital landing should resolve synchronously")
  end)

  check.is_truthy(#emitted >= 1, "hospital landing should emit at least one event")
  _assert_eq(emitted[1].kind, monopoly_event.feedback.status_applied, "hospital should emit status feedback event")
  _assert_eq(emitted[1].payload.cue_name, "hospital_shock", "hospital cue mismatch")
  _assert_eq(emitted[1].payload.tile_index, idx, "hospital feedback should preserve landing index")
end)

it("test_inert_mine_does_not_trigger_on_landing", function()
  local g = _new_game()
  local player = g.players[1]
  local idx = player.position
  g.board:place_mine(idx, {
    owner_id = g.players[2].id,
    armed = false,
  })

  local next_state, next_args = land.run({ game = g }, { player = player, move_result = {} })

  check.is_truthy(next_state ~= "wait_action_anim", "explicitly inert mine should not stage a mine trigger animation")
  check.is_truthy(next_state ~= "move_followup", "explicitly inert mine should not divert into hospital followup")
  _assert_eq(next_args and next_args.player, player, "inert mine should preserve normal landing continuation")
  _assert_eq(g:detention_remaining(player), 0, "inert mine should not hospitalize anyone")
  _assert_eq(g.board:has_mine(idx), true, "inert mine should remain on the tile")
end)

it("test_item_landing_full_inventory_no_duplicate_success_popup", function()
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
    check.is_truthy(ok == true, "preload inventory failed")
  end
  local idx, tile_ref = _first_tile_by_type(g.board, "item")
  g:update_player_position(p, idx)
  _with_patches({
    { target = item_inventory, key = "draw_random", value = function()
      return { id = 2002, name = item_inventory.item_name(2002) }
    end },
  }, function()
    local res = _resolve_landing(g, p, tile_ref, {})
    check.is_truthy(not res, "item landing should not wait")
  end)
  check.is_truthy(#popups == 1, "full inventory should only keep existing fail popup")
  check.is_truthy(popups[1].title == "道具", "full inventory popup title mismatch")
  check.is_truthy(string.find(popups[1].body, "背包已满", 1, true), "full inventory popup body mismatch")
end)

it("test_item_landing_queues_reveal_on_success", function()
  local g = _new_game()
  local popups = {}
  _set_ui_port(g, {
    wait_action_anim = true,
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
    check.is_truthy(not res, "item landing should not wait")
  end)
  -- 2026-08-18 换皮(CONTEXT「卡牌展示广播」 修订):道具地块拿卡改走「卡牌展示屏」弹窗全员广播。
  check.is_truthy(#popups == 1, "item tile landing should push the card reveal popup")
  local gain_popup = popups[1] or {}
  check.is_truthy(gain_popup.kind == "item_card", "gain popup kind mismatch")
  check.is_truthy(gain_popup.title == "道具卡", "gain popup title mismatch")
  check.is_truthy(gain_popup.image_ref == 2001, "gain popup image ref mismatch")
  check.is_truthy(gain_popup.broadcast == true, "gain popup should broadcast to all roles")
  check.is_truthy(gain_popup.auto_close_seconds == timing.item_get_reveal_seconds, "gain popup auto close mismatch")
  check.is_truthy(g.turn.action_anim and g.turn.action_anim.kind == "item_gain_popup", "item landing should queue gain popup anim")
  check.is_truthy(g.turn.action_anim.item_id == 2001, "item landing reveal item mismatch")
  check.is_truthy(g.turn.action_anim.player_id == p.id, "item landing reveal player mismatch")
end)

it("test_land_on_start_reward", function()
  local g = _new_game()
  local p = g:current_player()
  local idx, _ = _first_tile_by_type(g.board, "start")
  g:update_player_position(p, idx)
  local before = g:player_cash(p)
  local res = _resolve_landing(g, p, g.board:get_tile(idx), nil)
  check.is_truthy(not res, "landing resolver should not wait")
  _assert_eq(g:player_cash(p), before + constants.pass_start_bonus, "landing on start should grant reward")
end)

it("test_land_on_start_reward_when_passed_start_zero", function()
  local g = _new_game()
  local p = g:current_player()
  local idx, _ = _first_tile_by_type(g.board, "start")
  g:update_player_position(p, idx)
  local before = g:player_cash(p)
  local res = _resolve_landing(g, p, g.board:get_tile(idx), { passed_start = 0 })
  check.is_truthy(not res, "landing resolver should not wait")
  _assert_eq(g:player_cash(p), before + constants.pass_start_bonus, "passed_start zero should still grant start reward")
end)

it("test_land_on_start_rich_deity_doubles_reward", function()
  local g = _new_game()
  local p = g:current_player()
  g:set_player_deity(p, "rich", 3)
  local idx, _ = _first_tile_by_type(g.board, "start")
  g:update_player_position(p, idx)
  local before = g:player_cash(p)
  local res = _resolve_landing(g, p, g.board:get_tile(idx), {})
  check.is_truthy(not res, "landing resolver should not wait")
  _assert_eq(g:player_cash(p), before + constants.pass_start_bonus * 2, "rich deity should double start reward")
end)

it("test_land_on_start_skips_duplicate_passed_start_reward", function()
  local g = _new_game()
  local p = g:current_player()
  local idx, _ = _first_tile_by_type(g.board, "start")
  g:update_player_position(p, idx)
  local before = g:player_cash(p)
  local res = _resolve_landing(g, p, g.board:get_tile(idx), { passed_start = 1 })
  check.is_truthy(not res, "landing resolver should not wait")
  _assert_eq(g:player_cash(p), before, "passed_start reward should not be duplicated on start landing")
end)

it("test_landing_optional_choice_carries_move_result_meta", function()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local move_result = { passed_start = 2 }
  local res = _resolve_landing(g, p, tile_ref, move_result)
  check.is_truthy(res and res.waiting, "landing should open optional choice")
  local pending = _get_choice(g)
  check.is_truthy(pending and pending.meta and pending.meta.move_result == move_result,
    "optional choice meta must carry the landing move_result (kills `context or {}` -> `context and {}`)")
end)

it("test_landing_optional_stale_choice_is_blocked", function()
  local g = _new_game()
  _set_ui_port(g)
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = _resolve_landing(g, p, tile_ref, {})
  check.is_truthy(res and res.waiting, "should open choice")
  local pending = _get_choice(g)
  check.is_truthy(pending and pending.kind == "landing_optional_effect", "pending choice expected")

  g:set_player_cash(p, 0)

  local choice_resolver = require("src.rules.choice.resolver")
  choice_resolver.resolve(g, pending, { option_id = "buy_land" })
  check.is_truthy(_tile_state(g, tile_ref).owner_id == nil, "stale buy_land should be blocked")
end)

it("test_landing_optional_waits_with_ui", function()
  local g = _new_game()
  _set_ui_port(g)
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = _resolve_landing(g, p, tile_ref, {})
  check.is_truthy(res and res.waiting, "landing resolver should wait when UI is available")
  local pending = _get_choice(g)
  check.is_truthy(pending and pending.kind == "landing_optional_effect", "pending choice for landing optional")
  check.is_truthy(pending.allow_cancel == true,
    "landing optional choice must allow cancel (kills optional_allow_cancel true→false)")
  check.is_truthy(pending.cancel_label == "跳过",
    "landing optional cancel label must be 跳过 (kills cancel_label 跳过→nil)")
end)

it("test_landing_optional_waits_without_ui_and_can_resolve", function()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local before_cash = g:player_cash(p)
  local res = _resolve_landing(g, p, tile_ref, {})
  check.is_truthy(res and res.waiting, "landing resolver should wait without manual UI interaction")
  local pending = _get_choice(g)
  check.is_truthy(pending and pending.kind == "landing_optional_effect", "pending choice expected")
  local resolved = _resolve_choice_first(g, pending)
  check.is_truthy(resolved, "expected at least one optional effect")
  check.is_truthy(_tile_state(g, tile_ref).owner_id == p.id, "land should be purchased after resolving choice")
  check.is_truthy(g:player_cash(p) < before_cash, "cash deducted for purchase")
end)

it("test_legacy_save_with_seat_id_runs_through_mine_landing", function()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local player = g.players[1]
  player.seat_id = 4001
  _assert_eq(g:player_dice_count(player), 1, "legacy seat_id must not affect dice count")

  local idx = player.position
  g.board:place_mine(idx, { owner_id = g.players[2].id, armed = true })
  local next_state, next_args = land.run({ game = g }, { player = player, move_result = {} })
  _assert_eq(next_state, "wait_action_anim", "legacy seat_id should not break mine landing flow")

  local resumed_state, _ = move_followup.run({ game = g }, next_args.next_args)
  _assert_eq(resumed_state, "end_turn", "legacy seat_id should not block move followup")
  check.is_truthy(g:detention_remaining(player) > 0, "hospital stay must still apply for legacy save")
  _assert_eq(player.seat_id, 4001, "seat_id remains an orphan field; no logic path clears it")
end)

it("test_mine_landing_defers_hospital_effect_until_move_followup", function()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local player = g.players[1]
  local idx = player.position
  g.board:place_mine(idx, {
    owner_id = g.players[2].id,
    armed = true,
  })

  local next_state, next_args = land.run({ game = g }, { player = player, move_result = {} })
  local move_anim = nil
  if g.turn.action_anim and g.turn.action_anim.kind == "mine_trigger" then
    move_anim = g.turn.action_anim
  else
    for _, entry in ipairs(g.turn.action_anim_queue or {}) do
      if entry.kind == "mine_trigger" then
        move_anim = entry
        break
      end
    end
  end

  _assert_eq(next_state, "wait_action_anim", "mine landing should wait for move effect animation")
  _assert_eq(next_args.next_state, "move_followup", "mine landing should resume through move_followup")
  _assert_eq(move_anim and move_anim.kind, "mine_trigger", "mine landing should queue staged mine animation")
  _assert_eq(next_args.next_args.log_entries[1], player.name .. "触发地雷", "mine landing should defer trigger log")
  _assert_eq(g:detention_remaining(player), 0, "mine landing should not hospitalize before move followup")

  local resumed_state, _ = move_followup.run({ game = g }, next_args.next_args)
  _assert_eq(resumed_state, "end_turn", "mine move followup should end the turn after hospital followup")
  check.is_truthy(g:detention_remaining(player) > 0, "mine move followup should apply hospital stay")
end)

it("test_mine_with_active_hold_routes_through_landing_visual", function()
  local g = _new_game()
  _set_ui_port(g, { wait_action_anim = true })
  local player = g.players[1]
  local idx = player.position
  g.board:place_mine(idx, {
    owner_id = g.players[2].id,
    armed = true,
  })
  landing_visual_hold.start(g)

  local next_state, next_args = land.run({ game = g }, { player = player, move_result = {} })

  _assert_eq(next_state, "wait_landing_visual",
    "mine with active hold should route through wait_landing_visual first")
  _assert_eq(next_args.next_state, "wait_action_anim",
    "after visual hold release, should chain into wait_action_anim")
  _assert_eq(next_args.next_args.next_state, "move_followup",
    "action anim should chain into move_followup for hospital effects")
  check.is_truthy(landing_visual_hold.is_active_game(g),
    "hold should still be active until tick releases it")
end)

it("test_mountain_landing_emits_status_feedback_event", function()
  local g = _new_game()
  local emitted = {}
  local idx, tile_ref = _first_tile_by_type(g.board, "mountain")
  local player = g.players[1]
  g:update_player_position(player, idx)

  _with_patches({
    {
      target = monopoly_event,
      key = "emit",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    local res = _resolve_landing(g, player, tile_ref, {})
    check.is_truthy(not res, "mountain landing should resolve synchronously")
  end)

  check.is_truthy(#emitted >= 1, "mountain landing should emit at least one event")
  _assert_eq(emitted[1].kind, monopoly_event.feedback.status_applied, "mountain should emit status feedback event")
  _assert_eq(emitted[1].payload.cue_name, "mountain_stun", "mountain cue mismatch")
  _assert_eq(emitted[1].payload.tile_index, idx, "mountain feedback should preserve landing index")
end)

it("test_pass_players_without_steal_does_not_crash", function()
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
  check.is_truthy(not res, "landing resolver should not wait without steal")
  check.is_truthy(_get_choice(g) == nil, "should not open choice without steal")
end)

it("test_passing_player_with_steal_card_does_not_trigger_steal_and_still_pays_rent", function()
  local g = _new_game({ ai = { [2] = true } })
  local p1 = g.players[1]
  local p2 = g.players[2]
  p1.inventory:add({ id = item_ids.steal })
  p2.inventory:add({ id = item_ids.roadblock })
  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p2.id)
  g:set_player_property(p2, tile_ref.id, true)
  g:update_player_position(p1, idx)
  local before_cash = g:player_cash(p1)
  local before_steal_count = item_inventory.count(p1)
  local before_target_count = item_inventory.count(p2)
  local move_result = { encountered_players = { p2.id } }

  local res = _resolve_landing(g, p1, tile_ref, move_result)
  check.is_truthy(not res, "passing another player should not open a landing choice")
  check.is_truthy(_get_choice(g) == nil, "landing should not open steal prompt")
  _assert_eq(item_inventory.count(p1), before_steal_count, "steal card should remain unconsumed")
  _assert_eq(item_inventory.count(p2), before_target_count, "passed target should keep items")
  check.is_truthy(g:player_cash(p1) < before_cash, "rent must be paid after failed steal on AI-owned tile")
end)

it("test_roadblock_stop_on_own_land_opens_upgrade_choice", function()
  local g = _new_game()
  _set_ui_port(g)
  g.last_turn = {}
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p.id)
  g:set_player_property(p, tile_ref.id, true)
  g:set_tile_level(tile_ref, 0)
  local pending = _run_roadblock_stopped_landing(g, p, idx)
  check.is_truthy(_choice_offers(pending, "upgrade_land"), "upgrade_land should be offered after roadblock stop on own upgradeable land")
end)

it("test_roadblock_stop_on_unowned_land_opens_buy_choice", function()
  local g = _new_game()
  _set_ui_port(g)
  g.last_turn = {}
  local p = g:current_player()
  local idx, _ = _first_land_tile(g.board)
  local pending = _run_roadblock_stopped_landing(g, p, idx)
  check.is_truthy(_choice_offers(pending, "buy_land"), "buy_land should be offered after roadblock stop on unowned land")
end)

it("test_turn_land_bridges_to_wait_action_anim_for_chance", function()
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
    local next_state, next_args = land.run({ game = g }, { player = p, move_result = {} })
    check.is_truthy(next_state == "wait_landing_visual", "chance landing should defer visual release before action anim")
    check.is_truthy(next_args and next_args.next_state == "wait_action_anim",
      "chance landing should resume into wait_action_anim after visual hold")
    check.is_truthy(g.turn.action_anim and g.turn.action_anim.kind == "chance", "chance action anim should be queued")
  end)
end)

it("test_turn_land_bridges_to_wait_action_anim_for_item", function()
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
    local next_state, next_args = land.run({ game = g }, { player = p, move_result = {} })
    check.is_truthy(next_state == "wait_landing_visual", "item landing should defer visual release before action anim")
    check.is_truthy(next_args and next_args.next_state == "wait_action_anim",
      "item landing should resume into wait_action_anim after visual hold")
    check.is_truthy(g.turn.action_anim and g.turn.action_anim.kind == "item_gain_popup", "item gain popup anim should be queued")
    check.is_truthy(g.turn.action_anim and g.turn.action_anim.item_id == 2001, "item action anim item_id mismatch")
  end)
end)

it("test_upgrade_land_emits_tile_upgraded_event", function()
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
    check.is_truthy(res and res.waiting, "upgrade path should open landing optional choice")
    local pending = _get_choice(g)
    check.is_truthy(pending and pending.kind == "landing_optional_effect", "pending optional choice expected")
    local choice_resolver = require("src.rules.choice.resolver")
    choice_resolver.resolve(g, pending, { option_id = "upgrade_land" })
  end)

  check.is_truthy(_tile_state(g, tile_ref).level == 1, "upgrade should raise land level to 1")
  check.is_truthy(captured_kind == monopoly_event.land.tile_upgraded, "upgrade should emit tile_upgraded event")
  check.is_truthy(captured_payload and captured_payload.tile_id == tile_ref.id, "event payload tile_id mismatch")
  check.is_truthy(captured_payload and captured_payload.level == 1, "event payload level mismatch")
end)

it("test_upgrade_land_prefers_direct_ui_notify_before_event_bridge", function()
  local g = _new_game()
  local direct_calls = 0
  _set_ui_port(g, {
    on_tile_upgraded = function(_, tile_id, level)
      direct_calls = direct_calls + 1
      check.is_truthy(tile_id ~= nil and level ~= nil, "direct tile upgraded callback should receive payload")
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
    check.is_truthy(res and res.waiting, "upgrade path should open landing optional choice")
    local pending = _get_choice(g)
    check.is_truthy(pending and pending.kind == "landing_optional_effect", "pending optional choice expected")
    local choice_resolver = require("src.rules.choice.resolver")
    choice_resolver.resolve(g, pending, { option_id = "upgrade_land" })
  end)

  check.is_truthy(direct_calls == 1, "upgrade should notify ui runtime directly once")
  check.is_truthy(emitted == false, "direct ui notify should skip event bridge fallback")
end)

it("test_zero_cash_no_buy_choice", function()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile_ref = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  g:set_player_cash(p, 0)
  local res = _resolve_landing(g, p, tile_ref, {})
  check.is_truthy(res and res.waiting, "buy choice should appear even when cash is zero")
  check.is_truthy(_get_choice(g) ~= nil, "pending choice should exist")
end)


end)
