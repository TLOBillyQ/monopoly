-- Mutation-closure pins for src/rules/items/handlers.lua.
-- The item-use handlers are registered into the item registry and exercised
-- through integration in item_spec, which leaves the dispatch-layer branch and
-- literal mutations alive. This spec drives the exported handle_* functions
-- directly, patching the injected ports (effects.apply_target, inventory,
-- action_anim_port, auto_play, demolish, roadblock, remote_dice, event_feed)
-- so each branch is observable in isolation:
--   * handle_target_player_item target_id validation (nil / self / eliminated /
--     not-in-candidates) and the apply orchestration helpers
--     (_resolve_apply_ok shapes, _maybe_consume_item skips, _finalize_apply,
--     _apply_share_wealth_context, _queue_target_player_anim payload),
--   * _run_item_choice_flow empty / ai / human branches,
--   * handle_remote_dice ai feed-publish guard and choice spec,
--   * handle_roadblock ai vs manual candidate source and choice spec,
--   * handle_demolish cfg dispatch (monster / missile) and missing-cfg assert.
-- Routed by architect (agent_context/rules-mutation-bootstrap-debt.md).
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local config_reset = require("spec.support.config_reset")

local handlers = require("src.rules.items.handlers")
local effects = require("src.rules.items.post_effects")
local inventory = require("src.rules.items.inventory")
local action_anim_port = require("src.foundation.ports.action_anim")
local auto_play_port = require("src.rules.ports.auto_play")
local demolish = require("src.rules.items.demolish")
local roadblock = require("src.rules.items.roadblock")
local remote_dice = require("src.rules.items.remote_dice")
local event_feed = require("src.rules.ports.event_feed")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _anim_duration = timing.action_anim_default_seconds or 1.0

local function _game(players)
  return support.new_game({ map = default_map, players = players or { "P1", "P2" } })
end

describe("item handlers — handle_target_player_item target_id validation", function()
  before_each(function() config_reset.reset_all() end)

  local function _ctx(g, target_id)
    local other = g.players[2]
    return {
      resolve_target_candidates = function() return { other } end,
      target_id = target_id,
    }
  end

  it("rejects a target_id that resolves to no player", function()
    local g = _game()
    local res = handlers.handle_target_player_item(g, g.players[1], item_ids.exile, _ctx(g, 999999))
    _assert_eq(res, false, "an unresolved target id is rejected")
  end)

  it("rejects targeting yourself", function()
    local g = _game()
    local p = g.players[1]
    local res = handlers.handle_target_player_item(g, p, item_ids.exile, _ctx(g, p.id))
    _assert_eq(res, false, "self-target is rejected")
  end)

  it("rejects an eliminated target", function()
    local g = _game()
    g.players[2].eliminated = true
    local res = handlers.handle_target_player_item(g, g.players[1], item_ids.exile, _ctx(g, g.players[2].id))
    _assert_eq(res, false, "an eliminated target is rejected")
  end)

  it("rejects a valid target that is absent from the candidate list", function()
    local g = _game()
    local res = handlers.handle_target_player_item(g, g.players[1], item_ids.exile, {
      resolve_target_candidates = function() return {} end, -- candidate list excludes the target
      target_id = g.players[2].id,
    })
    _assert_eq(res, false, "a target missing from the candidates is rejected")
  end)
end)

