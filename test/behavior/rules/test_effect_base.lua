local lu = require("luaunit")
local support = require("test.support.shared_support")
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

TestEffectBase = {}

-- 购买拒绝:现金不足时返回 popup intent (L53 < → <=, L56 push_popup → nil)
function TestEffectBase:test_buy_land_rejects_insufficient_balance_with_popup()
  local ctx = _owned_land_ctx()
  ctx.game:set_player_cash(ctx.player, ctx.tile.price - 1)

  local result = effect_base.executors.buy_land.apply(ctx)

  lu.assertNotNil(result, "insufficient balance should return a rejection result")
  lu.assertEvalToTrue(result.intent and result.intent.kind == "push_popup",
    "insufficient balance should push a popup")
  lu.assertEvalToTrue(result.intent.payload.title == "购买失败",
    "popup title should be 购买失败")
end

-- 购买成功:恰好付得起边界不允许变 <= 拒绝 (L53 < → <=)
function TestEffectBase:test_buy_land_succeeds_when_cash_exactly_covers_price()
  local ctx = _owned_land_ctx()
  ctx.game:set_player_cash(ctx.player, ctx.tile.price)

  effect_base.executors.buy_land.apply(ctx)

  lu.assertEvalToTrue(ctx.game:player_cash(ctx.player) == 0,
    "player should spend exactly the tile price at boundary")
  lu.assertEvalToTrue(ctx.tile.owner_id == ctx.player.id,
    "tile ownership should transfer to buyer")
  -- 钉 L63 true → false:购买后产权台账必须是 true
  lu.assertEvalToTrue(ctx.player.properties[ctx.tile.id] == true,
    "player property ledger must record the new ownership")
end

-- 加盖边界:恰好付得起升级费时不应被拒绝 (L89 < → <=)
function TestEffectBase:test_upgrade_land_succeeds_at_exact_upgrade_cost_boundary()
  local ctx = _owned_land_ctx()
  local pricing = require("src.rules.land.pricing")
  local cost = pricing.upgrade_cost(ctx.tile, 0)
  ctx.game:set_player_cash(ctx.player, cost)

  effect_base.executors.upgrade_land.apply(ctx)

  lu.assertEvalToTrue(ctx.game:player_cash(ctx.player) == 0,
    "player should spend exactly the upgrade cost at boundary")
end

-- 从 level>0 升级:费用按当前等级索引 (L87 st.level or 0 → and 0 变异:level 恒非 nil 时 or 分支不可达,但 and 变异会吞掉等级)
function TestEffectBase:test_upgrade_land_from_above_zero_level_costs_by_current_level()
  local ctx = _owned_land_ctx()
  local pricing = require("src.rules.land.pricing")
  local max_level = pricing.max_level(ctx.tile)
  if max_level < 2 then
    lu.skip("tile max level is too low for this test")
  end
  ctx.game:set_tile_level(ctx.tile, 1)
  local cost = pricing.upgrade_cost(ctx.tile, 1)
  ctx.game:set_player_cash(ctx.player, cost)

  effect_base.executors.upgrade_land.apply(ctx)

  lu.assertEvalToTrue(ctx.game:player_cash(ctx.player) == 0,
    "upgrading from level 1 should spend upgrade_cost(tile, 1)")
  lu.assertEvalToTrue(ctx.tile.level == 2,
    "tile level should advance from 1 to 2")
end

-- 加盖排队 action_anim(kind=upgrade_land) (L115 upgrade_land → nil)
function TestEffectBase:test_upgrade_land_queues_upgrade_land_action_anim()
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
  lu.assertEvalToTrue(upgrade_anims[1].player_id == ctx.player.id,
    "action anim must target the upgrading player")
end

-- can_upgrade 边界:已满级地块拒加盖 (L79 >= → >, false → true)
function TestEffectBase:test_can_upgrade_rejects_at_max_level()
  local ctx = _owned_land_ctx()
  local pricing = require("src.rules.land.pricing")
  local max_level = pricing.max_level(ctx.tile)
  ctx.game:set_tile_level(ctx.tile, max_level)

  local ok = effect_base.executors.upgrade_land.can_apply(ctx)

  lu.assertEvalToTrue(ok == false, "can_upgrade should reject when at max level")
end

-- can_upgrade 边界:未满级地块允许加盖 (L79 >= → >, false → true)
function TestEffectBase:test_can_upgrade_allows_below_max_level()
  local ctx = _owned_land_ctx()
  local pricing = require("src.rules.land.pricing")
  local max_level = pricing.max_level(ctx.tile)
  if max_level <= 1 then
    lu.skip("tile max level is too low for this test")
  end
  ctx.game:set_tile_level(ctx.tile, max_level - 1)

  local ok = effect_base.executors.upgrade_land.can_apply(ctx)

  lu.assertEvalToTrue(ok == true, "can_upgrade should allow below max level")
end

-- can_buy 拒绝:地块已有主
function TestEffectBase:test_can_buy_rejects_owned_land()
  local ctx = _owned_land_ctx()

  local ok = effect_base.executors.buy_land.can_apply(ctx)

  lu.assertEvalToTrue(ok == false, "can_buy should reject owned land")
end

-- can_buy 允许:空地无主 (L47 not st.owner_id → nil 变异其实也有测但主要覆盖可购路径)
function TestEffectBase:test_can_buy_allows_unowned_land()
  local game = support.new_game({ map = default_map })
  local player = game.players[1]
  local tile = select(2, support.first_land_tile(game.board))

  local ok = effect_base.executors.buy_land.can_apply({ game = game, player = player, tile = tile })

  lu.assertEvalToTrue(ok == true, "can_buy should allow unowned land")
end

-- _notify_tile_upgraded_direct: pcall 失败返回 false,回落到事件广播 (L37 false → true)
function TestEffectBase:test_notify_tile_upgraded_direct_falls_back_to_event_on_pcall_error()
  local ctx = _owned_land_ctx()
  ctx.game.tile_feedback_port = {
    on_tile_upgraded = function()
      error("boom")
    end,
  }

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

return TestEffectBase
