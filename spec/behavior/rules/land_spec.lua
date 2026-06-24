-- luacheck: ignore 211
local support = require("spec.support.shared_support")
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
local constants = require("src.config.content.constants")
local function _require_upvalue(fn, expected_name)
  assert(debug and type(debug.getupvalue) == "function", "debug.getupvalue should be available for characterization tests")
  local index = 1
  while true do
    local name, value = debug.getupvalue(fn, index)
    assert(name ~= nil, "missing upvalue: " .. tostring(expected_name))
    if name == expected_name then
      return value
    end
    index = index + 1
  end
end

local function _reload_core_agent()
  package.loaded["src.computer.agent"] = nil
  return require("src.computer.agent")
end

local function _remote_priority_for_tile_type()
  local agent = _reload_core_agent()
  local remote_priority = _require_upvalue(agent.pick_remote_dice_value, "_remote_priority")
  return _require_upvalue(remote_priority, "_remote_priority_for_tile_type")
end

local function _remote_priority_for_land()
  local agent = _reload_core_agent()
  local remote_priority = _require_upvalue(agent.pick_remote_dice_value, "_remote_priority")
  local rules = _require_upvalue(remote_priority, "remote_priority_rules")
  return rules.land
end

local function _action_anim_count(game)
  local count = 0
  if game.turn.action_anim then
    count = count + 1
  end
  return count + #(game.turn.action_anim_queue or {})
end

