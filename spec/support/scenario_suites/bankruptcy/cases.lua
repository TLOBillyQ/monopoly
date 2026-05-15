---@diagnostic disable
-- luacheck: ignore 113 211
local function make_cases(helpers)
  local _ENV = helpers

local function _test_mandatory_payment_causes_bankruptcy()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local p2 = g.players[2]

  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p1.id)
  g:set_tile_level(tile_ref, 3)
  g:set_player_property(p1, tile_ref.id, true)

  g:set_player_cash(p2, 10)

  g:update_player_position(p2, idx)

  local before_eliminated = p2.eliminated
  _resolve_landing(g, p2, tile_ref, {})

  assert(p2.eliminated == true, "player should be eliminated after failing to pay rent")
  assert(before_eliminated == false, "player should not have been eliminated before")
end

local function _test_bankruptcy_resets_owned_tiles()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local _, tile1 = _first_land_tile(g.board)
  local tile2 = nil
  for i = 1, #g.board.path do
    local t = g.board.path[i]
    if t.type == "land" and t.id ~= tile1.id then
      tile2 = t
      break
    end
  end
  assert(tile2, "should have at least two land tiles")

  g:set_tile_owner(tile1, p1.id)
  g:set_tile_level(tile1, 2)
  g:set_player_property(p1, tile1.id, true)

  g:set_tile_owner(tile2, p1.id)
  g:set_tile_level(tile2, 1)
  g:set_player_property(p1, tile2.id, true)

  bankruptcy.eliminate(g, p1)

  local st1 = _tile_state(g, tile1)
  local st2 = _tile_state(g, tile2)
  assert(st1.owner_id == nil and st1.level == 0, "bankruptcy clears owned tile1")
  assert(st2.owner_id == nil and st2.level == 0, "bankruptcy clears owned tile2")
  assert(next(p1.properties) == nil, "bankruptcy clears player properties")
end

