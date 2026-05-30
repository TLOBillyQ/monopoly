local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local effect_chance = require("src.rules.land.effect_chance")
local chance_cfg = require("src.config.content.chance_cards")
local event_kinds = require("src.config.gameplay.event_kinds")

local function _make_ctx(overrides)
  local ctx = {
    game = {
      rng = {
        next_int = function(self, min, max) return min end,
      },
      players = { { id = 1, name = "测试玩家" } },
    },
    player = { id = 1, name = "测试玩家" },
    tile = { type = "chance", index = 5 },
    move_result = { steps = 3 },
  }
  if overrides then
    for k, v in pairs(overrides) do
      ctx[k] = v
    end
  end
  return ctx
end

describe("effect_chance_draw", function()
  it("can_apply_returns_true_for_chance_tile", function()
    local ctx = _make_ctx()
    local result = effect_chance.executors.chance_draw_and_resolve.can_apply(ctx)
    _assert_eq(result, true, "should apply for chance tile")
  end)

  it("can_apply_returns_false_for_non_chance_tile", function()
    local ctx = _make_ctx({ tile = { type = "shop" } })
    local result = effect_chance.executors.chance_draw_and_resolve.can_apply(ctx)
    _assert_eq(result, false, "should not apply for non-chance tile")
  end)

  it("apply_publishes_event_and_popup", function()
    local events = {}
    local popups = {}
    local anims = {}

    local event_feed = require("src.rules.ports.event_feed")
    local presenter = require("src.rules.land.presenter")
    local chance_resolver = require("src.rules.chance.resolver")

    _with_patches({
      { target = event_feed, key = "publish", value = function(game, evt) events[#events + 1] = evt end },
      { target = presenter, key = "push_popup", value = function(game, title, text, opts) popups[#popups + 1] = { title = title, text = text, opts = opts } end },
      { target = presenter, key = "queue_action_anim", value = function(game, anim) anims[#anims + 1] = anim end },
      { target = chance_resolver, key = "resolve", value = function() return true end },
    }, function()
      local ctx = _make_ctx()
      effect_chance.executors.chance_draw_and_resolve.apply(ctx)
    end)

    _assert_eq(#events, 1, "should publish one event")
    _assert_eq(events[1].kind, event_kinds.chance_card, "should publish chance_card event")
    _assert_eq(#popups, 1, "should push one popup")
    _assert_eq(popups[1].title, "机会卡", "popup title should be 机会卡")
    _assert_eq(#anims, 1, "should queue one action anim")
    _assert_eq(anims[1].kind, "chance", "anim kind should be chance")
  end)

  it("apply_uses_rng_to_pick_card", function()
    local pick_called = false
    local pick_min, pick_max = nil, nil

    local game = {
      rng = {
        next_int = function(self, min, max)
          pick_called = true
          pick_min = min
          pick_max = max
          return min
        end,
      },
      players = { { id = 1, name = "测试玩家" } },
    }

    local ctx = _make_ctx({ game = game, player = game.players[1] })

    local event_feed = require("src.rules.ports.event_feed")
    local presenter = require("src.rules.land.presenter")
    local chance_resolver = require("src.rules.chance.resolver")

    _with_patches({
      { target = event_feed, key = "publish", value = function() end },
      { target = presenter, key = "push_popup", value = function() end },
      { target = presenter, key = "queue_action_anim", value = function() end },
      { target = chance_resolver, key = "resolve", value = function() return true end },
    }, function()
      effect_chance.executors.chance_draw_and_resolve.apply(ctx)
    end)

    _assert_eq(pick_called, true, "should call rng.next_int")
    _assert_eq(pick_min, 1, "rng min should be 1")
    assert(pick_max > 0, "rng max should be positive total_weight")
  end)

  it("apply_handles_nil_card_gracefully", function()
    local events = {}

    local game = {
      rng = {
        next_int = function(self, min, max) return max end,
      },
      players = { { id = 1, name = "测试玩家" } },
    }

    local ctx = _make_ctx({ game = game, player = game.players[1] })

    local event_feed = require("src.rules.ports.event_feed")
    local presenter = require("src.rules.land.presenter")
    local chance_resolver = require("src.rules.chance.resolver")

    local orig_cfg = chance_cfg[1]
    chance_cfg[1] = nil

    _with_patches({
      { target = event_feed, key = "publish", value = function(_game, evt) events[#events + 1] = evt end },
      { target = presenter, key = "push_popup", value = function() end },
      { target = presenter, key = "queue_action_anim", value = function() end },
      { target = chance_resolver, key = "resolve", value = function() return true end },
    }, function()
      local ok, err = pcall(function()
        effect_chance.executors.chance_draw_and_resolve.apply(ctx)
      end)
      chance_cfg[1] = orig_cfg
      assert(ok, "should not error on nil card: " .. tostring(err))
    end)
  end)
end)
