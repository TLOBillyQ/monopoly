-- Runtime public-seam assertions use the trusted project luassert module.
require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
local runtime = require("packages.acceptance.runtime")

-- Build a one-scenario IR by hand. The parser keeps Chinese placeholder names in
-- step.text and Chinese column names as example keys, so the fixtures do too.
local function _ir(steps, examples, opts)
  opts = opts or {}
  local scenario_steps = {}
  for index, step in ipairs(steps) do
    scenario_steps[index] = {
      keyword = step.keyword or "Given",
      text = step.text,
      metadata = { source_path = "features/test.feature", source_line = 10 + index },
    }
  end
  return {
    name = "测试功能",
    metadata = { source_path = "features/test.feature", field_names = opts.field_names or {} },
    background = opts.background or {},
    scenarios = { { name = "测试场景", steps = scenario_steps, examples = examples or { {} } } },
  }
end

-- The DSL builds these entries; the fixtures spell them out so the runtime's
-- third dispatch tier is exercised without depending on step_dsl.
local function _pattern(source_text, pattern, names, types, fn)
  return { source = source_text, pattern = pattern, names = names, types = types, fn = fn }
end

describe("acceptance runtime public dispatch and cleanup", function()

-- -------------------------------------------------- placeholder dispatch

it("binds a differently named placeholder to the handler name", function()
  local seen
  local ir = _ir({ { text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "3" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function(_, example)
      seen = example["槽位"]
      return true
    end,
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(seen, "3")
end)

it("binds several renamed placeholders by position", function()
  local slot, product
  local ir = _ir(
    { { text = "槽位<购买槽位>对应皮肤产品ID为<购买产品ID>" } },
    { { ["购买槽位"] = "2", ["购买产品ID"] = "skin_02" } }
  )
  local result = runtime.run_feature(ir, {
    ["槽位<槽位>对应皮肤产品ID为<产品ID>"] = function(_, example)
      slot, product = example["槽位"], example["产品ID"]
      return true
    end,
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(slot, "2")
  luassert.is.equal(product, "skin_02")
end)

it("keeps non parameter example columns readable", function()
  local extra
  local ir = _ir({ { text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "3", ["赠礼名"] = "限定" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function(_, example)
      extra = example["赠礼名"]
      return true
    end,
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(extra, "限定")
end)

it("prefers exact text over a same shape handler", function()
  -- 验证槽位 carries assert-only semantics that the 槽位 handler must not steal.
  local called
  local ir = _ir({ { text = "槽位<验证槽位>的皮肤已归玩家持有" } }, { { ["验证槽位"] = "1" } })
  local result = runtime.run_feature(ir, {
    ["槽位<槽位>的皮肤已归玩家持有"] = function()
      called = "shape"
      return true
    end,
    ["槽位<验证槽位>的皮肤已归玩家持有"] = function()
      called = "exact"
      return true
    end,
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(called, "exact")
end)

it("reports an ambiguous shape", function()
  local ir = _ir({ { text = "槽位<旧槽位>的皮肤已归玩家持有" } }, { { ["旧槽位"] = "1" } })
  local result = runtime.run_feature(ir, {
    ["槽位<槽位>的皮肤已归玩家持有"] = function() return true end,
    ["槽位<验证槽位>的皮肤已归玩家持有"] = function() return true end,
  })

  luassert.is_false(result.ok)
  local message = runtime.format_failures(result)
  luassert.truthy(message:find("ambiguous", 1, true), message)
  luassert.truthy(message:find("槽位<槽位>的皮肤已归玩家持有", 1, true), message)
  luassert.truthy(message:find("槽位<验证槽位>的皮肤已归玩家持有", 1, true), message)
  luassert.truthy(message:find("features/test.feature", 1, true), message)
end)

it("passes world resolved text and step to the handler", function()
  local resolved, keyword, world_seen
  local ir = _ir({ { keyword = "Then", text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "3" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function(world, _, step, resolved_text)
      world.touched = true
      world_seen, keyword, resolved = world, step.keyword, resolved_text
      return true
    end,
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(resolved, "玩家穿上槽位3的皮肤")
  luassert.is.equal(keyword, "Then")
  luassert.is_true(world_seen.touched)
end)

-- -------------------------------------------------- failures

it("rejects a step without a matching handler", function()
  local ir = _ir({ { text = "无人认领的步骤<槽位>" } }, { { ["槽位"] = "1" } })
  local result = runtime.run_feature(ir, {})

  luassert.is_false(result.ok)
  local message = runtime.format_failures(result)
  luassert.truthy(message:find("unsupported step", 1, true), message)
  luassert.truthy(message:find("无人认领的步骤<槽位>", 1, true), message)
  luassert.truthy(message:find("features/test.feature:第11行", 1, true), message)
end)

it("names the Chinese column for missing example value", function()
  local ir = _ir(
    { { text = "玩家穿上槽位<p1>的皮肤" } },
    { { ["其他列"] = "x" } },
    { field_names = { p1 = "新槽位" } }
  )
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function() return true end,
  })

  luassert.is_false(result.ok)
  local message = runtime.format_failures(result)
  luassert.truthy(message:find("missing example value", 1, true), message)
  luassert.truthy(message:find("新槽位", 1, true), message)
end)

it("surfaces the handler failure message", function()
  local ir = _ir({ { text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "9" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function() return nil, "no skin at slot 9" end,
  })

  luassert.is_false(result.ok)
  luassert.truthy(runtime.format_failures(result):find("no skin at slot 9", 1, true))
end)

it("runs background before scenario and reports each example", function()
  local calls = {}
  local ir = _ir(
    { { text = "玩家穿上槽位<新槽位>的皮肤" } },
    { { ["新槽位"] = "1" }, { ["新槽位"] = "2" } },
    {
      background = {
        { keyword = "Given", text = "皮肤商店已打开", metadata = { source_line = 5 } },
      },
    }
  )
  local result = runtime.run_feature(ir, {
    ["皮肤商店已打开"] = function()
      calls[#calls + 1] = "background"
      return true
    end,
    ["玩家穿上槽位<槽位>的皮肤"] = function(_, example)
      calls[#calls + 1] = "equip:" .. tostring(example["槽位"])
      return nil, "boom " .. tostring(example["槽位"])
    end,
  })

  luassert.is_false(result.ok)
  luassert.is.same({ "background", "equip:1", "background", "equip:2" }, calls)
  luassert.is.equal(#result.failures, 2)
  luassert.is.equal(result.failures[1].name, "测试场景/example_1")
  luassert.truthy(runtime.format_failures(result):find("boom 2", 1, true))
end)

-- -------------------------------------------------- spec binding

it("defines one spec per example", function()
  local defined = {}
  local ir = _ir(
    { { text = "玩家穿上槽位<新槽位>的皮肤" } },
    { { ["新槽位"] = "1" }, { ["新槽位"] = "2" } }
  )
  runtime.define_specs(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function() return true end,
  }, function(name, fn)
    defined[#defined + 1] = { name = name, fn = fn }
  end)

  luassert.is.equal(#defined, 2)
  luassert.is.equal(defined[1].name, "测试场景/example_1")
  luassert.is.equal(defined[2].name, "测试场景/example_2")
  luassert.has_no.errors(defined[1].fn)
end)

-- -------------------------------------------------- inline-capture patterns

it("matches fallback pattern and coerces integer captures", function()
  local seen
  local ir = _ir({ { text = "玩家掷出 5 点" } }, { {} })
  local result = runtime.run_feature(ir, {
    __patterns = {
      _pattern("玩家掷出 {点数:int} 点", "^玩家掷出 (-?%d+) 点$", { "点数" }, { ["点数"] = "int" }, function(_, binding)
        seen = binding["点数"]
        return true
      end),
    },
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(seen, 5)
end)

it("matches patterns against resolved step text", function()
  -- A pruned Examples column leaves a step that mixes a literal with a live
  -- placeholder (`玩家2附体<神灵>持续3回合`). The pattern tier must see the
  -- example value, not the `<神灵>` spelling.
  local seat, deity, turns
  local ir = _ir({ { text = "玩家2附体<神灵>持续3回合" } }, { { ["神灵"] = "财神" } })
  local result = runtime.run_feature(ir, {
    __patterns = {
      _pattern(
        "玩家{座号:int}附体{神灵}持续{回合数:int}回合",
        "^玩家(-?%d+)附体(.-)持续(-?%d+)回合$",
        { "座号", "神灵", "回合数" },
        { ["座号"] = "int", ["回合数"] = "int" },
        function(_, binding)
          seat, deity, turns = binding["座号"], binding["神灵"], binding["回合数"]
          return true
        end
      ),
    },
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(seat, 2)
  luassert.is.equal(deity, "财神")
  luassert.is.equal(turns, 3)
end)

it("prefers exact handler over matching pattern", function()
  local called
  local ir = _ir({ { text = "玩家掷出 5 点" } }, { {} })
  local result = runtime.run_feature(ir, {
    ["玩家掷出 5 点"] = function() called = "exact"; return true end,
    __patterns = {
      _pattern("玩家掷出 {点数:int} 点", "^玩家掷出 (-?%d+) 点$", { "点数" }, { ["点数"] = "int" }, function()
        called = "pattern"; return true
      end),
    },
  })

  luassert.is_true(result.ok, runtime.format_failures(result))
  luassert.is.equal(called, "exact")
end)

it("reports ambiguity when two patterns match", function()
  local ir = _ir({ { text = "值 7" } }, { {} })
  local result = runtime.run_feature(ir, {
    __patterns = {
      _pattern("值 {a}", "^值 (.+)$", { "a" }, { ["a"] = "text" }, function() return true end),
      _pattern("值 {b}", "^值 (.+)$", { "b" }, { ["b"] = "text" }, function() return true end),
    },
  })

  luassert.is_false(result.ok)
  local message = runtime.format_failures(result)
  luassert.truthy(message:find("ambiguous pattern", 1, true), message)
  luassert.truthy(message:find("值 {a}", 1, true), message)
  luassert.truthy(message:find("值 {b}", 1, true), message)
end)

it("hints nearest pattern when nothing matches", function()
  local ir = _ir({ { text = "玩家掷出 abc 点" } }, { {} })
  local result = runtime.run_feature(ir, {
    __patterns = {
      _pattern("玩家掷出 {点数:int} 点", "^玩家掷出 (-?%d+) 点$", { "点数" }, { ["点数"] = "int" }, function() return true end),
    },
  })

  luassert.is_false(result.ok)
  local message = runtime.format_failures(result)
  luassert.truthy(message:find("unsupported step", 1, true), message)
  luassert.truthy(message:find("最近候选", 1, true), message)
end)

it("failure runs deferred cleanup before next example", function()
  local patched = false
  local ir = _ir({ { text = "临时补丁" }, { text = "故意失败" } }, { {}, {} })
  local result = runtime.run_feature(ir, {
    ["临时补丁"] = function(world)
      luassert.is_false(patched)
      patched = true
      world.defer(function() patched = false end)
      return true
    end,
    ["故意失败"] = function() return false, "预期失败" end,
  })
  luassert.is_false(result.ok)
  luassert.is.equal(2, #result.failures)
  luassert.is_false(patched)
end)
end)
