-- Mutation-closure pins for src/rules/effects/mine.lua.
-- mine_effect_spec already pins _find_pending_roadblock_trigger; this file
-- covers the remaining survivors in can_trigger / _is_mine_grace_expired
-- (armed gate, owner/grace boundary) and apply (angel-immune short circuit,
-- the hospital relocation return shape, the queued mine_trigger payload, and
-- the obstacle-chain tip fields built via _build_obstacle_chain_key /
-- _build_chain_tip_text). Routed by architect
-- (agent_context/rules-mutation-bootstrap-debt.md).
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local timing = require("src.config.gameplay.timing")
local mine_effect = require("src.rules.effects.mine")

local _assert_eq = support.assert_eq
local _anim_duration = timing.action_anim_default_seconds or 1.0

local function _game(players)
  return support.new_game({ map = default_map, players = players or { "P1", "P2" } })
end

-- Locate a queued action anim of the given kind. apply queues through
-- action_anim_port, which lands the payload either in turn.action_anim (when
-- that slot is free) or in turn.action_anim_queue (when an entry already
-- occupies the current slot, e.g. a pending roadblock_trigger).
local function _find_action_anim(game, kind)
  local turn = game.turn
  if turn.action_anim and turn.action_anim.kind == kind then
    return turn.action_anim
  end
  for _, entry in ipairs(turn.action_anim_queue or {}) do
    if entry.kind == kind then
      return entry
    end
  end
  return nil
end

describe("mine_effect.can_trigger / grace boundary closure", function()
  local config_reset = require("spec.support.config_reset")
  before_each(function() config_reset.reset_all() end)

  it("returns false when the game has no board", function()
    _assert_eq(mine_effect.can_trigger({}, { id = 1 }, 3), false, "no board cannot trigger")
  end)

  it("returns false when the position is nil", function()
    local g = _game()
    _assert_eq(mine_effect.can_trigger(g, g.players[1], nil), false, "nil position cannot trigger")
  end)

  it("returns false when there is no mine at the position", function()
    local g = _game()
    _assert_eq(mine_effect.can_trigger(g, g.players[1], 3), false, "an empty tile cannot trigger")
  end)

  it("a non-table mine overlay always triggers", function()
    local g = _game()
    g:place_mine(3) -- nil data stores a bare `true`, not a table
    _assert_eq(mine_effect.can_trigger(g, g.players[1], 3), true,
      "a legacy boolean mine bypasses the armed/grace checks")
  end)

  it("a disarmed mine never triggers even when grace has expired", function()
    local g = _game()
    local p = g.players[1]
    -- owner mismatch would otherwise expire grace and trigger; the armed gate
    -- must short-circuit first.
    g:place_mine(3, { armed = false, owner_id = p.id + 100 })
    _assert_eq(mine_effect.can_trigger(g, p, 3), false, "armed == false blocks the trigger")
  end)

  it("a mine owned by another player triggers immediately", function()
    local g = _game()
    local p = g.players[1]
    g:place_mine(3, { armed = true, owner_id = p.id + 100,
      owner_turn_started_count_at_placement = 5 })
    g:set_player_status(p, "own_turn_started_count", 0)
    _assert_eq(mine_effect.can_trigger(g, p, 3), true,
      "a foreign owner expires grace regardless of turn counts")
  end)

  it("a nil triggering player expires grace and triggers", function()
    local g = _game()
    g:place_mine(3, { armed = true, owner_id = 1,
      owner_turn_started_count_at_placement = 5 })
    _assert_eq(mine_effect.can_trigger(g, nil, 3), true,
      "a missing player short-circuits the owner check to expired")
  end)

  it("an owner's mine with no placement count triggers (grace unknown)", function()
    local g = _game()
    local p = g.players[1]
    g:place_mine(3, { armed = true, owner_id = p.id }) -- no placement count
    _assert_eq(mine_effect.can_trigger(g, p, 3), true,
      "a nil placement count is treated as expired grace")
  end)

  it("the owner is still protected exactly one own-turn after placement", function()
    local g = _game()
    local p = g.players[1]
    g:place_mine(3, { armed = true, owner_id = p.id,
      owner_turn_started_count_at_placement = 5 })
    g:set_player_status(p, "own_turn_started_count", 6) -- placement + 1: grace still holds
    _assert_eq(mine_effect.can_trigger(g, p, 3), false,
      "own_count == placement + 1 is not yet expired (the > boundary holds)")
  end)

  it("the owner's grace expires two own-turns after placement", function()
    local g = _game()
    local p = g.players[1]
    g:place_mine(3, { armed = true, owner_id = p.id,
      owner_turn_started_count_at_placement = 5 })
    g:set_player_status(p, "own_turn_started_count", 7) -- placement + 2: grace has lapsed
    _assert_eq(mine_effect.can_trigger(g, p, 3), true,
      "own_count > placement + 1 expires the owner's grace")
  end)
end)