describe("land", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("ai_picks_land_purchase", function()
    local agent = _reload_core_agent()
    local g = _new_game()
    local ai_player = g.players[2]
    assert(agent.is_auto_player(ai_player), "player 2 should be AI")

    g.turn.current_player_index = 2
    g.dirty.turn = true
    g.dirty.any = true

    assert(g:current_player() == ai_player, "AI should be current player")

    local idx, tile_ref = _first_land_tile(g.board)
    g:update_player_position(ai_player, idx)

    local res = _resolve_landing(g, ai_player, tile_ref, {})
    assert(res and res.waiting, "should wait for choice")

    local pending = g.turn.pending_choice
    assert(pending and pending.kind == "landing_optional_effect", "should have landing choice")
    _assert_eq(pending.route_key, "secondary_confirm", "buy_land optional should expose secondary confirm route")
    _assert_eq(pending.requires_confirm, true, "buy_land optional should expose confirm requirement")
    local first_option = pending.options and pending.options[1] or nil
    assert(first_option and first_option.confirm_title == "买地", "buy_land should expose confirm title from use-case output")
    assert(first_option and first_option.confirm_body == "地块：" .. tile_ref.name .. "。要买吗？",
      "buy_land should expose confirm body from use-case output")

    local action = agent.auto_action_for_choice(g, pending)
    assert(action, "AI should return an action")
    assert(action.type == "choice_select", "AI should select land purchase")
    assert(action.option_id == "buy_land", "AI should pick buy_land")

    local before_cash = g:player_balance(ai_player, "金币")
    choice_resolver.resolve(g, pending, action)
    assert(g:player_balance(ai_player, "金币") == before_cash - tile_ref.price, "AI cash should decrease by land price")
    assert(_tile_state(g, tile_ref).owner_id == ai_player.id, "land should be purchased")
  end)

  it("ai_remote_priority_ranks_item", function()
    local remote_priority = _remote_priority_for_tile_type()
    local rank, score = remote_priority("item", 2)
    _assert_eq(rank, 1, "item should keep rank")
    _assert_eq(score, 2, "item should keep score")
  end)

  it("ai_remote_priority_ranks_chance", function()
    local remote_priority = _remote_priority_for_tile_type()
    local rank, score = remote_priority("chance", 3)
    _assert_eq(rank, 2, "chance should keep rank")
    _assert_eq(score, 3, "chance should keep score")
  end)

  it("ai_remote_priority_ranks_empty_land", function()
    local remote_priority = _remote_priority_for_land()
    local rank, score = remote_priority({}, { id = 7 }, {
      type = "land",
      owner_id = nil,
      level = 0,
      rents = { 80 },
    }, 4)
    _assert_eq(rank, 3, "empty land should keep rank")
    _assert_eq(score, 4, "empty land should keep score")
  end)

  it("ai_remote_priority_ranks_self_owned_land", function()
    local remote_priority = _remote_priority_for_land()
    local player = { id = 7 }
    local rank, score = remote_priority({}, player, {
      type = "land",
      owner_id = player.id,
      level = 1,
      rents = { 80, 160 },
    }, 5)
    _assert_eq(rank, 4, "self-owned land should keep rank")
    _assert_eq(score, 5, "self-owned land should keep score")
  end)

  it("ai_remote_priority_ranks_enemy_land", function()
    local remote_priority = _remote_priority_for_land()
    local rank, score = remote_priority({}, { id = 1 }, {
      type = "land",
      owner_id = 2,
      level = 1,
      rents = { 120, 300 },
    }, 4)
    _assert_eq(rank, 10, "enemy-owned land should keep fallback rank")
    _assert_eq(score, -300, "enemy-owned land score should be negative rent")
  end)

  it("ai_pick_remote_dice_value_prefers_item_rank_over_market", function()
    local agent = _reload_core_agent()
    local tiles = {
      [1] = { type = "item" },
      [2] = { type = "market" },
      [3] = { type = "chance" },
      [4] = { type = "start" },
      [5] = { type = "tax" },
      [6] = { type = "hospital" },
    }
    local board = {
      step_forward_by_facing = function(_, current, facing)
        return current + 1, nil, facing, false
      end,
      has_roadblock = function()
        return false
      end,
      has_mine = function()
        return false
      end,
      get_tile = function(_, idx)
        return tiles[idx]
      end,
    }
    local value, tile = agent.pick_remote_dice_value({
      board = board,
    }, {
      id = 1,
      position = 0,
    }, 1)

    _assert_eq(value, 1, "remote dice should prefer item rank over lower-priority tiles")
    _assert_eq(tile.type, "item", "remote dice should return the chosen item tile")
  end)

  it("ai_pick_remote_dice_value_prefers_lower_enemy_rent", function()
    local agent = _reload_core_agent()
    local tiles = {
      [1] = { type = "land", owner_id = 2, level = 0, rents = { 100 } },
      [2] = { type = "land", owner_id = 2, level = 1, rents = { 100, 400 } },
      [3] = { type = "land", owner_id = 2, level = 0, rents = { 150 } },
      [4] = { type = "land", owner_id = 2, level = 0, rents = { 200 } },
      [5] = { type = "land", owner_id = 2, level = 0, rents = { 250 } },
      [6] = { type = "land", owner_id = 2, level = 0, rents = { 300 } },
    }
    local board = {
      step_forward_by_facing = function(_, current, facing)
        return current + 1, nil, facing, false
      end,
      has_roadblock = function()
        return false
      end,
      has_mine = function()
        return false
      end,
      get_tile = function(_, idx)
        return tiles[idx]
      end,
    }
    local value, tile = agent.pick_remote_dice_value({
      board = board,
    }, {
      id = 1,
      position = 0,
    }, 1)

    _assert_eq(value, 1, "remote dice should prefer the lowest-rent enemy land when all ranks match")
    _assert_eq(tile.rents[1], 100, "remote dice should keep negative-rent tie-break behavior")
  end)

  it("ai_remote_priority_ranks_market", function()
    local remote_priority = _remote_priority_for_tile_type()
    local rank, score = remote_priority("market", 6)
    _assert_eq(rank, 6, "market should keep rank")
    _assert_eq(score, 6, "market should keep score")
  end)

  it("land_rent_graph_adjacency_breaks_path_neighbors", function()
    local g = _new_game()
    local owner = g.players[1]
    local tenant = g.players[2]
    local idx_a = g.board:index_of_tile_id(27)
    local idx_b = g.board:index_of_tile_id(28)
    assert(idx_a and idx_b, "expected tile ids 27/28")
    local tile_a = g.board:get_tile(idx_a)
    local tile_b = g.board:get_tile(idx_b)
    assert(tile_a and tile_b, "expected land tiles")

    g:set_tile_owner(tile_a, owner.id)
    g:set_tile_owner(tile_b, owner.id)
    g:set_tile_level(tile_a, 1)
    g:set_tile_level(tile_b, 2)
    g:set_player_property(owner, tile_a.id, true)
    g:set_player_property(owner, tile_b.id, true)

    g:update_player_position(tenant, idx_a)
    local before = g:player_balance(tenant, "金币")
    land_actions.execute_pay_rent(g, tenant.id, tile_a.id)
    local expected = pricing.rent_for_level(tile_a, 1)
    _assert_eq(before - g:player_balance(tenant, "金币"), expected, "graph adjacency rent excludes non-neighbors")
  end)

  it("total_invested_returns_purchase_price_for_negative_level", function()
    local tile = {
      price = 400,
      upgrade_costs = { 50, 75, 100 },
    }
    _assert_eq(pricing.total_invested(tile, -3), 400, "negative level should keep purchase price only")
  end)

  it("rent_for_level_uses_planning_formula", function()
    local tile = { price = 100, upgrade_costs = { 100, 200, 400 }, rents = { 999, 999, 999, 999 } }
    _assert_eq(pricing.rent_for_level(tile, 0), 50, "level 0 rent should be half base price")
    _assert_eq(pricing.rent_for_level(tile, 1), 100, "level 1 rent should double level 0")
    _assert_eq(pricing.rent_for_level(tile, 2), 200, "level 2 rent should double level 1")
    _assert_eq(pricing.rent_for_level(tile, 3), 400, "level 3 rent should double level 2")
  end)

  it("property_value_total_invested_includes_owner_paid_upgrades", function()
    -- 强征卡支付 = 地价 + owner 已支付的全部升级金币（src/rules/commerce/property_value.lua）
    -- 必须读 tile.upgrade_costs，并与 land/pricing.total_invested 完全一致。
    local property_value = require("src.rules.commerce.property_value")
    local tile = { price = 1000, upgrade_costs = { 1000, 2000, 4000 } }
    _assert_eq(property_value.total_invested(tile, 0), 1000, "level 0 should equal base price")
    _assert_eq(property_value.total_invested(tile, 1), 2000, "level 1 should add first upgrade")
    _assert_eq(property_value.total_invested(tile, 2), 4000, "level 2 should add first two upgrades")
    _assert_eq(property_value.total_invested(tile, 3), 8000, "level 3 should add base + all three upgrades")
    for level = 0, 3 do
      _assert_eq(
        property_value.total_invested(tile, level),
        pricing.total_invested(tile, level),
        "property_value must mirror pricing at level " .. tostring(level)
      )
    end
  end)

  it("rent_owner_missing_skips_payment", function()
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
    local before = g:player_balance(tenant, "金币")
    land.executors.pay_rent.apply({ game = g, player = tenant, tile = tile_ref })
    _assert_eq(g:player_balance(tenant, "金币"), before, "rent skipped when owner in mountain")
    assert(tenant.status.pending_free_rent == true, "pending_free_rent should remain when owner missing")

    g:set_player_status(tenant, "pending_free_rent", false)
    owner.eliminated = true
    local before2 = g:player_balance(tenant, "金币")
    local ok = land_actions.execute_pay_rent(g, tenant.id, tile_ref.id)
    _assert_eq(ok, false, "execute_pay_rent should return false when owner missing")
    _assert_eq(g:player_balance(tenant, "金币"), before2, "rent skipped when owner missing")
  end)

  it("choice_resolver_executes_canonical_landing_optional_effect", function()
    local g = _new_game()
    local p = g:current_player()
    local idx, tile_ref = _first_land_tile(g.board)
    g:update_player_position(p, idx)

    local res = _resolve_landing(g, p, tile_ref, {})
    assert(res and res.waiting, "landing resolver should wait for optional effect")

    local pending = g.turn.pending_choice
    assert(pending and pending.kind == "landing_optional_effect", "expected canonical optional choice")

    local before_cash = g:player_balance(p, "金币")
    local action = {
      type = "choice_select",
      choice_id = pending.id,
      option_id = "buy_land",
    }

    local resolved = choice_resolver.resolve(g, pending, action)
    assert(resolved and resolved.status == "resolved", "canonical optional choice should resolve successfully")
    assert(g:player_balance(p, "金币") < before_cash, "canonical optional choice should still execute buy_land")
    assert(_tile_state(g, tile_ref).owner_id == p.id, "canonical optional choice should still purchase land")
  end)

  it("land_actions_execute_strong_card_triggers_event", function()
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
    _with_patches({
      { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
        events[#events + 1] = result
      end },
    }, function()
      land_actions.execute_strong_card(g, p.id, tile_ref.id)
    end)

    assert(#events > 0, "execute_strong_card should trigger land events")
  end)

  it("land_actions_execute_free_card_triggers_event", function()
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
    _with_patches({
      { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
        events[#events + 1] = result
      end },
    }, function()
      land_actions.execute_free_card(g, p.id, tile_ref.id)
    end)

    assert(#events > 0, "execute_free_card should trigger land events")
  end)

  it("land_actions_execute_tax_free_card_triggers_event", function()
    local g = _new_game()
    local p = g:current_player()
    inventory.give(p, item_ids.tax_free, { game = g })
    p.status.pending_tax_free = true

    local events = {}
    _with_patches({
      { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
        events[#events + 1] = result
      end },
    }, function()
      land_actions.execute_tax_free_card(g, p.id)
    end)

    assert(#events > 0, "tax_free with pending status should apply a land event")
  end)

  it("land_actions_execute_pay_rent_queues_cash_anim_for_both_players", function()
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

    assert(ok == true, "execute_pay_rent should succeed")
    assert(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "rent should queue cash_receive anim")
    _assert_eq(g.turn.action_anim.player_id, tenant.id, "rent first anim should play on payer")
    _assert_eq(_action_anim_count(g), 2, "rent should queue one anim per changed player")
    _assert_eq(g.turn.action_anim_queue[1].player_id, owner.id, "rent second anim should play on owner")
  end)

  it("land_actions_execute_pay_rent_bankruptcy_queues_cash_anim_for_both_players", function()
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

    assert(ok == true, "execute_pay_rent should still resolve on bankruptcy")
    assert(tenant.eliminated == true, "rent bankruptcy should eliminate tenant")
    _assert_eq(_action_anim_count(g), 2, "rent bankruptcy should still queue both payer and owner cash anims")
    _assert_eq(g.turn.action_anim.player_id, tenant.id, "rent bankruptcy first anim should play on payer")
    _assert_eq(g.turn.action_anim_queue[1].player_id, owner.id, "rent bankruptcy second anim should play on owner")
  end)

  it("land_actions_safe_tile_state_returns_state", function()
    local g = _new_game()
    local idx, tile_ref = _first_land_tile(g.board)

    local st = land_actions.safe_tile_state(g, tile_ref)

    assert(type(st) == "table", "safe_tile_state should return a table")
    assert(st.owner_id == nil, "safe_tile_state should return nil owner_id for unowned land")
    assert(st.level == 0, "safe_tile_state should return level 0 for unowned land")
  end)

  it("land_actions_resolve_rent_owner_returns_owner", function()
    local g = _new_game()
    local p = g:current_player()
    local idx, tile_ref = _first_land_tile(g.board)
    local owner = g.players[2]
    g:set_tile_owner(tile_ref, owner.id)
    g:set_tile_level(tile_ref, 1)
    g:set_player_property(owner, tile_ref.id, true)
    g:update_player_position(p, idx)

    local resolved_owner, st = land_actions.resolve_rent_owner(g, tile_ref, nil)

    assert(resolved_owner ~= nil, "resolve_rent_owner should return owner for owned land")
    assert(resolved_owner.id == owner.id, "resolve_rent_owner should return correct owner")
  end)

  it("land_actions_resolve_rent_owner_skips_mountain_owner", function()
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
      assert(resolved_owner == nil, "resolve_rent_owner should return nil for mountain owner")
      assert(#events == 1, "resolve_rent_owner should emit rent_skipped_mountain event")
      assert(events[1].event == "rent_skipped_mountain", "event should be rent_skipped_mountain")
    end)
  end)

  it("apply_tax_with_pending_tax_free_skips_payment", function()
    local land = require("src.rules.land.executors")
    local g = _new_game()
    local p = g:current_player()
    g:set_player_cash(p, 10000)
    g:set_player_status(p, "pending_tax_free", true)

    local before_cash = g:player_balance(p, "金币")
    -- Find tax tile
    local tax_idx = nil
    for i = 1, g.board:length() do
      local tile = g.board:get_tile(i)
      if tile and tile.type == "tax" then
        tax_idx = i
        break
      end
    end

    if tax_idx then
      g:update_player_position(p, tax_idx)
      local tile = g.board:get_tile(tax_idx)
      land.executors.tax.apply({ game = g, player = p, tile = tile })
      assert(g:player_balance(p, "金币") == before_cash, "_apply_tax should skip payment when pending_tax_free is set")
      assert(p.status.pending_tax_free == false, "_apply_tax should clear pending_tax_free after use")
    end
  end)

  it("apply_tax_without_tax_free_card_prompts_choice", function()
    local land = require("src.rules.land.executors")
    local g = _new_game()
    local p = g:current_player()
    g:set_player_cash(p, 10000)
    g:set_player_status(p, "pending_tax_free", false)
    inventory.clear(p)

    -- Find tax tile
    local tax_idx = nil
    for i = 1, g.board:length() do
      local tile = g.board:get_tile(i)
      if tile and tile.type == "tax" then
        tax_idx = i
        break
      end
    end

    if tax_idx then
      g:update_player_position(p, tax_idx)
      local tile = g.board:get_tile(tax_idx)
      local res = land.executors.tax.apply({ game = g, player = p, tile = tile })
      -- Should return waiting intent for tax choice when player has tax_free card
      -- or pay tax directly if no card
      assert(res == nil or (type(res) == "table" and res.waiting), "_apply_tax should either pay tax or prompt choice")
    end
  end)

  it("apply_tax_charges_player_even_with_angel", function()
    local land = require("src.rules.land.executors")
    local g = _new_game()
    local p = g:current_player()
    g:set_player_cash(p, 10000)
    g:set_player_deity(p, "angel")

    local tax_idx = assert(g.board:find_first_by_type("tax"), "missing tax tile")
    g:update_player_position(p, tax_idx)
    local tile = g.board:get_tile(tax_idx)
    land.executors.tax.apply({ game = g, player = p, tile = tile })

    _assert_eq(g:player_balance(p, "金币"), 10000 - math.floor(10000 * constants.tax_rate), "angel should not block tax office")
  end)

  it("hospital_and_mountain_detain_player_even_with_angel", function()
    local land = require("src.rules.land.executors")
    local g = _new_game()
    local p = g:current_player()

    g:set_player_deity(p, "angel")
    local hospital_idx = assert(g.board:find_first_by_type("hospital"), "missing hospital")
    g:update_player_position(p, hospital_idx)
    land.executors.hospital.apply({ game = g, player = p, tile = g.board:get_tile(hospital_idx) })
    assert((p.status.stay_turns or 0) > 0, "angel should not block hospital stay")

    g:set_player_status(p, "stay_turns", 0)
    g:set_player_deity(p, "angel")
    local mountain_idx = assert(g.board:find_first_by_type("mountain"), "missing mountain")
    g:update_player_position(p, mountain_idx)
    land.executors.mountain.apply({ game = g, player = p, tile = g.board:get_tile(mountain_idx) })
    assert((p.status.stay_turns or 0) > 0, "angel should not block mountain stay")
  end)
end)
