-- Mutation-closure pins for src/rules/items/demolish.lua.
-- Each test fixes an observable branch/boundary so operator, literal, and
-- return-value mutations in demolish.lua are killed by the behavior lane.
-- Routed by architect (agent_context/rules-mutation-bootstrap-debt.md).
--
-- Behavior-lane mutation: 148/155 killed. The 7 remaining survivors are
-- IRREDUCIBLE EQUIVALENT / dead-guard mutations that no behavior test can kill
-- without breaking correct code — so demolish.lua cannot reach a *recorded*
-- 100% (the engine only persists a manifest at zero survivors). These are NOT
-- coverage debt; do not add false-closure pins for them. (See ADR 0004
-- equivalence tension; agent_context/rules-mutation-bootstrap-debt.md.)
--   L14  `... or 1.0`   -> `and`: timing default is 1.0, so `1.0 or 1.0` == `1.0 and 1.0`.
--   L23  `st.level or 0`-> `or 1`: an owned tile's level defaults to 0, never nil,
--                                   so the `or` fallback is never taken.
--   L122 `value < 0`    -> `<= 0` / `< 1`: find_best_tile returns -1 or a positive
--                                   investment; value is never in [0, 1), so the
--                                   boundary shift is unobservable.
--   L155 `local hit = 0`-> `= 1`: reassigned in the injure branch and never read
--                                   when injure is false; the init value is dead.
--   L162 `not opts.injure` removed: when this guard is reached, hit is always 0
--                                   (hit>0 early-returns above), so `not injure`
--                                   vs `injure` yield the same fully_blocked.
--   L201 `idx == player.position` -> `and`: candidates exclude the start tile and
--                                   find_target excludes self, so position is never
--                                   a candidate; the guard is unreachable.
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local demolish = require("src.rules.items.demolish")
local event_kinds = require("src.config.gameplay.event_kinds")

local _assert_eq = support.assert_eq
local _tile_state = support.tile_state

local function _game(players)
  return support.new_game({ map = default_map, players = players or { "P1", "P2", "P3", "P4" } })
end

-- Replace the event feed port with a recorder so published demolish text is
-- observable. demolish publishes through game.event_feed_port:publish(game, event).
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

