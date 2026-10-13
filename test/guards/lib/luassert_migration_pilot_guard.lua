--- #74 断言层迁移试点的静态门禁(纯逻辑:喂 {path, source},返回违规列表)。
---
--- 「先断言、后结构」的第一步只动断言词汇,所以门禁钉的也是这件事:
---   1. 试点文件的断言对象必须来自 test/support/luassert_loader(项目工具缓存);
---   2. 试点文件必须彻底脱离 LuaUnit 的断言入口(不再引入 luaunit / luassert 顶层模块);
---   3. 不得引入旧 Test 表 → describe/it 的永久兼容层;
---   4. 结构锚点必须仍在(切断言不许顺手改结构);
---   5. 断言调用点数不得低于切断言前的下界(防止把断言删空换绿);
---   6. loader 自己绝不接管全局 Lua assert(运行器与 LuaUnit 的后端语义挂在它上面)。
---
--- 规则是文本级的,故刻意保守:只认字面片段与 Lua 模式,不做语法分析。代价是
--- 试点文件的注释里也不能出现这些字面片段(包括 `require("luaunit")` 与 `lu.`
--- 之外的违禁片段),换来的是判定可预测、失败信息能直接指到行。
local M = {}

M.LOADER_PATH = "test/support/luassert_loader.lua"

-- #74 试点范围(冻结)。这张表就是试点范围本身:加文件/减文件都必须显式改它,
-- 试点范围不许随实现漂移。
M.PILOT_FILES = {
  "test/behavior/foundation/test_scope.lua",
  "test/behavior/foundation/test_tables.lua",
  "test/behavior/foundation/test_class.lua",
  "test/behavior/foundation/test_memo.lua",
  "test/behavior/rules/test_boundary_assertions_t36.lua",
}

-- 违禁片段(试点文件不得包含)→ 人话原因。`%f[%a]` 是词边界 frontier,避免把
-- `unit.describe(` 之类误判。
local _FORBIDDEN = {
  { literal = 'require("luaunit")', message = "仍然直接引入 luaunit 模块" },
  { literal = "require('luaunit')", message = "仍然直接引入 luaunit 模块" },
  { literal = 'require("luassert")', message = "绕过 loader 直接引入 luassert(工具缓存来源不受校验)" },
  { literal = "require('luassert')", message = "绕过 loader 直接引入 luassert(工具缓存来源不受校验)" },
  { literal = 'require("busted")', message = "引入了 busted 兼容层" },
  { pattern = "%f[%a]describe%s*%(", message = "引入了 describe 兼容层" },
}

-- 必须出现片段。
local _REQUIRED = {
  { literal = 'require("test.support.luassert_loader")', message = "断言对象未从项目工具缓存 loader 取得" },
  { literal = ".load()", message = "没有调用 loader.load() 取真 luassert 断言对象" },
}

-- 结构锚点:文件里必须仍在的结构性字面片段(切断言不许动结构)。
M.STRUCTURE_ANCHORS = {
  ["test/behavior/foundation/test_scope.lua"] = {
    { literal = "local original_warn = logger.warn", why = "logger 手工换手/还原的用例结构" },
    { literal = "return TestScope", why = "mutate 车道要求文件 return 类" },
  },
  ["test/behavior/foundation/test_tables.lua"] = {
    { literal = "local function _assert_eq", why = "文件内局部断言 helper(只换内部后端)" },
    { literal = "return TestTables", why = "mutate 车道要求文件 return 类" },
  },
  ["test/behavior/foundation/test_class.lua"] = {
    { literal = "local function _assert_eq", why = "文件内局部断言 helper(只换内部后端)" },
    { literal = "runtime_baseline_guard", why = "模块加载期的共享运行时端口基线守卫" },
    { literal = "return TestClass", why = "mutate 车道要求文件 return 类" },
  },
  ["test/behavior/foundation/test_memo.lua"] = {
    { literal = "return TestMemo", why = "mutate 车道要求文件 return 类" },
  },
  ["test/behavior/rules/test_boundary_assertions_t36.lua"] = {
    { literal = "local function _assert_contains", why = "文件内局部断言 helper(只换内部后端)" },
    { literal = "function TestBoundaryAssertionsT36:setUp()", why = "类钩子" },
    { literal = "test.support.multi_class_return", why = "多类文件合并 return 的特殊结构" },
  },
}

