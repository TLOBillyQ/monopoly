local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local default_map = require("src.config.content.default_map")
local effect_base = require("src.rules.land.effect_base")

local function _owned_land_ctx()
  local game = support.new_game({ map = default_map })
  local player = game.players[1]
  local tile = select(2, support.first_land_tile(game.board))
  game:set_tile_owner(tile, player.id)
  game:set_player_property(player, tile.id, true)
  return { game = game, player = player, tile = tile }
end

TestLandExecutors = {}

function TestLandExecutors:test__test_merge_executor_groups_combines_multiple_groups(self)
  local executors = require("src.rules.land.executors")
  local merged = executors._merge_executor_groups({
    { buy_land = { name = "buy" }, upgrade_land = { name = "upgrade" } },
    { pay_rent = { name = "rent" }, tax = { name = "tax" } },
  })
  lu.assertNotNil(merged.buy_land, "should have buy_land executor")
  lu.assertNotNil(merged.upgrade_land, "should have upgrade_land executor")
  lu.assertNotNil(merged.pay_rent, "should have pay_rent executor")
  lu.assertNotNil(merged.tax, "should have tax executor")
end

function TestLandExecutors:test__test_merge_executor_groups_later_overrides_earlier(self)
  local executors = require("src.rules.land.executors")
  local merged = executors._merge_executor_groups({
    { buy_land = { name = "original" } },
    { buy_land = { name = "override" } },
  })
  lu.assertEvalToTrue(merged.buy_land.name == "override", "later group should override earlier")
end

function TestLandExecutors:test__test_merge_executor_groups_handles_empty_groups(self)
  local executors = require("src.rules.land.executors")
  local merged = executors._merge_executor_groups({
    {},
    { buy_land = { name = "buy" } },
    {},
  })
  lu.assertNotNil(merged.buy_land, "should handle empty groups")
  lu.assertEvalToTrue(merged.buy_land.name == "buy", "should have correct executor after empty groups")
end

function TestLandExecutors:test_merge_executor_groups_combines_groups(self)
  local executors = require("src.rules.land.executors")
  local base = require("src.rules.land.effect_base")
  local special = require("src.rules.land.effect_special")

  lu.assertEvalToTrue(type(executors.executors) == "table", "executors.executors should be a table")
  for effect_id in pairs(base.executors) do
    lu.assertNotNil(executors.executors[effect_id], "merged executors should include base group: " .. effect_id)
  end
  for effect_id in pairs(special.executors) do
    lu.assertNotNil(executors.executors[effect_id], "merged executors should include special group: " .. effect_id)
  end
end