describe("demolish closure", function()
  -- demolish.find_target / score_fn boundaries -----------------------------

  it("find_target picks the highest invested enemy building in range", function()
    local g = _game()
    local p = g:current_player()
    _enemy_building(g, 3, 1) -- lower invested
    _enemy_building(g, 4, 3) -- higher invested
    _assert_eq(demolish.find_target(g, p, 10), 4, "should target the more valuable building")
  end)

  it("find_target returns nil when no enemy building exists", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _assert_eq(demolish.find_target(g, p, 10), nil, "no eligible tile -> nil")
  end)

  it("find_target skips the player's own land", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    local tile = g.board:get_tile(3)
    g:set_tile_owner(tile, p.id) -- owned by acting player
    g:set_tile_level(tile, 3)
    _assert_eq(demolish.find_target(g, p, 10), nil, "own land must not be a target")
  end)

  it("find_target skips enemy land with no building (level 0)", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _enemy_building(g, 3, 0)
    _assert_eq(demolish.find_target(g, p, 10), nil, "level 0 land must not be a target")
  end)

  -- demolish.apply + _build_demolish_msg (missile / injure branch) ----------

  it("missile destroying a vacant building omits the casualty suffix", function()
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 2, 2)
    local recorded = _capture_events(g)

    local res = demolish.apply(g, p, 2, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    _assert_eq(res.ok, true, "missile apply succeeds")
    _assert_eq(_tile_state(g, tile).level, 0, "building destroyed")
    local event = _first_event(recorded, event_kinds.demolish)
    assert(event ~= nil, "missile should publish a demolish event when nobody is hit")
    _assert_eq(
      event.text,
      p.name .. " 发射导弹轰炸 " .. tile.name .. "，建筑被摧毁",
      "hit==0 must not append the casualty suffix"
    )
  end)

  it("missile blocked by an angel owner keeps the casualty suffix but drops the destroy clause", function()
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 2)
    g:set_player_deity(g.players[2], "angel", 3) -- owner immune -> building survives
    g:update_player_position(g.players[3], 3) -- a non-immune occupant gets hit
    local recorded = _capture_events(g)

    local res = demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    _assert_eq(res.ok, true, "missile apply succeeds")
    _assert_eq(_tile_state(g, tile).level, 2, "angel-protected building is not destroyed")
    local event = _first_event(recorded, event_kinds.demolish)
    assert(event ~= nil, "missile should publish a demolish event for the casualty")
    _assert_eq(
      event.text,
      p.name .. " 发射导弹轰炸 " .. tile.name .. "，1 名玩家送医",
      "no destroy means no '建筑被摧毁' clause, but the casualty suffix stays"
    )
  end)

  it("missile without an anim gate relocates the occupant immediately, no followup", function()
    local g = _game()
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    local occupant = g.players[2]
    g:update_player_position(occupant, 3)
    _capture_events(g)

    local res = demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    _assert_eq(res.ok, true, "missile apply succeeds")
    _assert_eq(res.after_action_anim, nil, "no anim gate means no deferred followup")
    _assert_eq(occupant.position, g.board:find_first_by_type("hospital"), "occupant relocates to hospital now")
    assert((occupant.status.stay_turns or 0) > 0, "hospital stay applied immediately without a gate")
  end)

  it("missile with an anim gate defers via followup and carries target ids", function()
    local g = _game({ "P1", "P2", "P3" })
    g.ui_port = support.build_ui_port({ wait_action_anim = true })
    g.anim_gate_port = { wait_move_anim = false, wait_action_anim = true }
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    g:update_player_position(g.players[2], 3)

    local res = demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    local anim = g.turn.action_anim
    assert(anim and anim.kind == "missile", "missile queues a missile anim")
    _assert_eq(#(anim.target_player_ids or {}), 1, "exactly one casualty is carried on the anim")
    _assert_eq(anim.target_player_ids[1], g.players[2].id, "the occupant id is carried")
    assert(res.after_action_anim ~= nil, "anim gate defers hospital effects to the followup")
    _assert_eq(res.after_action_anim.next_state, "move_followup", "followup routes through move_followup")
  end)

  -- demolish.apply + _build_demolish_msg (monster / non-injure branch) ------

  it("monster destroying an enemy building publishes the monster destroy text", function()
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 2)
    local recorded = _capture_events(g)

    demolish.apply(g, p, 3, { item_id = item_ids.monster, injure = false })

    _assert_eq(_tile_state(g, tile).level, 0, "building destroyed")
    local event = _first_event(recorded, event_kinds.demolish)
    assert(event ~= nil, "monster should publish a demolish event")
    _assert_eq(event.text, p.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑", "monster destroy text")
  end)

  it("monster fully blocked by an angel publishes no demolish event", function()
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 2)
    g:set_player_deity(g.players[2], "angel", 3)
    local recorded = _capture_events(g)

    demolish.apply(g, p, 3, { item_id = item_ids.monster, injure = false })

    _assert_eq(_tile_state(g, tile).level, 2, "angel-protected building survives")
    _assert_eq(_first_event(recorded, event_kinds.demolish), nil, "fully blocked: no demolish text published")
  end)

  it("monster destroys owned-but-empty land before checking immunity", function()
    -- owner present + level 0 takes the (level<=0) short circuit: destroyed,
    -- never reaching the angel-immunity check. Pins the <= boundary.
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 0)
    g:set_player_deity(g.players[2], "angel", 3) -- immune, but must be bypassed
    local recorded = _capture_events(g)

    demolish.apply(g, p, 3, { item_id = item_ids.monster, injure = false })

    local event = _first_event(recorded, event_kinds.demolish)
    assert(event ~= nil, "empty owned land is destroyed without an immunity check")
    _assert_eq(event.text, p.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑", "monster destroy text")
    _assert_eq(_first_event(recorded, event_kinds.item_immune), nil, "immunity branch is bypassed for empty land")
  end)

  -- demolish.use dispatch --------------------------------------------------

  it("use returns false when there is no target", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    local res = demolish.use(g, p, 3, function() return true end, { item_id = item_ids.monster, by_ai = true })
    _assert_eq(res, false, "no target -> false")
  end)

  it("human use opens a demolish choice excluding the current tile", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    local choice = demolish.use(g, p, 3, nil, { item_id = item_ids.monster, injure = false, title = "怪兽卡" })
    assert(choice and choice.waiting, "human use waits on a choice")
    local spec = choice.intent and choice.intent.choice_spec
    assert(spec and spec.kind == "demolish_target", "opens demolish_target choice")
    local ids = {}
    for _, option in ipairs(spec.options) do ids[option.id] = true end
    assert(ids[3], "the enemy building is offered")
    _assert_eq(ids[p.position], nil, "the acting player's own tile is never offered")
  end)

  it("ai use consumes the item then applies the demolition", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 2)
    local consumed
    local res = demolish.use(g, p, 3, function(_, id) consumed = id; return true end,
      { item_id = item_ids.monster, injure = false, by_ai = true })
    _assert_eq(consumed, item_ids.monster, "consume_fn is called with the item id")
    assert(type(res) == "table" and res.ok == true, "ai use applies and reports ok")
    _assert_eq(_tile_state(g, tile).level, 0, "building destroyed by ai use")
  end)

  it("ai use aborts without applying when consume fails", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 2)
    local res = demolish.use(g, p, 3, function() return false end,
      { item_id = item_ids.monster, injure = false, by_ai = true })
    _assert_eq(res, false, "failed consume -> false")
    _assert_eq(_tile_state(g, tile).level, 2, "building untouched when consume fails")
  end)
