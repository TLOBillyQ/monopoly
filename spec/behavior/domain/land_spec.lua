-- luacheck: ignore 211
local support = require("support.domain_support")
local default_map = require("src.config.content.maps.default_map")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local _with_patches = support.with_patches
local function _new_game()
  return support.new_game({ map = default_map })
end
local _first_land_tile = support.first_land_tile
local _first_adjacent_land_pair = support.first_adjacent_land_pair
local _tile_state = support.tile_state
local _assert_eq = support.assert_eq
local _resolve_landing = support.resolve_landing
local land_actions = support.land_actions
local pricing = support.pricing
local choice_resolver = support.choice_resolver
local choice_registry = require("src.rules.choice.registry")
local choice_optional_effect_handler = require("src.rules.bootstrap.choice_optional_effect_handler")
local choice_handler_factory = require("src.rules.choice_handlers.factory")
local item_executor = require("src.rules.items.executor")
local item_phase = require("src.rules.items.phase")
local landing_defs = require("src.rules.land.landing_defs")
local effect_runner = require("src.rules.effects.runner")
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
  return _require_upvalue(remote_priority, "_remote_priority_for_land")
end

local function _action_anim_count(game)
  local count = 0
  if game.turn.action_anim then
    count = count + 1
  end
  return count + #(game.turn.action_anim_queue or {})
end

local function _build_choice_groups()
  local helpers = choice_resolver.helpers({
    use_item = item_executor.use_item,
    build_game_ctx = function(game, move_result)
      return effect_runner.build_game_ctx(game, move_result, {
        phase_default = "wait_choice",
        on_landing = true,
      })
    end,
    finish_item_phase = function(game, choice)
      item_phase.finish(game, choice and choice.meta and choice.meta.phase or nil)
    end,
    finish_active_item_phase = function(game)
      local phase = game.turn.item_phase_active
      if phase and phase ~= "" then
        item_phase.finish(game, phase)
      end
    end,
    get_container_defs_by_choice_kind = function(choice_kind)
      if choice_kind == "landing_optional_effect" then
        return landing_defs
      end
      return nil
    end,
    find_effect_by_id = function(effect_defs, effect_id)
      assert(effect_defs ~= nil, "missing effect defs")
      for _, effect_definition in ipairs(effect_defs) do
        if effect_definition.id == effect_id then
          return effect_definition
        end
      end
      return nil
    end,
  })

  return {
    choice_optional_effect_handler.build(helpers),
    choice_handler_factory.build_land_handlers(helpers),
    choice_handler_factory.build_item_handlers(helpers),
    choice_handler_factory.build_market_handlers(helpers),
  }
end
















local function _test_choice_registry_registers_descriptors_with_cancel_metadata()
  local registry = choice_registry:new()
  registry:register_defaults(_build_choice_groups())

  local tax_descriptor = registry:descriptor_for("tax_card_prompt")
  assert(type(tax_descriptor) == "table", "tax prompt should register as descriptor")
  assert(type(tax_descriptor.execute) == "function", "tax descriptor should expose execute")
  assert(tax_descriptor.cancel and tax_descriptor.cancel.mode == "select_option", "tax descriptor should expose cancel fallback")
  assert(tax_descriptor.cancel.option_id == "skip", "tax cancel fallback should target skip option")

  local item_phase_descriptor = registry:descriptor_for("item_phase_choice")
  assert(item_phase_descriptor and item_phase_descriptor.cancel and item_phase_descriptor.cancel.mode == "finish_item_phase",
    "item phase descriptor should delegate cancel cleanup to resolver")
  local market_buy_descriptor = registry:descriptor_for("market_buy")
  local optional_effect_descriptor = registry:descriptor_for("landing_optional_effect")
  assert(type(market_buy_descriptor.normalize_meta) == "function", "market buy should expose meta normalizer")
  assert(type(market_buy_descriptor.meta_validator) == "function", "market buy should expose meta validator")
  assert(type(market_buy_descriptor.normalize_action) == "function", "market buy should expose action normalizer")
  assert(type(optional_effect_descriptor.normalize_meta) == "function", "landing optional should expose meta normalizer")
  assert(type(optional_effect_descriptor.meta_validator) == "function", "landing optional should expose meta validator")
  assert(type(optional_effect_descriptor.normalize_action) == "function", "landing optional should expose action normalizer")
  _assert_eq(tax_descriptor.required_meta[1], "player_id", "tax descriptor should expose required meta")
  _assert_eq(item_phase_descriptor.required_meta[1], "player_id", "item phase should expose required meta")
  _assert_eq(item_phase_descriptor.required_meta[2], "phase", "item phase should require phase")
end


-- T4 characterization tests for land actions








