local support = require("support.domain_support")
local default_map = require("Config.maps.default_map")
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
local choice_registry = require("src.game.systems.choices.registry")
local choice_optional_effect_handler = require("src.game.systems.choices.handlers.optional_effect")
local item_choice_handlers = require("src.game.systems.items.choice_handlers")
local item_executor = require("src.game.systems.items.executor")
local item_phase = require("src.game.systems.items.phase")
local land_choice_handlers = require("src.game.systems.land.choice_handlers")
local landing_defs = require("src.game.systems.land.specs.effects")
local effect_runner = require("src.game.systems.effects.effect_runner")
local market_choice_handlers = require("src.game.systems.market.choice_handlers")

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
    land_choice_handlers.build(helpers),
    item_choice_handlers.build(helpers),
    market_choice_handlers.build(helpers),
  }
end

local function _test_ai_picks_land_purchase()
  local agent = require("src.game.ai.agent")
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
end

local function _test_land_rent_contiguous_sum()
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
end

local function _test_land_rent_graph_adjacency_breaks_path_neighbors()
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
end

local function _test_rent_owner_missing_skips_payment()
  local land = require("src.game.systems.land.executors")
  local g = _new_game()
  local tenant = g.players[1]
  local owner = g.players[2]
  local idx, tile_ref = _first_land_tile(g.board)

  g:set_tile_owner(tile_ref, owner.id)
  g:set_tile_level(tile_ref, 1)
  g:set_player_property(owner, tile_ref.id, true)
  g:update_player_position(tenant, idx)

  g:set_player_status(tenant, "pending_free_rent", true)
  g:player_send_to_mountain(owner)
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
end

local function _test_tax_only_bankrupts_when_balance_depleted()
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

local function _test_choice_resolver_executes_canonical_landing_optional_effect()
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
end

return {
  name = "land",
  tests = {
    { name = "ai_picks_land_purchase", run = _test_ai_picks_land_purchase },
    { name = "land_rent_contiguous_sum", run = _test_land_rent_contiguous_sum },
    { name = "land_rent_graph_adjacency_breaks_path_neighbors", run = _test_land_rent_graph_adjacency_breaks_path_neighbors },
    { name = "rent_owner_missing_skips_payment", run = _test_rent_owner_missing_skips_payment },
    { name = "tax_only_bankrupts_when_balance_depleted", run = _test_tax_only_bankrupts_when_balance_depleted },
    {
      name = "choice_resolver_executes_canonical_landing_optional_effect",
      run = _test_choice_resolver_executes_canonical_landing_optional_effect,
    },
  },
}