local function _test_bankruptcy_notifier_reads_grouped_ports()
  local g = _new_game()
  local p1 = g.players[1]
  local _, tile_ref = _first_land_tile(g.board)
  local calls = {}

  g:set_tile_owner(tile_ref, p1.id)
  g:set_player_property(p1, tile_ref.id, true)
  g.bankruptcy_feedback_port = {
    on_tiles_cleared = function(_, player, owned_tile_ids)
      calls[#calls + 1] = {
        player_id = player and player.id or nil,
        owned_tile_ids = owned_tile_ids,
      }
      return true
    end,
  }

  bankruptcy.eliminate(g, p1)

  assert(#calls == 1, "grouped bankruptcy notifier should be invoked once")
  assert(calls[1].player_id == p1.id, "notifier should receive eliminated player")
  assert(type(calls[1].owned_tile_ids) == "table", "notifier should receive owned_tile_ids list")
  assert(calls[1].owned_tile_ids[1] == tile_ref.id, "notifier should receive cleared tile id")
end

local function _test_gameplay_loop_set_game_installs_bankruptcy_feedback_port()
  local g = _new_game()
  local state = _build_loop_state()
  local calls = {}

  state.on_board_visual_sync = function(_, payload)
    calls[#calls + 1] = payload
    return true
  end

  gameplay_loop.set_game(state, g)
  g.bankruptcy_feedback_port.on_tiles_cleared(g, g.players[1], { 101 })

  assert(#calls == 1, "set_game should install bankruptcy feedback port")
  assert(calls[1].tile_ids[1] == 101, "feedback port should forward tile ids into board visual sync")
end

local function _test_bankruptcy_calls_role_life_die_before_lose()
  local g = _new_game()
  local p1 = g.players[1]
  local call_order = {}
  local role = {
    die = function()
      table.insert(call_order, "die")
    end,
    lose = function()
      table.insert(call_order, "lose")
    end,
  }
  support.with_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      if player_id == p1.id then
        return role
      end
      return nil
    end },
  }, function()
    bankruptcy.eliminate(g, p1)
  end)

  assert(#call_order == 2, "bankruptcy should call role die and lose")
  assert(call_order[1] == "die", "bankruptcy should call role die before lose")
  assert(call_order[2] == "lose", "bankruptcy should call role lose")
end

local function _test_rent_bankruptcy_leaves_payer_cash_negative()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local p2 = g.players[2]

  local idx, tile_ref = _first_land_tile(g.board)
  g:set_tile_owner(tile_ref, p1.id)
  g:set_tile_level(tile_ref, 3)
  g:set_player_property(p1, tile_ref.id, true)

  local p1_cash_before = g:player_balance(p1, "金币")
  local p2_starting_cash = 10
  g:set_player_cash(p2, p2_starting_cash)
  g:update_player_position(p2, idx)
  _resolve_landing(g, p2, tile_ref, {})

  assert(p2.eliminated == true, "payer should be eliminated when rent unaffordable")
  local p2_cash = g:player_balance(p2, "金币")
  assert(p2_cash < 0,
    "bankrupt rent payer cash must be negative (showing debt), got " .. tostring(p2_cash))
  local p1_cash = g:player_balance(p1, "金币")
  assert(p1_cash == p1_cash_before + p2_starting_cash,
    "owner should receive only payer's liquid (" .. tostring(p1_cash_before + p2_starting_cash)
      .. "), got " .. tostring(p1_cash))
end

local function _test_hospital_insufficient_funds_does_not_leave_positive_cash()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local fee = constants.hospital_fee
  local starting_cash = math.floor(fee / 2)

  g:set_player_cash(p1, starting_cash)
  g:set_player_status(p1, "pending_location_effect", "hospital")
  g:player_apply_hospital_effects(p1)

  assert(p1.eliminated == true, "player should be eliminated when hospital fee unpayable")
  assert(g:player_balance(p1, "金币") <= 0,
    "bankrupt cash must reflect the debt (<= 0), got " .. tostring(g:player_balance(p1, "金币")))
end

local function _test_chance_pay_others_stops_after_bankruptcy()
  local g = require("src.app.compose_game").new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2", "P3", "P4" },
    ai = {},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
  local p1 = g.players[1]
  local p2 = g.players[2]
  local p3 = g.players[3]
  local p4 = g.players[4]

  g:set_player_cash(p1, 15)
  g:set_player_cash(p2, 0)
  g:set_player_cash(p3, 0)
  g:set_player_cash(p4, 0)

  local chance_handler = assert(g.registries.chances.handlers.pay_others, "missing pay_others handler")
  chance_handler(g, p1, { effect = "pay_others", amount = 10 })

  assert(p1.eliminated == true, "payer should be eliminated when cash becomes non-positive")
  assert(g:player_balance(p2, "金币") == 10, "first recipient should receive transfer")
  assert(g:player_balance(p3, "金币") == 10, "second recipient should receive transfer before bankruptcy stop")
  assert(g:player_balance(p4, "金币") == 0, "later recipients should not receive transfer after bankruptcy")
end

local function _test_chance_collect_from_others_bankrupts_unable_payer()
  local g = require("src.app.compose_game").new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2", "P3", "P4" },
    ai = {},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
  local p1 = g.players[1]
  local p2 = g.players[2]
  local p3 = g.players[3]
  local p4 = g.players[4]

  g:set_player_cash(p1, 0)
  g:set_player_cash(p2, 5)
  g:set_player_cash(p3, 200)
  g:set_player_cash(p4, 200)

  local handler = assert(g.registries.chances.handlers.collect_from_others, "missing collect_from_others handler")
  handler(g, p1, { effect = "collect_from_others", amount = 100 })

  assert(p2.eliminated == true, "broke payer should be eliminated by collect_from_others")
  local p2_cash = g:player_balance(p2, "金币")
  assert(p2_cash < 0,
    "bankrupt collect-from-others payer cash must be negative, got " .. tostring(p2_cash))
  assert(g:player_balance(p3, "金币") == 100, "solvent payer should pay full amount")
  assert(g:player_balance(p4, "金币") == 100, "solvent payer should pay full amount")
  assert(g:player_balance(p1, "金币") == 5 + 100 + 100,
    "collector should receive each payer's actual liquid only, got "
      .. tostring(g:player_balance(p1, "金币")))
end

local function _test_set_tile_owner_without_ui_port_does_not_crash()
  local g = _new_game()
  g.ui_port = nil
  local _, tile_ref = _first_land_tile(g.board)
  local p1 = g.players[1]

  g:set_tile_owner(tile_ref, p1.id)
  local st_owned = _tile_state(g, tile_ref)
  assert(st_owned.owner_id == p1.id, "set_tile_owner should work without ui_port")

  g:reset_tile(tile_ref)
  local st_reset = _tile_state(g, tile_ref)
  assert(st_reset.owner_id == nil, "reset_tile should clear owner without ui_port")
  assert(st_reset.level == 0, "reset_tile should clear level without ui_port")
end

local function _test_tile_owner_notifier_receives_owner_changes()
  local g = _new_game()
  g.ui_port = nil
  local _, tile_ref = _first_land_tile(g.board)
  local p1 = g.players[1]
  local calls = {}
  g.tile_owner_notifier = {
    notify_owner_changed = function(_, tile_id, owner_id)
      calls[#calls + 1] = { tile_id = tile_id, owner_id = owner_id }
    end,
  }

  g:set_tile_owner(tile_ref, p1.id)
  g:reset_tile(tile_ref)

  assert(#calls == 2, "tile_owner_notifier should receive owner set and reset")
  assert(calls[1].tile_id == tile_ref.id and calls[1].owner_id == p1.id, "first notify should be owner set")
  assert(calls[2].tile_id == tile_ref.id and calls[2].owner_id == nil, "second notify should be owner clear")
end

local function _test_dispatch_validator_accepts_ui_state_snapshot()
  local ui_state = {
    input_blocked = true,
    item_slot_item_ids = { [1] = 2001 },
  }
  local blocked = dispatch_validator.should_block_action(ui_state, { type = "ui_button" })
  assert(blocked == true, "validator should block when ui_state.input_blocked")

  local state = {
    pending_choice = {
      id = 1,
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2001 } },
    },
  }
  _bind_ui_runtime(state)
  local res = dispatch_validator.resolve_item_slot_action(ui_state, state, {
    id = "item_slot_1",
    actor_role_id = 1,
  })
  assert(res and res.ok, "validator should resolve item slot action")
end

local function _test_intent_dispatcher_sets_choice_route_metadata()
  local g = _new_game()
  local choice_spec = {
    kind = "remote_dice_value",
    route_key = "remote",
    title = "遥控骰子",
    body_lines = { "选择点数" },
    options = { { id = 1, label = "1" }, { id = 2, label = "2" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = g:current_player().id, item_id = 2001 },
  }
  local entry = intent_dispatcher.open_choice(g, choice_spec, {})
  assert(entry.route_key == "remote", "intent_dispatcher should inject explicit route_key")
  assert(entry.requires_confirm == false, "remote route should not require confirm")

  local custom_entry = intent_dispatcher.open_choice(g, {
    kind = "item_target_player",
    title = "自定义路由",
    options = { { id = 1, label = "A" } },
    route = { route_key = "secondary_confirm", requires_confirm = true },
    meta = { player_id = g:current_player().id, item_id = 2001 },
  }, {})
  assert(custom_entry.route_key == "secondary_confirm", "explicit route should override inferred route")
  assert(custom_entry.requires_confirm == true, "explicit requires_confirm should be kept")

  local inline_entry = intent_dispatcher.open_choice(g, {
    kind = "item_phase_choice",
    route_key = "base_inline",
    title = "行动前：使用道具？",
    options = { { id = 2001, label = "路障卡" } },
    meta = { player_id = g:current_player().id, phase = "pre_action" },
  }, {})
  assert(inline_entry.route_key == "base_inline", "item_phase_choice should use base_inline route")
  assert(inline_entry.requires_confirm == false, "base_inline route should not require confirm")

  local unknown_entry = intent_dispatcher.open_choice(g, {
    kind = "unknown_choice_kind",
    title = "未知流程",
    options = { { id = 1, label = "A" } },
  }, {})
  assert(unknown_entry.route_key == "base_inline", "unknown choice should fallback to base_inline route")
end

local function _test_intent_dispatcher_rejects_missing_required_choice_meta()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "market_buy",
      title = "黑市",
      options = { { id = 2001, label = "A" } },
      meta = {},
    }, {})
  end)

  assert(ok == false, "open_choice should reject missing required meta")
  assert(tostring(err):find("market_buy requires meta.player_id", 1, true) ~= nil,
    "open_choice should report the missing required meta key")
  assert(g.turn.pending_choice == nil, "open_choice should not mutate pending_choice on schema failure")
