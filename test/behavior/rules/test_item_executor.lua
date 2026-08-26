-- executor.use_item 的分发臂。handler 路径上有两条臂此前没有任何 spec 驱动:
-- 「handler 返回 waiting 时原样放行」和「apply 前后计数差回填消耗事实」。
-- 两条都只在注入式 handler 下可达(见 executor.lua 的历史 handler 契约注释),
-- 所以放在这个专门的注入式 spec 里,不去搅动真实道具的行为规约。
--
-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,断言词汇从 luassert
-- 兼容层切到 lu.assertXxx,用例数与改写前一一对应(4 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local executor = require("src.rules.items.executor")
local inventory = require("src.rules.items.inventory")
local post_effects = require("src.rules.items.post_effects")

local _assert_eq = support.assert_eq

-- 无 handler 注册、但有 cfg 的道具,executor 会走 post-effect 那条臂;
-- 这里统一用它,再临时注入 handler 把控制流赶进 handler 臂。
local TEST_ITEM_ID = 2008

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _with_item_handler(game, item_id, handler, fn)
  local handlers = assert(game.registries and game.registries.items and game.registries.items.handlers,
    "missing item handlers")
  local previous = handlers[item_id]
  handlers[item_id] = handler
  local ok, result = pcall(fn)
  handlers[item_id] = previous
  if not ok then
    error(result, 0)
  end
  return result
end

TestItemExecutor = {}

function TestItemExecutor:setUp()
  require("test.support.config_reset").reset_all()
end

function TestItemExecutor:test_use_item_returns_a_waiting_handler_result_verbatim()
  local game = _new_game()
  local player = game.players[1]
  player.inventory:add({ id = TEST_ITEM_ID })
  local waiting = { waiting = true, marker = "handler-owned" }

  local result = _with_item_handler(game, TEST_ITEM_ID, function()
    return waiting
  end, function()
    return executor.use_item(game, player, TEST_ITEM_ID, {})
  end)

  -- 同一张表原样返回,而不是被 settlement 冻结成结算结果:
  -- waiting 表示 handler 还持有这次使用,结算此刻插手会提前落账。
  lu.assertIs(result, waiting, "a waiting handler result must be returned untouched")
  lu.assertNil(result._settled_item_use, "a waiting result must not be settled")
  _assert_eq(inventory.find_index(player, TEST_ITEM_ID) ~= nil, true,
    "a waiting handler must not have consumed the item yet")
end

function TestItemExecutor:test_use_item_settles_a_non_waiting_handler_result()
  local game = _new_game()
  local player = game.players[1]
  player.inventory:add({ id = TEST_ITEM_ID })

  local result = _with_item_handler(game, TEST_ITEM_ID, function()
    return { ok = true }
  end, function()
    return executor.use_item(game, player, TEST_ITEM_ID, {})
  end)

  -- waiting 臂的对照组:非 waiting 结果必须经结算冻结,
  -- 否则「waiting 原样放行」那条断言分不清是放行还是根本没结算。
  lu.assertEquals(result._settled_item_use, true, "a non-waiting handler result must be settled")
  _assert_eq(result.status, "applied", "a successful handler settles as applied")
end

function TestItemExecutor:test_use_item_backfills_consumption_from_the_apply_count_diff()
  local game = _new_game()
  local player = game.players[1]
  player.inventory:add({ id = TEST_ITEM_ID })

  local result = _with_item_handler(game, TEST_ITEM_ID, function(_, handler_player, handler_item_id)
    -- 历史 handler 契约:效果连同消耗都在 handler 内部生效,
    -- 结算只能靠 apply 前后的计数差把「已自耗」这个事实回填进台账。
    inventory.consume(handler_player, handler_item_id)
    return { ok = true }
  end, function()
    return executor.use_item(game, player, TEST_ITEM_ID, {})
  end)

  _assert_eq(result.item_consumed, true,
    "a self-consuming handler must be recorded as consumed via the count diff")
  _assert_eq(inventory.find_index(player, TEST_ITEM_ID), nil,
    "the self-consumed item must be gone from the inventory")
end

function TestItemExecutor:test_use_item_does_not_claim_consumption_when_the_handler_keeps_the_item()
  local game = _new_game()
  local player = game.players[1]
  player.inventory:add({ id = TEST_ITEM_ID })

  local result = _with_item_handler(game, TEST_ITEM_ID, function()
    return { ok = true }
  end, function()
    return executor.use_item(game, player, TEST_ITEM_ID, {})
  end)

  -- 计数差的另一侧:handler 没自耗就不能记成已消耗,
  -- 否则台账会凭空扣掉一张仍在背包里的卡。
  _assert_eq(result.item_consumed, false,
    "a handler that keeps the item must not be recorded as consumed")
  lu.assertNotNil(inventory.find_index(player, TEST_ITEM_ID), "the item must still be in the inventory")
end

function TestItemExecutor:test_use_item_asserts_missing_registries_with_messages()
  -- #293:两处装配断言消息未测,消息→nil 变异存活。
  local bare = _new_game()
  bare.registries = nil
  local ok_registries, err_registries = pcall(executor.use_item, bare, bare.players[1], TEST_ITEM_ID, {})
  lu.assertEvalToTrue(ok_registries == false, "use_item without registries should assert")
  lu.assertEvalToTrue(tostring(err_registries):find("missing game.registries", 1, true) ~= nil,
    "registries assert should carry its message: " .. tostring(err_registries))

  local no_items = _new_game()
  no_items.registries = { items = nil }
  local ok_items, err_items = pcall(executor.use_item, no_items, no_items.players[1], TEST_ITEM_ID, {})
  lu.assertEvalToTrue(ok_items == false, "use_item without item registry should assert")
  lu.assertEvalToTrue(tostring(err_items):find("missing item registry", 1, true) ~= nil,
    "item registry assert should carry its message: " .. tostring(err_items))
end

-- #293 补杀:_use_post_effect 臂(无 handler 的道具)从未通过 executor 接口测过,
-- consume="before_apply" 字符串→nil 与 context.item_preconsumed==true→false 两个位点存活。
function TestItemExecutor:test_use_item_without_handler_consumes_via_before_apply()
  local game = _new_game()
  local player = game.players[1]
  -- 2017 无注册 handler(2008 怪兽卡有 handler 且有目标需求,会先被目标解析拒绝),
  -- executor 走 _use_post_effect → settlement(consume="before_apply")
  player.inventory:add({ id = 2017 })

  support.with_patches({
    { target = post_effects, key = "apply_post", value = function(_, _, item_id, _)
      return { ok = true, item_used_id = item_id }
    end },
  }, function()
    local result = executor.use_item(game, player, 2017, {})

    _assert_eq(result.ok, true, "no-handler item use should succeed via post effect")
    -- before_apply 模式:道具在 applier 执行前被消耗
    _assert_eq(result.item_consumed, true, "item must be consumed by before_apply mode")
  end)
end

function TestItemExecutor:test_use_item_with_preconsumed_context_marks_item_as_consumed()
  local game = _new_game()
  local player = game.players[1]
  player.inventory:add({ id = TEST_ITEM_ID })

  local result = _with_item_handler(game, TEST_ITEM_ID, function()
    -- handler 不自耗，但 context.item_preconsumed=true 告知结算道具已被预消耗
    return { ok = true }
  end, function()
    return executor.use_item(game, player, TEST_ITEM_ID, { item_preconsumed = true })
  end)

  _assert_eq(result.ok, true, "item use should succeed")
  -- context.item_preconsumed==true 经 settlement 的 _init_escrow 将 ledger.escrowed 置 true
  _assert_eq(result.item_consumed, true,
    "preconsumed flag must cause settlement to mark item as consumed without consuming via ledger")
end


return TestItemExecutor