describe("item handlers — apply orchestration helpers", function()
  before_each(function() config_reset.reset_all() end)

  -- Drive _apply_target_player_item through handle_target_player_item with a
  -- matched target, patching effects.apply_target to control the result shape.
  local function _run(g, item_id, apply_res, extra_ctx)
    local other = g.players[2]
    local consumed, queued_payload
    local ctx = { resolve_target_candidates = function() return { other } end, target_id = other.id }
    for k, v in pairs(extra_ctx or {}) do ctx[k] = v end
    local result
    _with_patches({
      { target = effects, key = "apply_target", value = function() return apply_res end },
      { target = inventory, key = "consume", value = function() consumed = true; return true end },
      { target = action_anim_port, key = "queue", value = function(_, payload) queued_payload = payload; return true end },
    }, function()
      result = handlers.handle_target_player_item(g, g.players[1], item_id, ctx)
    end)
    return result, consumed, queued_payload, ctx
  end

  it("a table result with ok=true consumes the item and queues the target anim", function()
    local g = _game()
    local res, consumed, payload = _run(g, item_ids.exile, { ok = true })
    _assert_eq(consumed, true, "a successful apply consumes the item")
    _assert_eq(res.ok, true, "the result is stamped ok")
    _assert_eq(res.action_anim, true, "the queued anim flag is set on the result")
    _assert_eq(payload.kind, "item_target_player", "the queued anim is an item_target_player anim")
    _assert_eq(payload.player_id, g.players[1].id, "the anim carries the user id")
    _assert_eq(payload.target_player_id, g.players[2].id, "the anim carries the target id")
    _assert_eq(payload.item_id, item_ids.exile, "the anim carries the item id")
    _assert_eq(payload.duration, _anim_duration, "the anim uses the default duration")
  end)

  it("a table result with ok=false aborts before consuming or queueing", function()
    local g = _game()
    local res, consumed, payload = _run(g, item_ids.exile, { ok = false })
    _assert_eq(consumed, nil, "a failed apply does not consume the item")
    _assert_eq(payload, nil, "a failed apply queues no anim")
    _assert_eq(res.ok, false, "the failing result is returned verbatim")
  end)

  it("a bare-true result is treated as ok and finalized into a table", function()
    local g = _game()
    local res, consumed = _run(g, item_ids.exile, true)
    _assert_eq(consumed, true, "a bare-true result still consumes")
    _assert_eq(res.ok, true, "a non-table result is wrapped with ok=true")
    _assert_eq(res.action_anim, true, "the wrapper records the queued anim")
  end)

  it("a table result with no ok field defaults to applied", function()
    local g = _game()
    -- _resolve_apply_ok returns true for a table that omits a boolean ok, so
    -- the apply proceeds to consume/queue/finalize rather than aborting.
    local res, consumed, payload = _run(g, item_ids.exile, { note = "no ok field" })
    _assert_eq(consumed, true, "a table without an explicit ok is treated as applied and consumes")
    _assert_eq(res.ok, true, "_finalize_apply stamps ok=true onto the ok-less table")
    _assert_eq(payload ~= nil, true, "the target anim is queued for an ok-less success")
  end)

  it("a result flagged item_consumed skips the consume step", function()
    local g = _game()
    local _, consumed = _run(g, item_ids.exile, { ok = true, item_consumed = true })
    _assert_eq(consumed, nil, "an already-consumed result must not double-consume")
  end)

  it("a preconsumed context skips the consume step", function()
    local g = _game()
    local _, consumed = _run(g, item_ids.exile, { ok = true }, { item_preconsumed = true })
    _assert_eq(consumed, nil, "a preconsumed item must not be consumed again")
  end)

  it("an apply that already queued its own anim is not re-queued", function()
    local g = _game()
    local res, _, payload = _run(g, item_ids.exile, { ok = true, action_anim = true })
    _assert_eq(payload, nil, "the handler must not queue a second anim")
    _assert_eq(res.action_anim, true, "the apply's own anim flag is preserved")
  end)

  it("share_wealth seeds the cash-receive context; other items leave it untouched", function()
    local g1 = _game()
    local _, _, _, share_ctx = _run(g1, item_ids.share_wealth, { ok = true })
    _assert_eq(share_ctx.share_wealth_cash_receive_mode, "item_target_player_only",
      "share_wealth routes cash receive through the target-player anim")
    _assert_eq(share_ctx.suppress_cash_receive_anim, true, "share_wealth suppresses the default cash-receive anim")

    local g2 = _game()
    local _, _, _, other_ctx = _run(g2, item_ids.exile, { ok = true })
    _assert_eq(other_ctx.share_wealth_cash_receive_mode, nil,
      "a non-share item leaves the share_wealth context unset")
  end)
end)