describe("mine_effect.apply closure", function()
  local config_reset = require("spec.support.config_reset")
  before_each(function() config_reset.reset_all() end)

  it("an angel-immune victim defuses the mine without hospitalization", function()
    local g = _game()
    local p = g.players[1]
    g:set_player_deity(p, "angel", 3)
    g:place_mine(3, { armed = true })
    local position_before = p.position

    local res = mine_effect.apply(g, p, 3)

    _assert_eq(res.detonated, true, "the mine still counts as detonated")
    _assert_eq(res.protected, true, "the angel protection flag is set")
    _assert_eq(res.hospitalized, nil, "a protected victim is not hospitalized")
    _assert_eq(g.board:has_mine(3), false, "the mine is cleared")
    _assert_eq(p.position, position_before, "a protected victim is not relocated")
  end)

  it("a normal trigger clears the mine, hospitalizes the victim, and queues the blast", function()
    local g = _game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    local p = g.players[1]
    g:place_mine(3, { armed = true })
    local hospital = g.board:find_first_by_type("hospital")

    local res = mine_effect.apply(g, p, 3)

    _assert_eq(g.board:has_mine(3), false, "the mine is cleared")
    _assert_eq(res.detonated, true, "result is detonated")
    _assert_eq(res.hospitalized, true, "result is hospitalized")
    _assert_eq(res.wait_action_anim, true, "the caller waits on the blast anim")
    _assert_eq(res.new_position, hospital, "the victim's new position is the hospital")
    _assert_eq(res.next_state, "move_followup", "the followup routes through move_followup")
    _assert_eq(res.next_args.mode, "apply_location_effects", "the followup applies location effects")
    _assert_eq(res.next_args.next_state, "end_turn", "the location followup ends the turn")
    _assert_eq(res.next_args.effects[1].player_id, p.id, "the location effect targets the victim")
    _assert_eq(res.next_args.effects[1].effect, "hospital", "the location effect is a hospital stay")
    _assert_eq(res.next_args.log_entries[1], p.name .. "触发地雷", "the log entry names the victim")

    _assert_eq(p.position, hospital, "the victim is relocated to the hospital")
    _assert_eq(p.status.pending_location_effect, "hospital", "a pending hospital effect is flagged")

    local anim = _find_action_anim(g, "mine_trigger")
    assert(anim ~= nil, "a mine_trigger anim is queued")
    _assert_eq(anim.player_id, p.id, "the anim carries the victim id")
    _assert_eq(anim.tile_index, 3, "the anim records the mine tile")
    _assert_eq(anim.from_index, 3, "the blast originates at the mine tile")
    _assert_eq(anim.to_index, hospital, "the blast carries the victim to the hospital")
    _assert_eq(anim.cue_name, "mine_blast", "the blast cue is mine_blast")
    _assert_eq(anim.duration, _anim_duration, "the blast uses the default action-anim duration")
    _assert_eq(anim.tip_policy, nil, "a non-chained blast carries no tip policy")
    _assert_eq(anim.tip_source, nil, "a non-chained blast carries no tip source")
    _assert_eq(anim.dedupe_key, nil, "a non-chained blast carries no dedupe key")
    _assert_eq(anim.chain_key, nil, "a non-chained blast carries no chain key")
    _assert_eq(anim.focus_text, nil, "a non-chained blast carries no focus text")
  end)

  it("a mine chained off a pending roadblock stamps the obstacle-chain tip", function()
    local g = _game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    local p = g.players[1]
    g:place_mine(3, { armed = true })
    g.turn.turn_count = 5
    g.turn.action_anim = { kind = "roadblock_trigger", player_id = p.id, tile_index = 3 }
    local tile = g.board:get_tile(3)

    mine_effect.apply(g, p, 3)

    local anim = _find_action_anim(g, "mine_trigger")
    assert(anim ~= nil, "the chained blast is queued behind the roadblock trigger")
    _assert_eq(anim.tip_policy, "user", "a chained blast surfaces a user tip")
    _assert_eq(anim.tip_source, "obstacle_chain", "the tip is sourced from the obstacle chain")
    _assert_eq(anim.chain_key, "5:" .. tostring(p.id) .. ":3",
      "the chain key folds turn_count, player id, and position")
    _assert_eq(anim.dedupe_key, "obstacle_chain:5:" .. tostring(p.id) .. ":3",
      "the dedupe key prefixes the chain key")
    _assert_eq(anim.focus_text, p.name .. " 在 " .. tile.name .. "踩中地雷",
      "the focus text names the victim and the tile")
  end)

  it("a chained mine with no turn_count falls back to a zero chain key", function()
    local g = _game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    local p = g.players[1]
    g:place_mine(3, { armed = true })
    g.turn.turn_count = nil
    g.turn.action_anim = { kind = "roadblock_trigger", player_id = p.id, tile_index = 3 }

    mine_effect.apply(g, p, 3)

    local anim = _find_action_anim(g, "mine_trigger")
    assert(anim ~= nil, "the chained blast is queued")
    _assert_eq(anim.dedupe_key, "obstacle_chain:0:" .. tostring(p.id) .. ":3",
      "a missing turn_count defaults the chain key's turn segment to 0")
  end)
end)