end

local function _test_intent_dispatcher_rejects_missing_required_choice_meta_table()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "market_buy",
      title = "黑市",
      options = { { id = 2001, label = "A" } },
    }, {})
  end)

  assert(ok == false, "open_choice should reject missing meta table for required_meta descriptors")
  assert(tostring(err):find("market_buy requires meta", 1, true) ~= nil,
    "open_choice should report missing meta table before validating required keys")
  assert(g.turn.pending_choice == nil, "dispatcher should not mutate pending choice when meta table is missing")
end

local function _test_intent_dispatcher_normalizes_market_choice_meta()
  local g = _new_game()
  local entry = intent_dispatcher.open_choice(g, {
    kind = "market_buy",
    title = "黑市",
    options = { { id = 2001, label = "A" } },
    meta = {
      player_id = tostring(g:current_player().id),
      active_tab = "unknown",
      page_index = "2",
      page_count = "3",
    },
  }, {})

  assert(entry.meta.player_id == g:current_player().id, "market choice meta should normalize player_id")
  assert(entry.owner_role_id == g:current_player().id, "market choice should backfill owner_role_id from meta")
  assert(entry.active_tab == "item", "market choice should normalize unsupported tab to item")
  assert(entry.page_index == 2, "market choice should normalize page_index")
  assert(entry.page_count == 3, "market choice should normalize page_count")
