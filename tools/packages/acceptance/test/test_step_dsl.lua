local lu = require("luaunit")
local dsl = require("packages.acceptance.step_dsl")

TestStepDsl = {}

function TestStepDsl:test_passes_a_plain_sentence_through_as_an_exact_key()
  local handlers = dsl.steps({
    ["项目验收步骤已加载"] = function() return true end,
  })
  lu.assertIsFunction(handlers["项目验收步骤已加载"])
  lu.assertNil(handlers.__patterns)
end

function TestStepDsl:test_keeps_a_placeholder_sentence_verbatim()
  local seen
  local handlers = dsl.steps({
    ["玩家有<数量>个金币"] = function(_, example)
      seen = example["数量"]
      return true
    end,
  })
  -- The runtime binds <数量> from the example; the DSL only registers the key.
  local ok = handlers["玩家有<数量>个金币"]({}, { ["数量"] = "7" })
  lu.assertTrue(ok)
  lu.assertIs(seen, "7")
end

function TestStepDsl:test_strips_int_annotation_from_dispatch_key_and_coerces_the_column()
  local seen
  local handlers = dsl.steps({
    ["玩家有<数量:int>个金币"] = function(_, example)
      seen = example["数量"]
      return true
    end,
  })
  lu.assertIsFunction(handlers["玩家有<数量>个金币"])
  lu.assertNil(handlers["玩家有<数量:int>个金币"])

  local ok = handlers["玩家有<数量>个金币"]({}, { ["数量"] = "42" })
  lu.assertTrue(ok)
  lu.assertIs(seen, 42)
end

function TestStepDsl:test_passes_non_annotated_columns_through_untouched()
  local other
  local handlers = dsl.steps({
    ["玩家<玩家名>有<数量:int>个金币"] = function(_, example)
      other = example["玩家名"]
      return true
    end,
  })
  local ok = handlers["玩家<玩家名>有<数量>个金币"]({}, { ["玩家名"] = "小明", ["数量"] = "3" })
  lu.assertTrue(ok)
  lu.assertIs(other, "小明")
end

function TestStepDsl:test_fails_with_a_uniform_message_when_the_column_is_not_an_integer()
  local handlers = dsl.steps({
    ["玩家有<数量:int>个金币"] = function() return true end,
  })
  local ok, err = handlers["玩家有<数量>个金币"]({}, { ["数量"] = "abc" })
  lu.assertNil(ok)
  lu.assertEvalToTrue(err:find("invalid <数量>", 1, true), err)
  lu.assertEvalToTrue(err:find("abc", 1, true), err)
end

function TestStepDsl:test_compiles_int_capture_into_an_anchored_integer_capturing_pattern()
  local handlers = dsl.steps({
    ["玩家掷出 {点数:int} 点"] = function() return true end,
  })
  lu.assertIsTable(handlers.__patterns)
  lu.assertIs(#handlers.__patterns, 1)
  local entry = handlers.__patterns[1]
  lu.assertEquals(entry.names, { "点数" })
  lu.assertIs(entry.types["点数"], "int")
  lu.assertEvalToTrue(("玩家掷出 5 点"):match(entry.pattern))
  lu.assertNil(("玩家掷出  点"):match(entry.pattern))
end

function TestStepDsl:test_captures_a_non_empty_text_run()
  local handlers = dsl.steps({
    ["当前玩家是 {名字}"] = function() return true end,
  })
  local entry = handlers.__patterns[1]
  lu.assertIs(entry.types["名字"], "text")
  -- Non-empty: an empty run does not match.
  lu.assertNil(("当前玩家是 "):match(entry.pattern))
  lu.assertIs(("当前玩家是 小红"):match(entry.pattern), "小红")
end

function TestStepDsl:test_escapes_lua_magic_literals_so_they_match_literally()
  local handlers = dsl.steps({
    ["余额 (元) 为 {金额:int}"] = function() return true end,
  })
  local entry = handlers.__patterns[1]
  lu.assertIs(("余额 (元) 为 9"):match(entry.pattern), "9")
end

function TestStepDsl:test_errors_on_an_ordinary_key_collision()
  local base = dsl.steps({ ["步骤甲"] = function() return true end })
  local extra = dsl.steps({ ["步骤甲"] = function() return true end })
  lu.assertError(function()
    dsl.merge(base, extra, "mod_b")
  end)
end

function TestStepDsl:test_concatenates_patterns_arrays()
  local base = dsl.steps({ ["掷出 {点数:int} 点"] = function() return true end })
  local extra = dsl.steps({ ["移动 {格数:int} 格"] = function() return true end })
  dsl.merge(base, extra, "mod_b")
  lu.assertIs(#base.__patterns, 2)
end

function TestStepDsl:test_merges_ordinary_keys_without_collision()
  local base = dsl.steps({ ["步骤甲"] = function() return true end })
  local extra = dsl.steps({ ["步骤乙"] = function() return true end })
  dsl.merge(base, extra, "mod_b")
  lu.assertIsFunction(base["步骤甲"])
  lu.assertIsFunction(base["步骤乙"])
end

function TestStepDsl:test_eq_passes_on_equality_and_reports_label_expected_actual_on_failure()
  lu.assertTrue(dsl.eq(3, 3, "金币"))
  local ok, err = dsl.eq(2, 3, "金币")
  lu.assertNil(ok)
  lu.assertEvalToTrue(err:find("金币", 1, true), err)
  lu.assertEvalToTrue(err:find("期望 3", 1, true), err)
  lu.assertEvalToTrue(err:find("实际 2", 1, true), err)
end

function TestStepDsl:test_ne_passes_on_inequality()
  lu.assertTrue(dsl.ne(2, 3, "金币"))
  lu.assertNil((dsl.ne(3, 3, "金币")))
end

function TestStepDsl:test_range_is_inclusive_of_both_bounds()
  lu.assertTrue(dsl.range(1, 1, 6, "点数"))
  lu.assertTrue(dsl.range(6, 1, 6, "点数"))
  lu.assertNil((dsl.range(7, 1, 6, "点数")))
  lu.assertNil((dsl.range(0, 1, 6, "点数")))
end

function TestStepDsl:test_contains_matches_a_substring_or_a_list_element()
  lu.assertTrue(dsl.contains("玩家小明破产", "破产", "消息"))
  lu.assertTrue(dsl.contains({ "a", "b", "c" }, "b", "列表"))
  lu.assertNil((dsl.contains("玩家小明破产", "胜利", "消息")))
  lu.assertNil((dsl.contains({ "a", "b" }, "z", "列表")))
end

function TestStepDsl:test_truthy_passes_on_any_truthy_value()
  lu.assertTrue(dsl.truthy(0, "值"))
  lu.assertTrue(dsl.truthy("", "值"))
  lu.assertNil((dsl.truthy(nil, "值")))
  lu.assertNil((dsl.truthy(false, "值")))
end

function TestStepDsl:test_all_runs_checks_in_order_and_returns_the_first_failure()
  lu.assertTrue(dsl.all(
    function() return dsl.eq(1, 1, "一") end,
    function() return dsl.eq(2, 2, "二") end
  ))
  local ok, err = dsl.all(
    function() return dsl.eq(1, 1, "一") end,
    function() return dsl.eq(2, 3, "二") end,
    function() return dsl.eq(9, 9, "三") end
  )
  lu.assertNil(ok)
  lu.assertEvalToTrue(err:find("二", 1, true), err)
end


return TestStepDsl
