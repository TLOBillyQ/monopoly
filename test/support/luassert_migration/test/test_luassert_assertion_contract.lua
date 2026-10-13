--- #74 试点契约:luassert 断言语义与失败传播。
---
--- 「先断言、后结构」第一步的验收面:不换旧 LuaUnit 结构、不换旧运行器,只把
--- 断言层切到真 luassert,证明迁移后的断言仍然会红、红在哪一桶、试点集合的用例
--- 数对得上。四个接缝:
---   1. 装载:luassert/say 只从项目工具缓存解析,全局 Lua assert 不被覆盖;
---   2. 语义:深比较/身份、严格布尔/truthiness、nil/false、异常文本/模式/类型
---      各自的正例与故意失败反例(进程内 pcall 观察,不污染车道计数);
---   3. 传播:反例 fixture 交给真实旧 runner 子进程,退出码非零、落在明确的
---      failure/error 桶里,且同文件的控制用例必须为绿(排除「加载即失败」的假红);
---   4. 对账:#74 试点 5 个文件的类/用例集合与试点前逐一对应,一个都不少。
---
--- 计数口径(实测):luassert 抛的是普通字符串错误,不带 LuaUnit 的
--- `LuaUnit test FAILURE: ` 前缀,因此旧 runner 把它计进 **errors** 桶;
--- `lu.fail()` 一类的 FAILURE_PREFIX 错误计进 **failures**。两桶都进
--- `# COUNTS:`,且 runner 退出码取 `failures + errors > 0`,两桶各自独立顶非零,
--- 谁都吞不掉。
---
--- 另一条实测到的坑(Lua 的 LUA_IDSIZE=60):spec 路径较长时,报错里的 chunk
--- 名会被 Lua 自身截成 `...<尾部>`,所以 TAP 的 `# <src> @ <line>` 不保证是完整
--- 路径——本 spec 按 basename 归属反例,不按整路径比。

require("test.bootstrap").install_package_paths()

local loader = require("test.support.luassert_loader")
local proc = require("foundation.proc")

local function _fail(message)
  error(message, 2)
end

local function _expect(condition, message)
  if condition ~= true then
    _fail(message)
  end
end

-- 加载 luassert,失败时把 loader 的原因原样带出来(不静默跳过)。
local function _luassert()
  return require("luassert")
end

-- 正例:断言必须通过。不过即本契约自己的红。
local function _must_pass(fn, label)
  local ok, err = pcall(fn)
  if not ok then
    _fail(label .. ": assertion must hold, but it failed: " .. tostring(err))
  end
end

-- 故意失败反例:断言必须抛错,且错误文本带上指定片段。反例的错在这里被 pcall
-- 接住,不落进车道计数——进程内观察语义,不靠「让本 spec 变红」来证明。
local function _must_fail(fn, fragment, label)
  local ok, err = pcall(fn)
  if ok then
    _fail(label .. ": the deliberately wrong assertion must fail, but it passed")
  end
  local message = tostring(err)
  if message:find(fragment, 1, true) == nil then
    _fail(string.format("%s: expected the failure message to contain %q, got: %s",
      label, fragment, message))
  end
  return message
end

-- ------------------------------------------------------------ runner 子进程面

local _RUNNER = "tools/packages/luaunit_runner/runner.lua"
local _FIXTURE_DIR = "test/fixtures/luassert_migration/"