function TestLandExecutors:test_upgrade_land_emits_tile_upgraded_event_when_feedback_port_unresolvable(self)
  local ctx = _owned_land_ctx()
  local monopoly_event = require("src.foundation.events")
  local emitted = {}

  ctx.game.tile_feedback_port = nil

  support.with_patches({
    {
      target = monopoly_event,
      key = "emit",
      value = function(kind, payload) emitted[#emitted + 1] = { kind = kind, payload = payload } end,
    },
  }, function()
    effect_base.executors.upgrade_land.apply(ctx)
  end)

  local upgraded = nil
  for _, event in ipairs(emitted) do
    if event.kind == monopoly_event.land.tile_upgraded then upgraded = event end
  end
  lu.assertNotNil(upgraded, "两级兜底都解析不出反馈口时应广播 tile_upgraded 事件")
  lu.assertEvalToTrue(upgraded.payload.tile_id == ctx.tile.id, "广播应带被加盖地块 id")
  lu.assertEvalToTrue(upgraded.payload.level == 1, "广播应带新等级")
end


function TestLandExecutors:test_upgrade_land_rejects_insufficient_balance_with_popup()
  local ctx = _owned_land_ctx()
  ctx.game:set_player_cash(ctx.player, 0)

  local result = effect_base.executors.upgrade_land.apply(ctx)

  lu.assertNotNil(result, "insufficient balance should return a rejection result")
  lu.assertEvalToTrue(result.intent and result.intent.kind == "push_popup",
    "insufficient balance should push a popup")
  lu.assertEvalToTrue(tostring(result.intent.payload.body):find("余额不足", 1, true) ~= nil,
    "insufficient balance popup should carry the 余额不足 body")
end

function TestLandExecutors:test_mine_executor_distinguishes_hospitalization()
  -- #293:mine 执行器的 `res and res.hospitalized`(or 变异)与
  -- need_landing kind(→ nil 变异)未测。
  local mine_effect = require("src.rules.effects.mine")
  local special = require("src.rules.land.effect_special")
  local executor = special.executors.mine

  local ctx = {
    game = {},
    player = { id = 1, position = 5 },
  }

  local saved_apply = mine_effect.apply
  mine_effect.apply = function() return { hospitalized = false } end
  local non_hospital = executor.apply(ctx)
  lu.assertEvalToTrue(non_hospital == nil,
    "non-hospitalized mine result should fall through without a landing intent")

  mine_effect.apply = function() return { hospitalized = true, wait_action_anim = false } end
  local landed = executor.apply(ctx)
  lu.assertEvalToTrue(landed ~= nil and landed.kind == "need_landing",
    "hospitalized mine result should yield a need_landing intent; got " .. tostring(landed and landed.kind))
  lu.assertEvalToTrue(landed.player_id == 1 and landed.board_index == 5,
    "need_landing should carry the player and position")

  mine_effect.apply = function() return { hospitalized = true, wait_action_anim = true } end
  local waiting = executor.apply(ctx)
  lu.assertEvalToTrue(waiting ~= nil and waiting.waiting == true and waiting.wait_action_anim == true,
    "waiting mine result should pass through the wait flags")

  mine_effect.apply = saved_apply
end

-- 购买拒绝:现金不足时返回 popup intent(kind=push_popup)且标题为"购买失败"
function TestLandExecutors:test_buy_land_rejects_insufficient_balance_with_popup()
  local ctx = _owned_land_ctx()
  ctx.game:set_player_cash(ctx.player, ctx.tile.price - 1)

  local result = effect_base.executors.buy_land.apply(ctx)

  lu.assertNotNil(result, "insufficient balance should return a rejection result")
  lu.assertEvalToTrue(result.intent and result.intent.kind == "push_popup",
    "insufficient balance should push a popup; got " .. tostring(result.intent and result.intent.kind))
  lu.assertEvalToTrue(result.intent.payload.title == "购买失败",
    "popup title should be 购买失败")
end

-- 购买成功:恰好付得起(boundary=price)不允许变<=拒绝
function TestLandExecutors:test_buy_land_succeeds_when_cash_exactly_covers_price()
  local ctx = _owned_land_ctx()
  ctx.game:set_player_cash(ctx.player, ctx.tile.price)

  effect_base.executors.buy_land.apply(ctx)

  lu.assertEvalToTrue(ctx.game:player_cash(ctx.player) == 0,
    "player should spend exactly the tile price at boundary")
  lu.assertEvalToTrue(ctx.tile.owner_id == ctx.player.id,
    "tile ownership should transfer to buyer")
  lu.assertEvalToTrue(ctx.player.properties[ctx.tile.id] == true,
    "player property ledger must record the new ownership")
end

-- 加盖边界:恰好付得起升级费时不应被拒绝
function TestLandExecutors:test_upgrade_land_succeeds_at_exact_upgrade_cost_boundary()
  local ctx = _owned_land_ctx()
  local pricing = require("src.rules.land.pricing")
  local cost = pricing.upgrade_cost(ctx.tile, 0)
  ctx.game:set_player_cash(ctx.player, cost)

  effect_base.executors.upgrade_land.apply(ctx)

  lu.assertEvalToTrue(ctx.game:player_cash(ctx.player) == 0,
    "player should spend exactly the upgrade cost at boundary")
end

-- 加盖排队 action_anim(kind=upgrade_land)
function TestLandExecutors:test_upgrade_land_queues_upgrade_land_action_anim()
  local ctx = _owned_land_ctx()
  local action_anim_port = require("src.foundation.ports.action_anim")
  local queued = {}
  support.with_patches({
    { target = action_anim_port, key = "queue", value = function(_, anim)
      queued[#queued + 1] = anim
    end },
  }, function()
    effect_base.executors.upgrade_land.apply(ctx)
  end)

  -- 升级路径会先因扣款排一条 cash_receive,再排 upgrade_land;按 kind 过滤后必须恰一条
  local upgrade_anims = {}
  for _, anim in ipairs(queued) do
    if anim.kind == "upgrade_land" then
      upgrade_anims[#upgrade_anims + 1] = anim
    end
  end
  lu.assertEvalToTrue(#upgrade_anims == 1, "upgrade should queue one upgrade_land action anim")
  _assert_eq(upgrade_anims[1].player_id, ctx.player.id, "action anim must target the upgrading player")
end

-- can_upgrade 边界:已满级地块拒加盖
function TestLandExecutors:test_can_upgrade_rejects_at_max_level()
  local ctx = _owned_land_ctx()
  local pricing = require("src.rules.land.pricing")
  local max_level = pricing.max_level(ctx.tile)
  ctx.game:set_tile_level(ctx.tile, max_level)

  local ok = effect_base.executors.upgrade_land.can_apply(ctx)

  _assert_eq(ok, false, "can_upgrade should reject when at max level; got " .. tostring(ok))
end

-- can_upgrade 边界:未满级地块允许加盖
function TestLandExecutors:test_can_upgrade_allows_below_max_level()
  local ctx = _owned_land_ctx()
  local pricing = require("src.rules.land.pricing")
  local max_level = pricing.max_level(ctx.tile)
  if max_level <= 1 then
    lu.skip("tile max level is too low for this test")
  end
  ctx.game:set_tile_level(ctx.tile, max_level - 1)

  local ok = effect_base.executors.upgrade_land.can_apply(ctx)

  _assert_eq(ok, true, "can_upgrade should allow below max level")
end

-- can_buy 拒绝:地块已有主
function TestLandExecutors:test_can_buy_rejects_owned_land()
  local ctx = _owned_land_ctx()

  local ok = effect_base.executors.buy_land.can_apply(ctx)

  _assert_eq(ok, false, "can_buy should reject owned land")
end

-- can_buy 允许:空地无主
function TestLandExecutors:test_can_buy_allows_unowned_land()
  local game = support.new_game({ map = default_map })
  local player = game.players[1]
  local tile = select(2, support.first_land_tile(game.board))

  local ok = effect_base.executors.buy_land.can_apply({ game = game, player = player, tile = tile })

  _assert_eq(ok, true, "can_buy should allow unowned land")
end

-- _notify_tile_upgraded_direct: pcall 失败返回 false
function TestLandExecutors:test_notify_tile_upgraded_direct_returns_false_on_error()
  local ctx = _owned_land_ctx()
  ctx.game.tile_feedback_port = {
    on_tile_upgraded = function()
      error("boom")
    end,
  }

  -- 不加补丁直接调 apply,通过 _notify_tile_upgraded_direct → pcall 捕获 error
  -- pcall 失败时 _notify_tile_upgraded_direct 返回 false,回落到事件广播
  local monopoly_event = require("src.foundation.events")
  local emitted = false
  support.with_patches({
    { target = monopoly_event, key = "emit", value = function(kind, _payload)
      if kind == monopoly_event.land.tile_upgraded then emitted = true end
    end },
  }, function()
    effect_base.executors.upgrade_land.apply(ctx)
  end)

  lu.assertEvalToTrue(emitted == true,
    "pcall error in tile_feedback_port should fall back to event emission (not crash)")
end


return TestLandExecutors