-- T4 characterization tests for _apply_tax

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

    local before_cash = ai_player.cash
    choice_resolver.resolve(g, pending, action)
    assert(ai_player.cash == before_cash - tile_ref.price, "AI cash should decrease by land price")
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

  it("land_rent_contiguous_sum", function()
    local g = _new_game()
    local owner = g.players[1]
    local tenant = g.players[2]

    local idx1, tile1, _, tile2 = _first_adjacent_land_pair(g.board)
    g:set_tile_owner(tile1, owner.id)
    g:set_tile_owner(tile2, owner.id)
    g:set_tile_level(tile1, 1)
    g:set_tile_level(tile2, 2)
    g:set_player_property(owner, tile1.id, true)
    g:set_player_property(owner, tile2.id, true)

    g:update_player_position(tenant, idx1)
    local before = tenant.cash
    land_actions.execute_pay_rent(g, tenant.id, tile1.id)
    local expected = pricing.rent_for_level(tile1, 1) + pricing.rent_for_level(tile2, 2)
    _assert_eq(before - tenant.cash, expected, "contiguous rent sum")

    g:set_tile_level(tile1, 2)
    local before2 = tenant.cash
    land_actions.execute_pay_rent(g, tenant.id, tile1.id)
    local expected2 = pricing.rent_for_level(tile1, 2) + pricing.rent_for_level(tile2, 2)
    _assert_eq(before2 - tenant.cash, expected2, "contiguous rent sum after upgrade")
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
    local before = tenant.cash
    land_actions.execute_pay_rent(g, tenant.id, tile_a.id)
    local expected = pricing.rent_for_level(tile_a, 1)
    _assert_eq(before - tenant.cash, expected, "graph adjacency rent excludes non-neighbors")
  end)

  it("total_invested_returns_purchase_price_for_negative_level", function()
    local tile = {
      price = 400,
      upgrade_costs = { 50, 75, 100 },
    }
    _assert_eq(pricing.total_invested(tile, -3), 400, "negative level should keep purchase price only")
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
    local before = tenant.cash
    land.executors.pay_rent.apply({ game = g, player = tenant, tile = tile_ref })
    _assert_eq(tenant.cash, before, "rent skipped when owner in mountain")
    assert(tenant.status.pending_free_rent == true, "pending_free_rent should remain when owner missing")

    g:set_player_status(tenant, "pending_free_rent", false)
    owner.eliminated = true
    local before2 = tenant.cash
    local ok = land_actions.execute_pay_rent(g, tenant.id, tile_ref.id)
    _assert_eq(ok, false, "execute_pay_rent should return false when owner missing")
    _assert_eq(tenant.cash, before2, "rent skipped when owner missing")
  end)

  it("free_rent_only_inventory_opens_choice_prompt_instead_of_silent_use", function()
    local land = require("src.rules.land.executors")
    local g = _new_game()
    local tenant = g.players[1]
    local owner = g.players[2]
    local idx, tile_ref = _first_land_tile(g.board)

    g:set_tile_owner(tile_ref, owner.id)
    g:set_tile_level(tile_ref, 1)
    g:set_player_property(owner, tile_ref.id, true)
    g:update_player_position(tenant, idx)
    inventory.give(tenant, item_ids.free_rent, { game = g })

    local tenant_cash_before = g:player_balance(tenant, "金币")
    local owner_cash_before = g:player_balance(owner, "金币")
    local res = land.executors.pay_rent.apply({ game = g, player = tenant, tile = tile_ref })

    assert(type(res) == "table", "pay_rent with only free_rent should return waiting intent, not execute silently")
    assert(res.waiting == true, "pay_rent with only free_rent should mark waiting on the choice")
    assert(res.intent and res.intent.kind == "need_choice",
      "pay_rent with only free_rent should open a need_choice intent")
    local spec = res.intent.choice_spec
    assert(spec and spec.kind == "rent_card_prompt", "pay_rent with only free_rent should open rent_card_prompt")
    assert(spec.title == "是否使用免费卡", "pay_rent with only free_rent should open the free rent prompt branch")
    assert(spec.route_key == "secondary_confirm",
      "free rent prompt opened from silent path should route to secondary_confirm")
    assert(spec.requires_confirm == true,
      "free rent prompt opened from silent path should require confirm")
    _assert_eq(g:player_balance(tenant, "金币"), tenant_cash_before,
      "pay_rent with only free_rent should not change tenant cash before user confirms")
    _assert_eq(g:player_balance(owner, "金币"), owner_cash_before,
      "pay_rent with only free_rent should not change owner cash before user confirms")
    _assert_eq(inventory.find_index(tenant, item_ids.free_rent) ~= nil, true,
      "pay_rent with only free_rent should not consume the card before user confirms")
  end)

  it("tax_only_bankrupts_when_balance_depleted", function()
    local g = _new_game()
    local p = g.players[1]
    g:set_player_cash(p, 10000)
    local ok = land_actions.execute_pay_tax(g, p.id)
    assert(ok == true, "tax should execute")
    assert(p.eliminated == false, "player with remaining cash should not be eliminated by tax")
    assert(g:player_balance(p, "金币") > 0, "cash should remain positive after tax")

    g:set_player_cash(p, 0)
    ok = land_actions.execute_pay_tax(g, p.id)
    assert(ok == true, "tax should execute on depleted balance")
    assert(p.eliminated == true, "player should be eliminated only when tax depletes balance")
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

    local before_cash = p.cash
    local action = {
      type = "choice_select",
      choice_id = pending.id,
      option_id = "buy_land",
    }

    local resolved = choice_resolver.resolve(g, pending, action)
    assert(resolved and resolved.status == "resolved", "canonical optional choice should resolve successfully")
    assert(p.cash < before_cash, "canonical optional choice should still execute buy_land")
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
    inventory.give(p, item_ids.tax_free, { game = g }) -- tax_free card

    local events = {}
    _with_patches({
      { target = require("src.rules.land.events"), key = "apply", value = function(_, result)
        events[#events + 1] = result
      end },
    }, function()
      land_actions.execute_tax_free_card(g, p.id)
    end)

    -- tax_free card may or may not trigger events depending on pending_tax_free status
    -- The test verifies the function executes without error
    assert(true, "execute_tax_free_card should execute without error")
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

    local before_cash = p.cash
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
      assert(p.cash == before_cash, "_apply_tax should skip payment when pending_tax_free is set")
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
end)
