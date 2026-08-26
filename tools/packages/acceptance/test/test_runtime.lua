-- 原生 LuaUnit 迁移:四个顶层 describe(placeholder dispatch / failures / spec
-- binding / inline-capture patterns)均无钩子、无嵌套,全部拍平进单一类 TestRuntime,
-- 用例数与改写前一致(7 + 5 + 1 + 5 = 16 例);inline-capture describe 体内的
-- _pattern helper 提升为文件级 local;assert.has_no.errors 经 luax 补件等价映射。
local lu = require("luaunit")
local luax = require("test.support.luax")
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

TestRuntime = {}

-- -------------------------------------------------- placeholder dispatch

function TestRuntime:test_binds_a_differently_named_placeholder_to_the_handlers_declared_name()
  local seen
  local ir = _ir({ { text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "3" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function(_, example)
      seen = example["槽位"]
      return true
    end,
  })

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(seen, "3")
end

function TestRuntime:test_binds_several_renamed_placeholders_by_position()
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

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(slot, "2")
  lu.assertIs(product, "skin_02")
end

function TestRuntime:test_keeps_non_parameter_example_columns_readable_through_the_bound_view()
  local extra
  local ir = _ir({ { text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "3", ["赠礼名"] = "限定" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function(_, example)
      extra = example["赠礼名"]
      return true
    end,
  })

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(extra, "限定")
end

function TestRuntime:test_prefers_an_exact_step_text_handler_over_a_same_shape_handler()
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

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(called, "exact")
end

function TestRuntime:test_reports_an_ambiguous_shape_instead_of_picking_a_handler_at_random()
  local ir = _ir({ { text = "槽位<旧槽位>的皮肤已归玩家持有" } }, { { ["旧槽位"] = "1" } })
  local result = runtime.run_feature(ir, {
    ["槽位<槽位>的皮肤已归玩家持有"] = function() return true end,
    ["槽位<验证槽位>的皮肤已归玩家持有"] = function() return true end,
  })

  lu.assertFalse(result.ok)
  local message = runtime.format_failures(result)
  lu.assertEvalToTrue(message:find("ambiguous", 1, true), message)
  lu.assertEvalToTrue(message:find("槽位<槽位>的皮肤已归玩家持有", 1, true), message)
  lu.assertEvalToTrue(message:find("槽位<验证槽位>的皮肤已归玩家持有", 1, true), message)
  lu.assertEvalToTrue(message:find("features/test.feature", 1, true), message)
end

function TestRuntime:test_passes_world_resolved_text_and_the_step_to_the_handler()
  local resolved, keyword, world_seen
  local ir = _ir({ { keyword = "Then", text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "3" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function(world, _, step, resolved_text)
      world.touched = true
      world_seen, keyword, resolved = world, step.keyword, resolved_text
      return true
    end,
  })

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(resolved, "玩家穿上槽位3的皮肤")
  lu.assertIs(keyword, "Then")
  lu.assertTrue(world_seen.touched)
end

-- -------------------------------------------------- failures

function TestRuntime:test_rejects_a_step_no_handler_shape_matches()
  local ir = _ir({ { text = "无人认领的步骤<槽位>" } }, { { ["槽位"] = "1" } })
  local result = runtime.run_feature(ir, {})

  lu.assertFalse(result.ok)
  local message = runtime.format_failures(result)
  lu.assertEvalToTrue(message:find("unsupported step", 1, true), message)
  lu.assertEvalToTrue(message:find("无人认领的步骤<槽位>", 1, true), message)
  lu.assertEvalToTrue(message:find("features/test.feature:第11行", 1, true), message)
end

function TestRuntime:test_names_the_chinese_column_when_the_example_has_no_value_for_a_placeholder()
  local ir = _ir(
    { { text = "玩家穿上槽位<p1>的皮肤" } },
    { { ["其他列"] = "x" } },
    { field_names = { p1 = "新槽位" } }
  )
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function() return true end,
  })

  lu.assertFalse(result.ok)
  local message = runtime.format_failures(result)
  lu.assertEvalToTrue(message:find("missing example value", 1, true), message)
  lu.assertEvalToTrue(message:find("新槽位", 1, true), message)
end

function TestRuntime:test_surfaces_a_handlers_own_failure_message()
  local ir = _ir({ { text = "玩家穿上槽位<新槽位>的皮肤" } }, { { ["新槽位"] = "9" } })
  local result = runtime.run_feature(ir, {
    ["玩家穿上槽位<槽位>的皮肤"] = function() return nil, "no skin at slot 9" end,
  })

  lu.assertFalse(result.ok)
  lu.assertEvalToTrue(runtime.format_failures(result):find("no skin at slot 9", 1, true))
end

function TestRuntime:test_runs_background_steps_before_scenario_steps_and_reports_each_example()
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

  lu.assertFalse(result.ok)
  lu.assertEquals(calls, { "background", "equip:1", "background", "equip:2" })
  lu.assertIs(#result.failures, 2)
  lu.assertIs(result.failures[1].name, "测试场景/example_1")
  lu.assertEvalToTrue(runtime.format_failures(result):find("boom 2", 1, true))
end

-- -------------------------------------------------- spec binding

function TestRuntime:test_defines_one_spec_per_example()
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

  lu.assertIs(#defined, 2)
  lu.assertIs(defined[1].name, "测试场景/example_1")
  lu.assertIs(defined[2].name, "测试场景/example_2")
  luax.has_no_error(defined[1].fn)
end

-- -------------------------------------------------- inline-capture patterns

function TestRuntime:test_matches_a_pattern_when_exact_and_shape_both_miss_coercing_int_captures()
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

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(seen, 5)
end

function TestRuntime:test_matches_against_the_resolved_step_text_not_the_raw_placeholder()
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

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(seat, 2)
  lu.assertIs(deity, "财神")
  lu.assertIs(turns, 3)
end

function TestRuntime:test_prefers_an_exact_handler_over_a_matching_pattern()
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

  lu.assertTrue(result.ok, runtime.format_failures(result))
  lu.assertIs(called, "exact")
end

function TestRuntime:test_reports_an_ambiguous_pattern_when_two_patterns_match()
  local ir = _ir({ { text = "值 7" } }, { {} })
  local result = runtime.run_feature(ir, {
    __patterns = {
      _pattern("值 {a}", "^值 (.+)$", { "a" }, { ["a"] = "text" }, function() return true end),
      _pattern("值 {b}", "^值 (.+)$", { "b" }, { ["b"] = "text" }, function() return true end),
    },
  })

  lu.assertFalse(result.ok)
  local message = runtime.format_failures(result)
  lu.assertEvalToTrue(message:find("ambiguous pattern", 1, true), message)
  lu.assertEvalToTrue(message:find("值 {a}", 1, true), message)
  lu.assertEvalToTrue(message:find("值 {b}", 1, true), message)
end

function TestRuntime:test_hints_the_nearest_pattern_when_nothing_matches()
  local ir = _ir({ { text = "玩家掷出 abc 点" } }, { {} })
  local result = runtime.run_feature(ir, {
    __patterns = {
      _pattern("玩家掷出 {点数:int} 点", "^玩家掷出 (-?%d+) 点$", { "点数" }, { ["点数"] = "int" }, function() return true end),
    },
  })

  lu.assertFalse(result.ok)
  local message = runtime.format_failures(result)
  lu.assertEvalToTrue(message:find("unsupported step", 1, true), message)
  lu.assertEvalToTrue(message:find("最近候选", 1, true), message)
end


return TestRuntime