end

local function _test_intent_dispatcher_normalizes_item_choice_meta()
  local g = _new_game()
  local entry = intent_dispatcher.open_choice(g, {
    kind = "item_phase_choice",
    route_key = "base_inline",
    title = "行动前：使用道具？",
    options = { { id = item_ids.remote_dice, label = "遥控骰子" } },
    meta = {
      player_id = tostring(g:current_player().id),
      phase = "pre_action",
    },
  }, {})

  assert(entry.meta.player_id == g:current_player().id, "item phase choice should normalize player_id")
  assert(entry.owner_role_id == g:current_player().id, "item phase choice should backfill owner_role_id from meta")
end

local function _test_intent_dispatcher_normalizes_landing_optional_effect_meta()
  local g = _new_game()
  local _, tile_ref = _first_land_tile(g.board)
  local entry = intent_dispatcher.open_choice(g, {
    kind = "landing_optional_effect",
    title = "请选择",
    options = { { id = "buy_land", label = "购买地块" } },
    meta = {
      player_id = tostring(g:current_player().id),
      tile_id = tostring(tile_ref.id),
      effect_ids = { "buy_land" },
      move_result = { next_state = "wait_choice" },
    },
  }, {})

  assert(entry.meta.player_id == g:current_player().id, "landing optional should normalize player_id")
  assert(entry.meta.tile_id == tile_ref.id, "landing optional should normalize tile_id")
  assert(entry.owner_role_id == g:current_player().id, "landing optional should backfill owner_role_id")