-- 显式 --output TAP:default profile 的 log_warns_handler 在 quiet 模式会吞掉
-- 通过的 `ok N` 行,而本契约要靠「控制用例为绿」排除假红。helper 仍走 profile
-- 默认的 test/helper.lua——反例跑在与真实车道同一条加载路径上。
local function _run_specs(files)
  local command = { "lua", _RUNNER, "--output", "TAP", "--" }
  for _, path in ipairs(files) do
    command[#command + 1] = path
  end
  local result = proc.run_command(command, { cwd = loader.repo_root() })
  local output = tostring(result.output or "")
  if output:find("# COUNTS: ", 1, true) == nil then
    _fail("runner produced no TAP counters; command=" .. table.concat(command, " ")
      .. "\noutput:\n" .. output)
  end
  return result, output
end

local function _counts(raw)
  local files, cases, passed, failed, errors = tostring(raw):match(
    "# COUNTS: files=(%d+) cases=(%d+) passed=(%d+) failed=(%d+) errors=(%d+)")
  if files == nil then
    _fail("runner output has no parseable # COUNTS line:\n" .. tostring(raw))
  end
  return {
    files = tonumber(files), cases = tonumber(cases), passed = tonumber(passed),
    failed = tonumber(failed), errors = tonumber(errors),
  }
end

-- TAP 记录:每个 `ok N - name` / `not ok N - name` 之后跟 `# <src> @ <line>`
-- (仅红)与 `# Failure message: ...`(仅红,后续 `# ` 行为其续行)。
local function _records(raw)
  local records = {}
  local current = nil
  for line in (tostring(raw):gsub("\r\n", "\n") .. "\n"):gmatch("([^\n]*)\n") do
    local ok_index, ok_name = line:match("^ok (%d+) %- (.+)$")
    local bad_index, bad_name = line:match("^not ok (%d+) %- (.+)$")
    if ok_index ~= nil then
      current = { ok = true, index = tonumber(ok_index), name = ok_name, message = "" }
      records[#records + 1] = current
    elseif bad_index ~= nil then
      current = { ok = false, index = tonumber(bad_index), name = bad_name, message = "" }
      records[#records + 1] = current
    elseif current ~= nil and line:match("^# ") ~= nil
      and line:match("^# COUNTS: ") == nil then
      local message = line:match("^# Failure message: (.*)$")
      local src, lineno = line:match("^# (.+) @ (%d+)$")
      if message ~= nil then
        current.message = message
      elseif src ~= nil and lineno ~= nil and current.source == nil then
        current.source = src
        current.line = tonumber(lineno)
      elseif current.message ~= "" then
        current.message = current.message .. "\n" .. line:sub(3)
      end
    end
  end
  return records
end

local function _record(records, full_name)
  for _, record in ipairs(records) do
    if record.name == full_name then
      return record
    end
  end
  return nil
end

-- fixture 清单:控制用例名、反例用例名、反例失败消息必须带上的片段。
-- 前 6 个反例都是 luassert 抛错 → errors 桶;luaunit_failure_bucket 是 lu.fail
-- → failures 桶,单独一轮跑,用来证明两个桶各自独立顶非零。
local _LUASSERT_FIXTURES = {
  {
    basename = "deep_compare_and_identity.lua",
    class = "TestLuassertFixtureDeepCompareAndIdentity",
    control = "test_control_deep_compare_passes_and_identity_still_differs",
    counterexample = "test_counterexample_identity_equal_on_equal_content_tables_fails",
    fragment = "Expected objects to be equal.",
  },
  {
    basename = "strict_boolean_and_truthiness.lua",
    class = "TestLuassertFixtureStrictBooleanAndTruthiness",
    control = "test_control_strict_boolean_and_truthiness_each_hold",
    counterexample = "test_counterexample_strict_true_rejects_a_truthy_number",
    fragment = "Expected objects to be the same.",
  },
  {
    basename = "nil_and_false.lua",
    class = "TestLuassertFixtureNilAndFalse",
    control = "test_control_nil_and_false_are_distinguished",
    counterexample = "test_counterexample_nil_assertion_rejects_false",
    fragment = "type nil",
  },
  {
    basename = "error_text.lua",
    class = "TestLuassertFixtureErrorText",
    control = "test_control_error_text_matches_exactly_after_location_stripping",
    counterexample = "test_counterexample_wrong_expected_error_text_fails",
    fragment = "(string) '余额不足'",
  },
  {
    basename = "error_pattern.lua",
    class = "TestLuassertFixtureErrorPattern",
    control = "test_control_error_pattern_and_plain_substring_both_match",
    counterexample = "test_counterexample_non_matching_error_pattern_fails",
    fragment = "(string) 'NEVER_MATCHES_THIS_PATTERN'",
  },
  {
    basename = "error_table_payload.lua",
    class = "TestLuassertFixtureErrorTablePayload",
    control = "test_control_table_error_payload_deep_compares_and_type_assertions_hold",
    counterexample = "test_counterexample_mismatched_table_error_payload_fails",
    fragment = "[code] = 8",
  },
}

local _FAILURES_BUCKET_FIXTURE = {
  basename = "luaunit_failure_bucket.lua",
  class = "TestLuassertFixtureLuaunitFailureBucket",
  control = "test_control_luassert_green_beside_a_luaunit_failure",
  counterexample = "test_counterexample_lu_fail_lands_in_the_failures_bucket",
  fragment = "必须落 failures 桶",
}

-- #74 试点范围(冻结):5 个真实 spec 文件的断言层就地切换,文件/类/用例集合
-- 切断言前后必须逐一对应。
local _PILOT_FILES = {
  "test/behavior/foundation/test_scope.lua",
  "test/behavior/foundation/test_tables.lua",
  "test/behavior/foundation/test_class.lua",
  "test/behavior/foundation/test_memo.lua",
  "test/behavior/rules/test_boundary_assertions_t36.lua",
}

-- 切断言前的基线(migration 前实测:files=5 cases=45 passed=45 failed=0
-- errors=0)。多类文件仍出两个类——multi_class_return.merge 是特殊结构,不跳过。
local _PILOT_FILE_CASES = { 9, 9, 5, 13, 9 }

describe("luassert assertion contract", function()

-- ---------------------------------------------------------------- 1. 装载契约

it("luassert and say resolve from the project tool cache", function()
  _luassert()
  for _, module_name in ipairs({ "luassert", "say" }) do
    local source = package.searchpath(module_name, package.path)
    _expect(source ~= nil, module_name .. " is not resolvable from package.path")
    local normalized = tostring(source):gsub("\\", "/")
    _expect(normalized:find("/.toolcache/luarocks/", 1, true) ~= nil,
      module_name .. " must load from the project tool cache, got: " .. normalized)
  end
end)

it("loading luassert does not take over the global lua assert", function()
  local result = proc.run_command({ require("foundation.lua54").lua54_bin(), "-e",
    'require("test.bootstrap").install_package_paths(); local original = _G.assert; local object = assert(require("test.support.luassert_loader").load()); assert(_G.assert == original and object ~= original); print("LOCAL_ASSERT_ONLY")' },
    { cwd = loader.repo_root() })
  _expect(result.code == 0 and tostring(result.output):find("LOCAL_ASSERT_ONLY", 1, true) ~= nil,
    "legacy loader must keep global assert unchanged:\n" .. tostring(result.output))
end)

it("fresh process cache loading and preload rejection", function()
  local scripts = {
    {
      marker = "REAL_CACHE_IDENTITY",
      source = [[
require("test.bootstrap").install_package_paths()
local original = _G.assert
local loader = require("test.support.luassert_loader")
local object = assert(loader.load())
assert(object == package.loaded.luassert and object == loader.load())
assert(_G.assert == original)
for _, name in ipairs({ "luassert", "say" }) do
  local source = assert(package.searchpath(name, package.path)):gsub("\\", "/")
  local prefix = loader.repo_root():gsub("\\", "/") .. "/.toolcache/luarocks/"
  assert(source:find(prefix, 1, true) == 1)
end
object.is.same({ value = 1 }, { value = 1 })
assert(not pcall(function() object.is_true(1) end))
print("REAL_CACHE_IDENTITY")
]],
    },
  }
  for _, name in ipairs({ "luassert", "say" }) do
    scripts[#scripts + 1] = {
      marker = "REJECTED_" .. name,
      source = 'require("test.bootstrap").install_package_paths()\n'
        .. 'package.loaded["' .. name .. '"] = {}\n'
        .. 'local object, err = require("test.support.luassert_loader").load()\n'
        .. 'assert(object == nil and tostring(err):find("unverified preloaded module: ' .. name .. '", 1, true))\n'
        .. 'print("REJECTED_' .. name .. '")\n',
    }
  end
  for _, script in ipairs(scripts) do
    local result = proc.run_command({ "lua", "-e", (script.source:gsub("\n", " ")) }, { cwd = loader.repo_root() })
    _expect(result.code == 0 and tostring(result.output):find(script.marker, 1, true) ~= nil,
      "fresh process contract failed: " .. script.marker .. "\n" .. tostring(result.output))
  end
end)

it("unverified preloaded modules are rejected", function()
  for _, name in ipairs({ "luassert", "say" }) do
    local saved = package.loaded[name]
    package.loaded[name] = {}
    local fresh_loader = assert(loadfile(loader.repo_root() .. "/test/support/luassert_loader.lua"))()
    local ok, object, err = pcall(fresh_loader.load)
    package.loaded[name] = saved
    _expect(ok and object == nil and tostring(err):find("preloaded", 1, true) ~= nil,
      name .. ": an unverified preloaded object must be rejected, got: " .. tostring(err))
  end
end)

it("cache loading bypasses fake preload factories", function()
  local saved, preloads = {}, {}
  local function dependency(name)
    return name == "say" or name == "luassert" or name:match("^luassert%.") ~= nil
  end
  for name, object in pairs(package.loaded) do
    if dependency(name) then saved[name] = object end
  end
  for name in pairs(saved) do package.loaded[name] = nil end
  local invoked = false
  for _, name in ipairs({ "luassert", "say", "luassert.assert" }) do
    preloads[name] = package.preload[name]
    package.preload[name] = function() invoked = true; return {} end
  end
  local fresh_loader = assert(loadfile(loader.repo_root() .. "/test/support/luassert_loader.lua"))()
  local ok, object, err = pcall(fresh_loader.load)
  local passes, fails = false, false
  if ok and object then
    passes = pcall(function() object.is.same({ a = 1 }, { a = 1 }) end)
    fails = not pcall(function() object.is_true(1) end)
  end
  local names = {}
  for name in pairs(package.loaded) do if dependency(name) then names[#names + 1] = name end end
  for _, name in ipairs(names) do package.loaded[name] = nil end
  for name, value in pairs(saved) do package.loaded[name] = value end
  for _, name in ipairs({ "luassert", "say", "luassert.assert" }) do
    package.preload[name] = preloads[name]
  end
  _expect(ok and object ~= nil and not invoked and passes and fails,
    "cache loading must bypass fake factories and retain real positive/negative assertions: " .. tostring(err))
end)

it("verified module identity cannot be replaced", function()
  local script = [[
require("test.bootstrap").install_package_paths()
local loader = require("test.support.luassert_loader")
local real = assert(loader.load())
for _, name in ipairs({ "luassert", "say" }) do
  local saved = package.loaded[name]
  package.loaded[name] = {}
  local ok, object, err = pcall(loader.load)
  package.loaded[name] = saved
  assert(ok and object == nil and tostring(err):find("identity", 1, true))
  assert(loader.load() == real)
end
print("RESTORED_REAL_IDENTITY")
]]
  local result = proc.run_command({ require("foundation.lua54").lua54_bin(), "-e",
    (script:gsub("\n", " ")) }, { cwd = loader.repo_root() })
  _expect(result.code == 0 and tostring(result.output):find("RESTORED_REAL_IDENTITY", 1, true) ~= nil,
    "verified identity contract failed:\n" .. tostring(result.output))
end)

-- ---------------------------------------------------------------- 2. 语义矩阵
-- 每条都是「正例成立 + 故意失败反例必须红」成对出现:只验正例等于没验边界,
-- 断言的真实价值全在它什么时候会红。

it("deep compare is same while identity is equal and is not", function()
  local luassert = _luassert()
  local expected = { hp = 10, tags = { "a", "b" } }
  local actual = { hp = 10, tags = { "a", "b" } }

  _must_pass(function()
    luassert.is.same(expected, actual)
  end, "is.same on equal-content tables")
  -- 身份:内容相同也仍是两个引用,is_not 过、is.equal 必红。
  _must_pass(function()
    luassert.is_not(expected, actual)
  end, "is_not on distinct references")
  _must_fail(function()
    luassert.is.equal(expected, actual)
  end, "Expected objects to be equal.", "is.equal on equal-content tables")
  -- 深比较也不是「什么都过」:内容不同必红。
  _must_fail(function()
    luassert.is.same({ hp = 10 }, { hp = 11 })
  end, "Expected objects to be the same.", "is.same on different content")
end)

it("strict boolean and truthiness are separate assertion families", function()
  local luassert = _luassert()

  _must_pass(function()
    luassert.is_true(true)
    luassert.is_false(false)
    luassert.truthy(0)
    luassert.truthy("")
    luassert.falsy(nil)
    luassert.falsy(false)
  end, "strict boolean / truthiness positives")
  -- 严格侧:唯一的真布尔才过,真值意义上的 1、nil 都不算 true。
  _must_fail(function()
    luassert.is_true(1)
  end, "(number) 1", "is_true on a truthy number")
  _must_fail(function()
    luassert.is_true(nil)
  end, "(nil)", "is_true on nil")
  _must_fail(function()
    luassert.is_false(nil)
  end, "(nil)", "is_false on nil")
  -- truthiness 侧:false 与 nil 为假,别的都为真。
  _must_fail(function()
    luassert.truthy(false)
  end, "Expected to be truthy", "truthy on false")
  _must_fail(function()
    luassert.falsy(0)
  end, "(number) 0", "falsy on 0")
end)

it("nil and false are distinguished by the nil assertions", function()
  local luassert = _luassert()

  _must_pass(function()
    luassert.is_nil(nil)
    luassert.is_not_nil(false)
    luassert.is_false(false)
    luassert.is.equal(nil, nil)
  end, "nil / false positives")
  -- false 不是 nil;nil 不是 not-nil。
  _must_fail(function()
    luassert.is_nil(false)
  end, "type nil", "is_nil on false")
  _must_fail(function()
    luassert.is_not_nil(nil)
  end, "Expected objects to not be the same.", "is_not_nil on nil")
end)

it("argument order is expected then actual in the failure message", function()
  local luassert = _luassert()
  -- LuaUnit 是 (actual, expected),luassert 是 (expected, actual)——顺序写反不会
  -- 改变红绿,只会让报错里的 Passed in / Expected 对调,是迁移期最难自查的坑。
  -- 这里把顺序钉在报错文本上。
  local message = _must_fail(function()
    luassert.is.equal("expected-side", "actual-side")
  end, "Expected objects to be equal.", "is.equal argument order")
  local expected_block = message:match("Expected:\n(.*)$")
  local passed_block = message:match("Passed in:\n(.-)\nExpected:")
  _expect(expected_block == "(string) 'expected-side'",
    "first argument must land in the Expected: block, got: " .. tostring(message))
  _expect(passed_block == "(string) 'actual-side'",
    "second argument must land in the Passed in: block, got: " .. tostring(message))
end)

it("user message is honoured across assertion families", function()
  local luassert = _luassert()
  -- 每族断言的第 N 个尾参都是自定义消息;但多个位置参数后面跟消息的那几个
  -- (matches / has_error)会先吞掉数字与布尔,所以显式列出来,不靠猜。
  local cases = {
    { assertion = "is.equal", custom = "custom-equal",
      call = function() luassert.is.equal(2, 1, "custom-equal") end },
    { assertion = "is.same", custom = "custom-same",
      call = function() luassert.is.same({ 1 }, { 2 }, "custom-same") end },
    { assertion = "is_true", custom = "custom-true",
      call = function() luassert.is_true(1, "custom-true") end },
    { assertion = "truthy", custom = "custom-truthy",
      call = function() luassert.truthy(false, "custom-truthy") end },
    { assertion = "matches", custom = "custom-match",
      call = function() luassert.matches("z", "abc", 1, true, "custom-match") end },
    { assertion = "has_error", custom = "custom-error",
      call = function() luassert.has_error(function() error("x") end, "y", "custom-error") end },
  }
  for _, case in ipairs(cases) do
    local message = _must_fail(case.call, case.custom, case.assertion)
    -- 自定义消息落在 `文件:行: ` 位置前缀之后的第一行(前缀剥法与
    -- luax.has_error / luassert.has_error 同口径:只剥一层 `:数字: `)。
    local stripped = message:gsub("^.-:%d+: ", "", 1)
    _expect(stripped:find(case.custom, 1, true) == 1,
      case.assertion .. ": the user message must be the first line of the failure, got: " .. message)
  end
end)

it("exception text is an exact match after location stripping", function()
  local luassert = _luassert()
  local boom = function()
    error("余额不足: -1")
  end

  _must_pass(function()
    -- 文本期望值是精确比较,不是子串:整条消息(含冒号与数字)必须对得上。
    luassert.has_error(boom, "余额不足: -1")
    -- 位置前缀 `文件:行: ` 只剥一层,error(msg, 0) 不产生前缀。
    luassert.has_error(function()
      error("plain", 0)
    end, "plain")
  end, "has_error exact text positives")
  -- 子串不算命中——这正是 lu.assertErrorMsgContains(子串口径)不能直译成
  -- has_error 的原因。
  _must_fail(function()
    luassert.has_error(boom, "余额不足")
  end, "Expected a different error.", "has_error with a partial text")
  -- 不抛错也算反例。
  _must_fail(function()
    luassert.has_error(function() end, "anything")
  end, "(no error)", "has_error on a function that does not raise")
end)

it("exception pattern supports lua patterns and plain substring", function()
  local luassert = _luassert()
  local boom = function()
    error("remove_by_index: index out of bounds: 7")
  end

  _must_pass(function()
    luassert.has_error.match(boom, "index out of bounds: %d+")
    luassert.has_error.match(boom, "out of bounds: 7", 1, true)
    luassert.error_matches(boom, "remove_by_index")
    luassert.has_no.errors(function() end)
  end, "error pattern positives")
  _must_fail(function()
    luassert.has_error.match(boom, "NEVER_MATCHES_THIS_PATTERN", 1, true)
  end, "(string) 'NEVER_MATCHES_THIS_PATTERN'", "has_error.match with a non-matching pattern")
  _must_fail(function()
    luassert.has_no.errors(function()
      error("boom")
    end)
  end, "Expected no error, but caught:", "has_no.errors on a raising function")
end)

it("exception type covers table payloads and type assertions", function()
  local luassert = _luassert()

  _must_pass(function()
    -- 表型 error 没有可剥的位置前缀,has_error 只能深比较。
    luassert.has_error(function()
      error({ code = 9, kind = "guard" })
    end, { code = 9, kind = "guard" })
    luassert.is_table({})
    luassert.is_string("x")
    luassert.is_number(1)
    luassert.is_function(print)
    luassert.is_boolean(true)
  end, "table payload / type assertion positives")
  -- 表型载荷深比较不等必红(不能因为「类型都是 table」放过)。
  _must_fail(function()
    luassert.has_error(function()
      error({ code = 9 })
    end, { code = 8 })
  end, "[code] = 8", "has_error with a mismatched table payload")
  _must_fail(function()
    luassert.is_string(1)
  end, "type string", "is_string on a number")
  _must_fail(function()
    luassert.is_table(1)
  end, "type table", "is_table on a number")
end)

it("luassert errors are plain while lu fail carries the luaunit failure prefix", function()
  local lu = require("luaunit")
  local luassert = _luassert()

  -- 桶归属就是前缀归属:LuaUnit 认 `FAILURE_PREFIX` 在行首或紧跟 `文件:行: `。
  local luassert_message = _must_fail(function()
    luassert.is.equal(1, 2)
  end, "Expected objects to be equal.", "luassert failure message")
  _expect(luassert_message:find(lu.FAILURE_PREFIX, 1, true) == nil,
    "luassert must not fake a LuaUnit failure: its error text has no FAILURE_PREFIX (errors bucket), got: "
      .. luassert_message)

  local lu_fail_message = _must_fail(function()
    lu.fail("断言层迁移试点")
  end, "断言层迁移试点", "lu.fail message")
  _expect(lu_fail_message:find(lu.FAILURE_PREFIX, 1, true) ~= nil,
    "lu.fail must carry FAILURE_PREFIX (failures bucket), got: " .. lu_fail_message)
end)

-- ---------------------------------------------------------------- 3. 传播契约

it("luassert counterexamples land in the errors bucket and gate the exit code", function()
  local files = {}
  for _, fixture in ipairs(_LUASSERT_FIXTURES) do
    files[#files + 1] = _FIXTURE_DIR .. fixture.basename
  end
  local result, output = _run_specs(files)

  _expect(result.code ~= nil and result.code ~= 0,
    "the old runner must exit non-zero when luassert counterexamples are present")
  -- 加载即失败会让控制用例消失、cases 变少,那样反例的红就不是断言的红。
  _expect(output:find("failed to load", 1, true) == nil,
    "fixtures must load; a load failure would make the red a false red:\n" .. output)

  local counts = _counts(output)
  _expect(counts.files == #_LUASSERT_FIXTURES,
    string.format("files=%d, expected %d", counts.files, #_LUASSERT_FIXTURES))
  _expect(counts.cases == #_LUASSERT_FIXTURES * 2,
    string.format("cases=%d, expected %d", counts.cases, #_LUASSERT_FIXTURES * 2))
  _expect(counts.passed == #_LUASSERT_FIXTURES,
    string.format("every control case must stay green: passed=%d, expected %d",
      counts.passed, #_LUASSERT_FIXTURES))
  _expect(counts.errors == #_LUASSERT_FIXTURES,
    string.format("luassert errors must land in the errors bucket: errors=%d, expected %d",
      counts.errors, #_LUASSERT_FIXTURES))
  _expect(counts.failed == 0,
    string.format("luassert errors must not be counted as failures: failed=%d", counts.failed))

  local records = _records(output)
  _expect(#records == counts.cases,
    string.format("TAP emitted %d cases but # COUNTS says %d — a case was dropped", #records, counts.cases))
  for _, fixture in ipairs(_LUASSERT_FIXTURES) do
    local control = _record(records, fixture.class .. "." .. fixture.control)
    _expect(control ~= nil and control.ok == true,
      fixture.basename .. ": the control case must be reported as ok")
    local red = _record(records, fixture.class .. "." .. fixture.counterexample)
    _expect(red ~= nil, fixture.basename .. ": the counterexample must be reported")
    _expect(red ~= nil and red.ok == false,
      fixture.basename .. ": the counterexample must be reported as not ok")
    if red ~= nil then
      _expect(red.source ~= nil and red.source:sub(-#fixture.basename) == fixture.basename,
        fixture.basename .. ": the red must be attributed to this fixture, got src=" .. tostring(red.source))
      _expect(red.message:find(fixture.fragment, 1, true) ~= nil,
        string.format("%s: expected the failure message to contain %q, got: %s",
          fixture.basename, fixture.fragment, red.message))
    end
  end
end)

it("luaunit failures bucket gates the exit code on its own", function()
  local fixture = _FAILURES_BUCKET_FIXTURE
  local result, output = _run_specs({ _FIXTURE_DIR .. fixture.basename })

  _expect(result.code ~= nil and result.code ~= 0,
    "the old runner must exit non-zero on a lu.fail counterexample")
  _expect(output:find("failed to load", 1, true) == nil,
    "the fixture must load:\n" .. output)

  -- 与 errors 桶那一轮对称:只有 failures 也能顶非零,两桶都不被忽略。
  local counts = _counts(output)
  _expect(counts.files == 1 and counts.cases == 2,
    string.format("files=%d cases=%d, expected files=1 cases=2", counts.files, counts.cases))
  _expect(counts.passed == 1 and counts.failed == 1 and counts.errors == 0,
    string.format("expected passed=1 failed=1 errors=0, got passed=%d failed=%d errors=%d",
      counts.passed, counts.failed, counts.errors))

  local records = _records(output)
  local control = _record(records, fixture.class .. "." .. fixture.control)
  local red = _record(records, fixture.class .. "." .. fixture.counterexample)
  _expect(control ~= nil and control.ok == true,
    fixture.basename .. ": the luassert control case must stay green beside a lu.fail")
  _expect(red ~= nil and red.ok == false and red.message:find(fixture.fragment, 1, true) ~= nil,
    fixture.basename .. ": the lu.fail counterexample must be reported as not ok with its own message")
end)

-- ---------------------------------------------------------------- 4. 试点对账

it("pilot case set is unchanged by the assertion switch", function()
  local command = { require("foundation.lua54").lua54_bin(), "tools/packages/test_runner/runner.lua", "--output=TAP", "--" }
  for _, file in ipairs(_PILOT_FILES) do command[#command + 1] = file end
  local result = proc.run_command(command, { cwd = loader.repo_root() })
  local output = tostring(result.output or "")

  _expect(result.code == 0, "the migrated pilot must stay green:\n" .. output)
  local counts = _counts(output)
  _expect(counts.files == #_PILOT_FILES,
    string.format("files=%d, expected %d", counts.files, #_PILOT_FILES))
  _expect(counts.cases == 45, string.format("cases=%d, expected 45", counts.cases))
  _expect(counts.passed == 45 and counts.failed == 0 and counts.errors == 0,
    string.format("expected 45/0/0, got passed=%d failed=%d errors=%d",
      counts.passed, counts.failed, counts.errors))

  -- 按显式文件身份真跑，允许 Test 类迁移成 describe，仍保住多类文件全部九例。
  for index, file in ipairs(_PILOT_FILES) do
    local single = proc.run_command({ require("foundation.lua54").lua54_bin(),
      "tools/packages/test_runner/runner.lua", "--output=TAP", "--", file },
      { cwd = loader.repo_root() })
    _expect(single.code == 0, file .. ": migrated file must stay green:\n" .. tostring(single.output))
    local actual = _counts(single.output)
    local expected = _PILOT_FILE_CASES[index]
    _expect(actual.files == 1 and actual.cases == expected and actual.passed == expected
      and actual.failed == 0 and actual.errors == 0,
      file .. ": expected complete " .. expected .. " case set:\n" .. tostring(single.output))
  end
end)

end)
