local support = require("TestSupport")
local _new_game = support.new_game
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _resolve_choice_first = support.resolve_choice_first
local _tile_state = support.tile_state
local _assert_eq = support.assert_eq
local executor = support.executor
local choice_resolver = support.choice_resolver

local function _test_monster_card()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 2)
  p.inventory:add({ id = 2008 })
  local res = executor.use_item(g, p, 2008, { by_ai = true })
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "demolish_target", "monster should open choice")
    _resolve_choice_first(g, pending)
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "monster use ok")
  _assert_eq(_tile_state(g, tile_ref).level, 0, "building destroyed")
end

local function _test_missile_card()
  local g = _new_game()
  local p = g:current_player()
  local idx = 4
  local tile_ref = g.board:get_tile(idx)
  g:set_tile_owner(tile_ref, 2)
  g:set_tile_level(tile_ref, 1)
  g:update_player_position(g.players[2], idx)
  g.board:place_roadblock(idx)
  g.board:place_mine(idx)
  p.inventory:add({ id = 2013 })
  local res = executor.use_item(g, p, 2013, {})
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "demolish_target", "missile should open choice")
    _resolve_choice_first(g, pending)
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "missile use ok")
  _assert_eq(_tile_state(g, tile_ref).level, 0, "building destroyed by missile")
  _assert_eq(g.board:has_roadblock(idx), false, "roadblock cleared")
  _assert_eq(g.board:has_mine(idx), false, "mine cleared")
  assert(g.players[2].status.stay_turns > 0, "target sent to hospital")
end

local function _test_item_equalize_cash()
  local g = _new_game()
  local user = g.players[1]
  local target = g.players[2]
  g:set_player_cash(user, 1000)
  g:set_player_cash(target, 9000)
  user.inventory:add({ id = 2011 })
  local res = executor.use_item(g, user, 2011, { by_ai = true })
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "item_target_player", "equalize should open choice")
    local first = pending.options[1]
    choice_resolver.resolve(g, pending, { option_id = first.id })
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "equalize use ok")
  _assert_eq(user.cash, 5000, "equalize user cash")
  _assert_eq(target.cash, 5000, "equalize target cash")
end

return {
  _test_monster_card,
  _test_missile_card,
  _test_item_equalize_cash,
}