-- 断言调用点下界 = 切断言前该文件 LuaUnit `lu.*` 调用点的实测数。切断言后
-- `luassert.*` 调用点不得少于这个数:断言只许换后端,不许被删空。
M.ASSERTION_CALL_FLOOR = {
  ["test/behavior/foundation/test_scope.lua"] = 13,
  ["test/behavior/foundation/test_tables.lua"] = 4,
  ["test/behavior/foundation/test_class.lua"] = 2,
  ["test/behavior/foundation/test_memo.lua"] = 35,
  ["test/behavior/rules/test_boundary_assertions_t36.lua"] = 6,
}

-- loader 源码里绝不允许出现的全局接管写法。
local _LOADER_FORBIDDEN = {
  { pattern = "_G%.assert%s*=", message = "loader 给 _G.assert 赋值,等于换执行后端" },
  { pattern = "_G%s*%[%s*[\"']assert[\"']%s*%]%s*=", message = "loader 给 _G.assert 赋值,等于换执行后端" },
  { pattern = "%f[%a]rawset%s*%(%s*_G", message = "loader 用 rawset 写 _G" },
}

local function _count_assertion_calls(source)
  -- `luassert.xxx` / `luassert.is.xxx` 都算;不数方法名本身。
  local count = 0
  for _ in tostring(source):gmatch("%f[%a]luassert%.[%a_%.]+") do
    count = count + 1
  end
  return count
end

local function _check_forbidden(path, source, rules, violations)
  for _, rule in ipairs(rules) do
    local found = nil
    if rule.literal ~= nil then
      if tostring(source):find(rule.literal, 1, true) ~= nil then
        found = rule.literal
      end
    else
      found = tostring(source):match(rule.pattern)
    end
    if found ~= nil then
      violations[#violations + 1] = string.format("%s: %s (命中 %q)", path, rule.message, found)
    end
  end
end

--- 逐条核对试点文件与 loader。entries = { { path = ..., source = ... }, ... }。
--- 返回违规字符串列表;空列表 = 门禁通过。
function M.check(entries)
  local violations = {}
  for _, entry in ipairs(entries or {}) do
    local path = entry.path
    local source = tostring(entry.source or "")
    if path == M.LOADER_PATH then
      _check_forbidden(path, source, _LOADER_FORBIDDEN, violations)
    else
      _check_forbidden(path, source, _FORBIDDEN, violations)
      for _, required in ipairs(_REQUIRED) do
        if source:find(required.literal, 1, true) == nil then
          violations[#violations + 1] = string.format("%s: %s(缺 %q)", path, required.message, required.literal)
        end
      end
      for _, anchor in ipairs(M.STRUCTURE_ANCHORS[path] or {}) do
        if source:find(anchor.literal, 1, true) == nil then
          violations[#violations + 1] = string.format("%s: 结构锚点丢失 %q(%s)", path, anchor.literal, anchor.why)
        end
      end
      local floor = M.ASSERTION_CALL_FLOOR[path]
      if floor ~= nil then
        local calls = _count_assertion_calls(source)
        if calls < floor then
          violations[#violations + 1] = string.format(
            "%s: luassert 断言调用点 %d 个,低于切断言前的下界 %d", path, calls, floor)
        end
      end
    end
  end
  return violations
end

--- IO 壳:读真实试点文件与 loader,交给纯核。仓根由源文件定位,不依赖 cwd。
function M.run()
  local fs_lib = require("foundation.fs")
  local env = require("foundation.bootstrap").install(debug.getinfo(1, "S").source)
  local entries = {}
  for _, path in ipairs({ M.LOADER_PATH }) do
    local source, err = fs_lib.read_file(env.repo_root .. "/" .. path)
    if source == nil then
      return { ok = false, error = "luassert_migration_pilot_guard error: " .. tostring(err) }
    end
    entries[#entries + 1] = { path = path, source = source }
  end
  for _, path in ipairs(M.PILOT_FILES) do
    local source, err = fs_lib.read_file(env.repo_root .. "/" .. path)
    if source == nil then
      return { ok = false, error = "luassert_migration_pilot_guard error: " .. tostring(err) }
    end
    entries[#entries + 1] = { path = path, source = source }
  end

  local violations = M.check(entries)
  if #violations > 0 then
    return { ok = false, error = table.concat(violations, "\n") }
  end
  return {
    ok = true,
    message = string.format("luassert_migration_pilot_guard ok (%d 个试点文件)", #M.PILOT_FILES),
  }
end

return M