describe("item handlers — choice flow branches", function()
  before_each(function() config_reset.reset_all() end)

  it("an empty candidate list short-circuits to false", function()
    local g = _game()
    local res = handlers.handle_target_player_item(g, g.players[1], item_ids.exile, {
      resolve_target_candidates = function() return {} end,
    })
    _assert_eq(res, false, "no candidates yields false")
  end)

  it("an ai actor applies against the auto-picked target", function()
    local g = _game()
    local other = g.players[2]
    local picked, consumed
    local res
    _with_patches({
      { target = auto_play_port, key = "pick_target_player", value = function() picked = true; return other end },
      { target = effects, key = "apply_target", value = function() return { ok = true } end },
      { target = inventory, key = "consume", value = function() consumed = true; return true end },
      { target = action_anim_port, key = "queue", value = function() return true end },
    }, function()
      res = handlers.handle_target_player_item(g, g.players[1], item_ids.exile, {
        resolve_target_candidates = function() return { other } end,
        by_ai = true,
      })
    end)
    _assert_eq(picked, true, "the ai branch resolves a target via auto_play")
    _assert_eq(consumed, true, "the ai application consumes the item")
    _assert_eq(res.ok, true, "the ai application reports ok")
  end)

  it("a human actor returns a waiting choice spec with the target options", function()
    local g = _game()
    local p, other = g.players[1], g.players[2]
    local res = handlers.handle_target_player_item(g, p, item_ids.exile, {
      resolve_target_candidates = function() return { other } end,
    })
    assert(res.waiting == true, "a human actor waits on a choice")
    _assert_eq(res.intent.kind, "need_choice", "the intent requests a choice")
    local spec = res.intent.choice_spec
    _assert_eq(spec.kind, "item_target_player", "the choice spec is an item_target_player choice")
    _assert_eq(spec.route_key, "player", "the route key dispatches to the player picker")
    _assert_eq(spec.pre_confirm_on_select, false, "selection does not pre-confirm")
    _assert_eq(spec.owner_role_id, p.id, "the choice is owned by the acting player")
    _assert_eq(spec.title, inventory.item_name(item_ids.exile) .. "：选择目标玩家", "the title names the item")
    _assert_eq(spec.allow_cancel, true, "the choice is cancelable")
    _assert_eq(spec.cancel_label, "取消", "the cancel label is pinned")
    _assert_eq(spec.meta.item_id, item_ids.exile, "the meta carries the item id")
    _assert_eq(spec.meta.player_id, p.id, "the meta carries the acting player id")
    _assert_eq(spec.options[1].id, other.id, "the candidate is offered as an option")
    _assert_eq(spec.options[1].label, other.name, "the option is labeled with the candidate name")
    assert(#spec.body_lines == 1, "one body line per candidate")
  end)
end)

describe("item handlers — handle_remote_dice", function()
  before_each(function() config_reset.reset_all() end)

  local function _run_ai(g, value, target_tile, apply_res)
    local published = {}
    _with_patches({
      { target = auto_play_port, key = "pick_remote_dice_value", value = function() return value, target_tile end },
      { target = inventory, key = "consume", value = function() return true end },
      { target = remote_dice, key = "apply", value = function() return apply_res end },
      { target = event_feed, key = "publish", value = function(_, entry) published[#published + 1] = entry end },
    }, function()
      handlers.handle_remote_dice(g, g.players[1], item_ids.remote_dice, { by_ai = true })
    end)
    return published
  end

  it("ai publishes a remote-dice feed entry when a target tile is chosen", function()
    local g = _game()
    local published = _run_ai(g, 4, { name = "财神庙" }, { ok = true })
    _assert_eq(#published, 1, "a successful targeted ai dice publishes one feed entry")
    assert(published[1].kind ~= nil, "the published entry carries a kind")
    assert(published[1].text:find("财神庙", 1, true), "the feed text names the target tile")
  end)

  it("ai publishes nothing when no target tile is chosen", function()
    local g = _game()
    local published = _run_ai(g, 4, nil, { ok = true })
    _assert_eq(#published, 0, "without a target tile there is no feed entry")
  end)

  it("ai publishes nothing when the dice application fails", function()
    local g = _game()
    local published = _run_ai(g, 4, { name = "财神庙" }, { ok = false })
    _assert_eq(#published, 0, "a failed dice application suppresses the feed entry")
  end)

  it("a human actor returns the remote-dice value choice spec", function()
    local g = _game()
    local res = handlers.handle_remote_dice(g, g.players[1], item_ids.remote_dice, {})
    local spec = res.intent.choice_spec
    _assert_eq(spec.kind, "remote_dice_value", "the choice spec is a remote_dice_value choice")
    _assert_eq(spec.route_key, "remote", "the route key dispatches to the remote picker")
    _assert_eq(spec.title, "遥控骰子：选择点数", "the title is pinned")
    _assert_eq(spec.cancel_label, "放弃", "the cancel label is pinned")
    _assert_eq(#spec.options, 6, "all six dice faces are offered")
  end)
end)

describe("item handlers — handle_roadblock", function()
  before_each(function() config_reset.reset_all() end)

  it("an ai actor sources auto candidates within radius 3 and applies the best", function()
    local g = _game()
    local auto_radius, manual_called, applied_idx
    _with_patches({
      { target = roadblock, key = "auto_candidates", value = function(_, _, radius)
          auto_radius = radius
          return { { idx = 5, label = "L5" } }
        end },
      { target = roadblock, key = "manual_candidates", value = function() manual_called = true; return {} end },
      { target = roadblock, key = "pick_best", value = function() return { idx = 5 } end },
      { target = inventory, key = "consume", value = function() return true end },
      { target = roadblock, key = "apply", value = function(_, _, idx) applied_idx = idx; return { ok = true } end },
    }, function()
      handlers.handle_roadblock(g, g.players[1], item_ids.roadblock, { by_ai = true })
    end)
    _assert_eq(auto_radius, 3, "ai roadblock placement scans a radius of 3")
    _assert_eq(manual_called, nil, "the ai branch does not use manual candidates")
    _assert_eq(applied_idx, 5, "the best candidate index is applied")
  end)

  it("a human actor sources manual candidates within radius 3 and returns a choice spec", function()
    local g = _game()
    local manual_radius
    local res
    _with_patches({
      { target = roadblock, key = "manual_candidates", value = function(_, _, radius)
          manual_radius = radius
          return { { idx = 5, label = "L5" } }
        end },
    }, function()
      res = handlers.handle_roadblock(g, g.players[1], item_ids.roadblock, {})
    end)
    _assert_eq(manual_radius, 3, "human roadblock placement scans a radius of 3")
    local spec = res.intent.choice_spec
    _assert_eq(spec.kind, "roadblock_target", "the choice spec is a roadblock_target choice")
    _assert_eq(spec.route_key, "target", "the route key dispatches to the target picker")
    _assert_eq(spec.title, "路障卡：选择位置", "the title is pinned")
    _assert_eq(spec.cancel_label, "放弃", "the cancel label is pinned")
  end)

  it("no placeable position short-circuits to false", function()
    local g = _game()
    local res
    _with_patches({
      { target = roadblock, key = "auto_candidates", value = function() return {} end },
    }, function()
      res = handlers.handle_roadblock(g, g.players[1], item_ids.roadblock, { by_ai = true })
    end)
    _assert_eq(res, false, "no roadblock candidates yields false")
  end)
end)

describe("item handlers — handle_demolish cfg dispatch", function()
  before_each(function() config_reset.reset_all() end)

  local function _capture_use(g, item_id, context)
    local captured
    g.players[1].inventory:add({ id = item_id })
    _with_patches({
      -- 假 applier 也要履行 applier_owned 契约:apply 成功前必须经 consume_fn 提交消耗
      { target = demolish, key = "use", value = function(_, _, idx, consume_fn, opts)
          captured = { idx = idx, consume_fn = consume_fn, opts = opts }
          assert(consume_fn() == true, "consume_fn must commit")
          return { ok = true }
        end },
    }, function()
      handlers.handle_demolish(g, g.players[1], item_id, context or {})
    end)
    return captured
  end

  it("the monster card demolishes within range 3 without injuring", function()
    local g = _game()
    local cap = _capture_use(g, item_ids.monster, { by_ai = true })
    _assert_eq(cap.idx, 3, "demolish scans a range of 3")
    _assert_eq(cap.opts.item_id, item_ids.monster, "the item id flows through")
    _assert_eq(cap.opts.injure, false, "the monster card does not injure")
    _assert_eq(cap.opts.title, "怪兽卡", "the monster card title is pinned")
    _assert_eq(cap.opts.by_ai, true, "the ai flag flows through")
  end)

  it("the missile card injures and carries its own title", function()
    local g = _game()
    local cap = _capture_use(g, item_ids.missile, {})
    _assert_eq(cap.opts.injure, true, "the missile card injures")
    _assert_eq(cap.opts.title, "导弹卡", "the missile card title is pinned")
    _assert_eq(cap.opts.by_ai, nil, "an absent ai flag stays nil")
  end)

  it("an unknown demolish item id is rejected", function()
    local g = _game()
    local ok = pcall(function()
      handlers.handle_demolish(g, g.players[1], item_ids.share_wealth, {})
    end)
    _assert_eq(ok, false, "a non-demolish item has no cfg and asserts")
  end)
end)