end

local function _test_intent_dispatcher_rejects_unknown_market_choice_player()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "market_buy",
      title = "黑市",
      options = { { id = 2001, label = "A" } },
      meta = { player_id = 999999 },
    }, {})
  end)

  assert(ok == false, "open_choice should reject unknown market player")
  assert(tostring(err):find("missing player: 999999", 1, true) ~= nil,
    "open_choice should report missing market player at dispatcher boundary")
  assert(g.turn.pending_choice == nil, "dispatcher validation failure should not mutate pending choice")
end

local function _test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile()
  local g = _new_game()
  local ok, err = pcall(function()
    intent_dispatcher.open_choice(g, {
      kind = "landing_optional_effect",
      title = "请选择",
      options = { { id = "buy_land", label = "购买地块" } },
      meta = {
        player_id = g:current_player().id,
        tile_id = 999999,
        effect_ids = { "buy_land" },
      },
    }, {})
  end)

  assert(ok == false, "open_choice should reject unknown landing tile")
  assert(tostring(err):find("missing tile: 999999", 1, true) ~= nil,
    "open_choice should report missing tile at dispatcher boundary")
  assert(g.turn.pending_choice == nil, "dispatcher validation failure should not mutate pending choice")
end

  return {
    _test_mandatory_payment_causes_bankruptcy = _test_mandatory_payment_causes_bankruptcy,
    _test_bankruptcy_resets_owned_tiles = _test_bankruptcy_resets_owned_tiles,
    _test_bankruptcy_notifier_reads_grouped_ports = _test_bankruptcy_notifier_reads_grouped_ports,
    _test_gameplay_loop_set_game_installs_bankruptcy_feedback_port = _test_gameplay_loop_set_game_installs_bankruptcy_feedback_port,
    _test_bankruptcy_calls_role_life_die_before_lose = _test_bankruptcy_calls_role_life_die_before_lose,
    _test_rent_bankruptcy_leaves_payer_cash_negative = _test_rent_bankruptcy_leaves_payer_cash_negative,
    _test_hospital_insufficient_funds_does_not_leave_positive_cash = _test_hospital_insufficient_funds_does_not_leave_positive_cash,
    _test_chance_pay_others_stops_after_bankruptcy = _test_chance_pay_others_stops_after_bankruptcy,
    _test_chance_collect_from_others_bankrupts_unable_payer = _test_chance_collect_from_others_bankrupts_unable_payer,
    _test_set_tile_owner_without_ui_port_does_not_crash = _test_set_tile_owner_without_ui_port_does_not_crash,
    _test_tile_owner_notifier_receives_owner_changes = _test_tile_owner_notifier_receives_owner_changes,
    _test_dispatch_validator_accepts_ui_state_snapshot = _test_dispatch_validator_accepts_ui_state_snapshot,
    _test_intent_dispatcher_sets_choice_route_metadata = _test_intent_dispatcher_sets_choice_route_metadata,
    _test_intent_dispatcher_rejects_missing_required_choice_meta = _test_intent_dispatcher_rejects_missing_required_choice_meta,
    _test_intent_dispatcher_rejects_missing_required_choice_meta_table = _test_intent_dispatcher_rejects_missing_required_choice_meta_table,
    _test_intent_dispatcher_normalizes_market_choice_meta = _test_intent_dispatcher_normalizes_market_choice_meta,
    _test_intent_dispatcher_normalizes_item_choice_meta = _test_intent_dispatcher_normalizes_item_choice_meta,
    _test_intent_dispatcher_normalizes_landing_optional_effect_meta = _test_intent_dispatcher_normalizes_landing_optional_effect_meta,
    _test_intent_dispatcher_rejects_unknown_market_choice_player = _test_intent_dispatcher_rejects_unknown_market_choice_player,
    _test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile = _test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile,
  }
end

return { make_cases = make_cases }
