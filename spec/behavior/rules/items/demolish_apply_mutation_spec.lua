-- Mutation-pinning specs for src/rules/items/demolish_apply.lua.
--
-- These tests call demolish_apply DIRECTLY (not through src.rules.items.demolish,
-- which captures `demolish.apply = demolish_apply.apply` by reference at load time
-- and therefore shields the mutated module from the existing closure spec). Only a
-- direct require of demolish_apply exercises the mutated source.
--
-- Surviving mutants targeted here:
--   L12  `... or 1.0` -> `and 1.0`   (killed via timing reload, below)
--   L19  `(st.level or 0) <= 0` `0`->`1` on the boundary (level-1 angel building)
--   L78  `destroyed_owner and kind == "monster"` -> `or`   (missile must not record)
--   L93  `not destroyed` -> `destroyed`   (monster destroy must publish an event)
--
-- Documented EQUIVALENT survivors (no behavior test can kill without breaking
-- correct code — see ADR 0004; do not add false-closure pins):
--   L12  `or`->`and`: in production timing.action_anim_default_seconds == 1.0, so
--         `1.0 or 1.0` == `1.0 and 1.0`. We still KILL it by reloading the module
--         with the field forced nil, making the `or` fallback observable.
--   L19  `st.level or 0` -> `or 1`: tile.get_state never returns a nil level for a
--         land tile (tile init sets level = 0), so the `or` fallback is dead. The
--         *other* `0` on L19 (the `<= 0` boundary) IS killed below.
--   L58  `local hit = 0` -> `= 1`: hit is reassigned in the injure branch before it
--         is ever read, and when injure is false the caller never reads hit (both
--         `not opts.injure or hit == 0` and `opts.injure and hit > 0` short-circuit
--         on opts.injure). The init value is dead.
--   L93  `not opts.injure` removed (the SECOND `not` on the line): when
--         fully_blocked is later observed (only via _finish_demolish_without_injury,
--         reached only when NOT (opts.injure and hit > 0)), hit is always 0 and the
--         `... or hit == 0` clause is already true, so `not opts.injure` vs
--         `opts.injure` produce the same fully_blocked. The FIRST `not` on L93
--         (`not destroyed`) IS killed by the monster-destroy test below.
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local demolish_apply = require("src.rules.items.demolish_apply")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_kinds = require("src.config.gameplay.event_kinds")

local _assert_eq = support.assert_eq
local _tile_state = support.tile_state

local function _game(players)
  return support.new_game({ map = default_map, players = players or { "P1", "P2", "P3", "P4" } })
end

