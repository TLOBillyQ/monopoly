-- screens_registry.lua 直测：聚合 API 的惰性加载(首次调用触发清单 require 自注册,
-- 且重复调用幂等)与 register 的 key 契约。
-- 清单屏模块在 behavior 车道可 require(各屏直测已验证),require 副作用即观测点。
local lu = require("luaunit")
local luax = require("test.support.luax")

local registry = require("src.ui.screens_registry")

TestScreensRegistry = {}

-- 隔离:清注册表 + 逐出清单模块的 require 缓存,让聚合 API 的首次调用成为
-- 唯一注册源(require 缓存会让同进程先加载的屏模块绕过 _ensure_loaded)。
-- 清理后必须装回(#428):per-file 模块缓存抹除移除后,registry 实例跨文件共享,
-- 不装回会让同 worker 后续类的屏注册断言打到被清空的共享实例上
-- (target/player/remote_choice_spec 的假红就是这么来的)。
local _SCREEN_LIST = {
  "src.ui.screens.market",
  "src.ui.screens.skin_panel",
  "src.ui.screens.item_atlas",
  "src.ui.screens.target_choice",
  "src.ui.screens.remote_choice",
  "src.ui.screens.player_choice",
  "src.ui.screens.secondary_confirm",
}

local _saved_screen_modules = nil

function TestScreensRegistry:setUp()
  _saved_screen_modules = {}
  for _, mod in ipairs(_SCREEN_LIST) do
    _saved_screen_modules[mod] = package.loaded[mod]
  end
  registry.reset_for_tests()
  for _, mod in ipairs(_SCREEN_LIST) do
    package.loaded[mod] = nil
  end
end

function TestScreensRegistry:tearDown()
  -- 装回 setUp 前状态:恢复 require 缓存(保住其它文件捕获的模块实例身份),
  -- 再触发一次惰性聚合,让注册表按 _ensure_loaded 规范序重注册同批实例。
  registry.reset_for_tests()
  for _, mod in ipairs(_SCREEN_LIST) do
    package.loaded[mod] = _saved_screen_modules[mod]
  end
  registry.build_choice_screens()
end

-- 惰性加载:首次聚合调用必须触发清单 require,否则清单屏不会自注册进 registry。
function TestScreensRegistry:test_aggregation_loads_the_screen_list_lazily()
  local screens = registry.build_choice_screens()

  lu.assertEvalToTrue(type(screens) == "table", "aggregation must return a table")
  lu.assertEvalToTrue(screens["target"] ~= nil,
    "target screen must register through lazy loading")
  lu.assertEvalToTrue(screens["remote"] ~= nil,
    "remote screen must register through lazy loading")
end

-- 幂等:已加载后再次聚合调用不重复 require(重复注册会炸 duplicate key)。
function TestScreensRegistry:test_aggregation_is_idempotent_across_calls()
  local first = registry.build_choice_screens()
  local second = registry.build_choice_screens()

  lu.assertEvalToTrue(type(first) == "table" and type(second) == "table",
    "repeated aggregation must not crash")
  lu.assertEvalToTrue(second["secondary_confirm"] ~= nil,
    "secondary_confirm stays registered after repeated aggregation")
end

-- register 契约:非表屏拒收。
function TestScreensRegistry:test_register_rejects_non_table_screens()
  luax.has_error(function()
    registry.register("not-a-screen")
  end, "screen needs a string key")
end

-- register 契约:key 必须是字符串。
function TestScreensRegistry:test_register_rejects_screens_without_a_string_key()
  luax.has_error(function()
    registry.register({ key = 7 })
  end, "screen needs a string key")
end

-- register 契约:key 必须唯一。
function TestScreensRegistry:test_register_rejects_duplicate_keys()
  local key = "zz_test_only_duplicate"
  registry.register({ key = key })
  luax.has_error(function()
    registry.register({ key = key })
  end, "duplicate screen key: " .. key)
end

function TestScreensRegistry:test_choice_descriptor_keys_stay_stable()
  local screens = registry.build_choice_screens()
  local keys = {}
  for key in pairs(screens) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  lu.assertEquals(keys, { "player", "remote", "secondary_confirm", "target" })
end

function TestScreensRegistry:test_opener_and_canvas_lookup_preserve_known_and_unknown_keys()
  local target = require("src.ui.screens.target_choice")
  lu.assertIs(registry.opener_for("target"), target.open)
  lu.assertIs(registry.canvas_for("target"), target.canvas)
  lu.assertNil(registry.opener_for("unknown"))
  lu.assertNil(registry.canvas_for("unknown"))
end

function TestScreensRegistry:test_route_specs_follow_registration_order()
  registry.build_choice_screens()
  registry.register({
    key = "zz_order_first",
    build_route_specs = function() return { { name = "zz_order_first" } } end,
  })
  registry.register({
    key = "zz_order_second",
    build_route_specs = function() return { { name = "zz_order_second" } } end,
  })

  local specs = registry.build_route_specs({})
  lu.assertEquals(specs[#specs - 1].name, "zz_order_first")
  lu.assertEquals(specs[#specs].name, "zz_order_second")
end

return TestScreensRegistry
