local support = require("TestSupport")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _resolve_landing = support.resolve_landing
local _resolve_choice_first = support.resolve_choice_first
local _get_choice = support.get_choice
local _first_land_tile = support.first_land_tile
local _first_tile_by_type = support.first_tile_by_type
local _tile_state = support.tile_state
local _with_patches = support.with_patches
local turn_land = require("src.game.turn.TurnLand")

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
  g.ui_port = _build_ui_port()
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
  g.ui_port = _build_ui_port()
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
  g.ui_port = _build_ui_port({ wait_action_anim = true })
  local p = g:current_player()
  local idx, tile_ref = _first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)
  local old_lua_api = LuaAPI
  local patched = old_lua_api or {}
  _with_patches({
    { key = "LuaAPI", value = patched },
    { target = patched, key = "rand", value = function() return 0 end },
  }, function()
    local next_state, _ = turn_land({ game = g }, { player = p, move_result = {} })
    assert(next_state == "wait_action_anim", "chance landing should bridge to wait_action_anim")
    assert(g.turn.action_anim and g.turn.action_anim.kind == "chance", "chance action anim should be queued")
  end)
end

return {
  _test_land_on_start_reward,
  _test_pass_players_without_steal_does_not_crash,
  _test_landing_optional_waits_with_ui,
  _test_landing_optional_waits_without_ui_and_can_resolve,
  _test_landing_optional_stale_choice_is_blocked,
  _test_zero_cash_no_buy_choice,
  _test_turn_land_bridges_to_wait_action_anim_for_chance,
}