local function _capture_events(game)
  local recorded = {}
  game.event_feed_port = {
    publish = function(_, _, event)
      recorded[#recorded + 1] = event
      return true
    end,
  }
  return recorded
end

local function _first_event(recorded, kind)
  for _, event in ipairs(recorded) do
    if event.kind == kind then
      return event
    end
  end
  return nil
end

local function _enemy_building(game, idx, level)
  local tile = game.board:get_tile(idx)
  game:set_tile_owner(tile, 2)
  game:set_tile_level(tile, level)
  return tile
end

local function _with_anim_gate(game)
  game.ui_port = support.build_ui_port({ wait_action_anim = true })
  game.anim_gate_port = { wait_move_anim = false, wait_action_anim = true }
end

describe("demolish_apply mutation pins (direct module)", function()
  -- L93 `not destroyed` -> `destroyed` -----------------------------------------
  it("monster destroying an enemy building publishes the demolish event (L93 'not destroyed')", function()
    -- destroyed=true, injure=false: original fully_blocked = (not true) and ... = false
    -- -> publishes. Mutant `destroyed and ...` = true -> fully_blocked -> no event.
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 2)
    local recorded = _capture_events(g)

    demolish_apply.apply(g, p, 3, { item_id = item_ids.monster, injure = false })

    _assert_eq(_tile_state(g, tile).level, 0, "building destroyed")
    local event = _first_event(recorded, event_kinds.demolish)
    assert(event ~= nil, "monster destroy must publish a demolish event; L93 'not' removal suppresses it")
    _assert_eq(event.text, p.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑", "monster destroy text")
  end)

  -- L19 `<= 0` boundary `0` -> `1` ---------------------------------------------
  it("monster on a level-1 angel building respects immunity (L19 '<= 0' boundary)", function()
    -- level 1: original `(level or 0) <= 0` is false -> owner-immunity check runs
    -- and protects the building. Mutant `<= 1` short-circuits to destroy, wiping
    -- the level-1 building and publishing a monster destroy event.
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 1)
    g:set_player_deity(g.players[2], "angel", 3)
    local recorded = _capture_events(g)

    demolish_apply.apply(g, p, 3, { item_id = item_ids.monster, injure = false })

    _assert_eq(_tile_state(g, tile).level, 1, "level-1 building is protected by immunity, not destroyed")
    _assert_eq(_first_event(recorded, event_kinds.demolish), nil,
      "fully blocked: no demolish text; the '<= 1' mutant would destroy and publish")
  end)

  -- L78 `destroyed_owner and kind == "monster"` -> `or` ------------------------
  it("missile destroying a building does NOT record a monster-demolish achievement (L78 'and')", function()
    -- destroyed_owner is non-nil (owner not immune) but kind == "missile", so the
    -- monster-demolish achievement must NOT fire. Mutant `or` fires it because
    -- destroyed_owner alone is truthy.
    local g = _game()
    local p = g:current_player()
    _enemy_building(g, 3, 2) -- owner (player 2) is not immune -> destroyed, owner returned
    _capture_events(g)

    local saved = achievement_progress.monster_demolished_building
    local calls = 0
    achievement_progress.monster_demolished_building = function() calls = calls + 1 end

    local ok, err = pcall(function()
      demolish_apply.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })
    end)

    achievement_progress.monster_demolished_building = saved
    assert(ok, "apply must not error: " .. tostring(err))
    _assert_eq(calls, 0,
      "missile kind must not record a monster-demolish; L78 'or' mutation fires it on destroyed_owner alone")
  end)

  it("monster destroying a building DOES record the monster-demolish achievement (L78 kind match)", function()
    -- Positive side of L78: kind == "monster" AND destroyed_owner set -> record.
    -- Pins that the achievement is wired at all (guards against the 'and'->'or'
    -- degenerating both branches to the same observable in a single scenario).
    local g = _game()
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    _capture_events(g)

    local saved = achievement_progress.monster_demolished_building
    local calls = 0
    achievement_progress.monster_demolished_building = function() calls = calls + 1 end

    demolish_apply.apply(g, p, 3, { item_id = item_ids.monster, injure = false })

    achievement_progress.monster_demolished_building = saved
    _assert_eq(calls, 1, "monster destroying an owned building records exactly one achievement")
  end)

  -- L12 `... or 1.0` -> `and 1.0` (reload to make the fallback observable) ------
  it("action_anim duration falls back to 1.0 when config seconds is nil (L12 'or 1.0')", function()
    -- Reload demolish_apply with timing.action_anim_default_seconds forced nil.
    -- Original `nil or 1.0` = 1.0 (queued anim duration 1.0). Mutant `nil and 1.0`
    -- = nil (queued anim duration nil).
    local timing_name = "src.config.gameplay.timing"
    local apply_name = "src.rules.items.demolish_apply"
    local saved_timing = package.loaded[timing_name]
    local saved_apply = package.loaded[apply_name]

    local real_timing = require(timing_name)
    local mock = {}
    for k, v in pairs(real_timing) do mock[k] = v end
    mock.action_anim_default_seconds = nil -- force the `or` fallback

    package.loaded[timing_name] = mock
    package.loaded[apply_name] = nil
    local reloaded = require(apply_name)

    local ok, err = pcall(function()
      local g = _game()
      local p = g:current_player()
      _with_anim_gate(g)
      _enemy_building(g, 3, 2)
      _capture_events(g)
      reloaded.apply(g, p, 3, { item_id = item_ids.monster, injure = false })
      _assert_eq(g.turn.action_anim.duration, 1.0,
        "nil config seconds must fall back to 1.0 via `or`; the `and` mutant yields nil")
    end)

    package.loaded[apply_name] = saved_apply
    package.loaded[timing_name] = saved_timing
    if not ok then error(err) end
  end)
end)