end)

describe("demolish closure — human choice spec / immune filter / anim patch", function()
  -- _build_human_demolish_choice spec fields (route_key, title, cancel) -----

  it("human choice carries the demolish_target route key and cancel affordance", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    local choice = demolish.use(g, p, 3, nil, { item_id = item_ids.monster, injure = false, title = "怪兽卡" })
    local spec = choice.intent.choice_spec
    _assert_eq(spec.route_key, "target", "route_key pins the dispatch key")
    _assert_eq(spec.allow_cancel, true, "human demolish choice is cancelable")
    _assert_eq(spec.cancel_label, "取消", "cancel label text is pinned")
    _assert_eq(spec.title, "怪兽卡：选择目标格子", "explicit title flows into the choice title")
  end)

  it("human choice falls back to the default title when opts.title is absent", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    local choice = demolish.use(g, p, 3, nil, { item_id = item_ids.monster, injure = false })
    _assert_eq(
      choice.intent.choice_spec.title,
      "选择目标：选择目标格子",
      "nil title resolves to the '选择目标' default"
    )
  end)

  -- _is_demolishable_tile exclusions (position / owner / level boundaries) --

  it("human choice excludes the tile under the acting player even if enemy-owned", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    g:update_player_position(p, 3) -- acting player stands on an enemy building
    _enemy_building(g, 4, 2) -- a different in-range target keeps the choice open
    local choice = demolish.use(g, p, 3, nil, { item_id = item_ids.monster, injure = false })
    local ids = {}
    for _, option in ipairs(choice.intent.choice_spec.options) do ids[option.id] = true end
    _assert_eq(ids[3], nil, "idx == player.position is excluded (the 'or position' guard)")
    assert(ids[4], "a separate in-range enemy building is still offered")
  end)

  it("human choice excludes self-owned land and building-less enemy land", function()
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    -- pick three distinct land tiles (away from the player) for the three roles
    local lands = {}
    for idx = 1, 60 do
      local tile = g.board:get_tile(idx)
      if tile and tile.type == "land" and idx ~= p.position then
        lands[#lands + 1] = idx
        if #lands == 3 then break end
      end
    end
    assert(#lands == 3, "map must expose three land tiles")
    local self_idx, empty_idx, target_idx = lands[1], lands[2], lands[3]

    local own = g.board:get_tile(self_idx)
    g:set_tile_owner(own, p.id)
    g:set_tile_level(own, 3) -- owned by the acting player
    _enemy_building(g, empty_idx, 0) -- enemy land with no building
    _enemy_building(g, target_idx, 2) -- valid target

    local choice = demolish.use(g, p, 60, nil, { item_id = item_ids.monster, injure = false })
    local ids = {}
    for _, option in ipairs(choice.intent.choice_spec.options) do ids[option.id] = true end
    _assert_eq(ids[self_idx], nil, "self-owned land excluded (owner ~= player.id clause)")
    _assert_eq(ids[empty_idx], nil, "level-0 enemy land excluded (level > 0 clause)")
    assert(ids[target_idx], "the valid enemy building is offered")
  end)

  -- _collect_hospital_targets immune filter (L42) --------------------------

  it("missile spares an angel-immune occupant from relocation", function()
    local g = _game({ "P1", "P2", "P3" })
    local p = g:current_player()
    _enemy_building(g, 3, 2) -- owned by player 2
    local immune = g.players[2]
    local casualty = g.players[3]
    g:update_player_position(immune, 3)
    g:update_player_position(casualty, 3)
    g:set_player_deity(immune, "angel", 3) -- occupant immune to the missile
    _capture_events(g)
    local hospital = g.board:find_first_by_type("hospital")

    demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    _assert_eq(immune.position, 3, "immune occupant is filtered out and not relocated")
    _assert_eq(casualty.position, hospital, "the non-immune occupant is relocated to hospital")
  end)

  -- _patch_queued_anim_targets (L77 guard, L81 kind match) -----------------

  it("missile with an anim gate patches the queued anim's to_index to the hospital", function()
    local g = _game({ "P1", "P2", "P3" })
    g.ui_port = support.build_ui_port({ wait_action_anim = true })
    g.anim_gate_port = { wait_move_anim = false, wait_action_anim = true }
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    g:update_player_position(g.players[2], 3)
    local hospital = g.board:find_first_by_type("hospital")

    demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    local anim = g.turn.action_anim
    assert(anim and anim.kind == "missile", "missile anim is queued")
    _assert_eq(anim.to_index, hospital, "the matching queued anim is patched to the hospital index")
  end)

  -- demolish.apply branch literals on a non-land target --------------------

  it("monster on a non-land tile is fully blocked: no event, but the monster anim kind stays", function()
    -- A non-land target skips the destroy block, so `destroyed` keeps its
    -- false init and (injure=false) makes the strike fully_blocked: no demolish
    -- text is published, yet _build_demolish_msg still stamps the "monster" kind
    -- on the queued anim. Pins destroyed-init (false), the fully_blocked `not`,
    -- and the monster literal at once.
    local g = _game({ "P1", "P2" })
    g.ui_port = support.build_ui_port({ wait_action_anim = true })
    g.anim_gate_port = { wait_move_anim = false, wait_action_anim = true }
    local p = g:current_player()
    local non_land_idx = nil
    for idx = 1, 60 do
      local tile = g.board:get_tile(idx)
      if tile and tile.type ~= "land" then non_land_idx = idx; break end
    end
    assert(non_land_idx, "map must have a non-land tile")
    local recorded = _capture_events(g)

    local res = demolish.apply(g, p, non_land_idx, { item_id = item_ids.monster, injure = false })

    _assert_eq(res.ok, true, "apply still reports ok on a non-land target")
    _assert_eq(
      _first_event(recorded, event_kinds.demolish),
      nil,
      "non-land + no-injure is fully blocked (destroyed stays false) -> no demolish text"
    )
    _assert_eq(g.turn.action_anim.kind, "monster", "the monster anim kind is carried even when nothing is destroyed")
  end)

  it("missile injure with zero casualties does not defer a hospital followup", function()
    local g = _game({ "P1", "P2" })
    g.ui_port = support.build_ui_port({ wait_action_anim = true })
    g.anim_gate_port = { wait_move_anim = false, wait_action_anim = true }
    local p = g:current_player()
    _enemy_building(g, 3, 2) -- destroyable, but nobody is standing on it
    _capture_events(g)

    local res = demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    _assert_eq(res.ok, true, "missile apply succeeds")
    _assert_eq(res.after_action_anim, nil, "hit == 0 means no relocation and no deferred followup")
  end)

  -- fully_blocked truth table (L162): destroyed=false + injure + hit==0 ----

  it("missile destroying nothing and hitting nobody is fully blocked: no demolish text", function()
    -- destroyed=false (angel owner) + injure=true + hit==0 (no occupant): this
    -- reaches the fully_blocked guard with the `hit == 0` clause live. Pins the
    -- `or`/`==`/literal mutations in fully_blocked that scenarios with hit>0 or
    -- destroyed=true cannot reach.
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 2)
    g:set_player_deity(g.players[2], "angel", 3) -- owner immune -> building survives
    local recorded = _capture_events(g) -- nobody stands on tile 3 -> hit == 0

    local res = demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })

    _assert_eq(res.ok, true, "missile apply succeeds")
    _assert_eq(_tile_state(g, tile).level, 2, "angel-protected building survives")
    _assert_eq(
      _first_event(recorded, event_kinds.demolish),
      nil,
      "no destroy AND zero casualties = fully blocked -> no demolish text"
    )
  end)

  -- _try_destroy_building level boundary (L23 <= 0) ------------------------

  it("monster on a level-1 angel building respects immunity (no <=0 destroy shortcut)", function()
    -- level 1 keeps (st.level or 0) <= 0 false, so the owner-immunity check
    -- runs and protects the building. Pins the `<= 0` boundary (a `<= 1`
    -- mutation would wrongly destroy a level-1 building).
    local g = _game()
    local p = g:current_player()
    local tile = _enemy_building(g, 3, 1) -- exactly level 1
    g:set_player_deity(g.players[2], "angel", 3)
    local recorded = _capture_events(g)

    demolish.apply(g, p, 3, { item_id = item_ids.monster, injure = false })

    _assert_eq(_tile_state(g, tile).level, 1, "level-1 building is protected by immunity, not destroyed")
    _assert_eq(_first_event(recorded, event_kinds.demolish), nil, "fully blocked, no demolish text")
  end)

  -- _patch_queued_anim_targets missing-turn guard (L77) -------------------

  it("missile relocation tolerates an absent turn context without crashing", function()
    -- With game.turn == nil the patch helper must early-return. A mutated guard
    -- (`game and game.turn` -> `game or game.turn`) would dereference nil.
    local g = _game()
    local p = g:current_player()
    _enemy_building(g, 3, 2)
    g:update_player_position(g.players[2], 3)
    _capture_events(g)
    g.turn = nil -- no active turn context

    local ok = pcall(function()
      return demolish.apply(g, p, 3, { item_id = item_ids.missile, injure = true, title = "导弹卡" })
    end)
    assert(ok, "apply must not crash patching anim targets when game.turn is absent")
  end)

  -- _build_human_demolish_choice no-duplicate fallback (L226) -------------

  it("human choice with a single in-range target offers exactly one option", function()
    -- Range scan finds the one target, so the `#options == 0` fallback must NOT
    -- fire. A mutated guard (`== 0` -> `~= 0`, or `0` -> `1`) would re-push the
    -- best index and duplicate the option.
    local g = _game({ "P1", "P2" })
    local p = g:current_player()
    _enemy_building(g, 3, 2) -- the only enemy building in range

    local choice = demolish.use(g, p, 3, nil, { item_id = item_ids.monster, injure = false })
    local count = 0
    for _, option in ipairs(choice.intent.choice_spec.options) do
      if option.id == 3 then count = count + 1 end
    end
    _assert_eq(count, 1, "the single target is offered exactly once (no fallback double-push)")
  end)
end)
