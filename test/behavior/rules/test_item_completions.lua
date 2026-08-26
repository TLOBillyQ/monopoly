-- item_completions 直测:completion 组装与 item_target_handler 描述表的边界契约。
-- 集成 spec(item_completions_closure 等)覆盖成功路径;本 spec 补 helper 桩直驱的
-- 参数形状与描述表默认值(变异清扫 #259 survivor 真缺口闭合)。
--
-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,断言词汇从 luassert
-- 兼容层切到 lu.assertXxx,用例数与改写前一一对应(5 例)。
local lu = require("luaunit")
local luax = require("test.support.luax")
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local item_phase = require("src.rules.items.phase")
local normalize = require("src.rules.choice_handlers.item_normalize")
local completions = require("src.rules.choice_handlers.item_completions")

local function _make_game()
  return {
    turn = {},
    find_player_by_id = function(_, pid)
      return { id = pid }
    end,
  }
end

TestItemCompletions = {}

function TestItemCompletions:test_settle_choice_window_finishes_the_settled_window_with_an_explicit_false_flag()
  local calls = {}
  local complete = completions.build({
    finish_choice = function(game, flag)
      calls[#calls + 1] = { game = game, flag = flag }
    end,
    finish_active_item_phase = function() end,
  })
  local game = _make_game()

  lu.assertNil(complete.settle_choice_window(game, nil))
  lu.assertEvalToTrue(#calls == 1 and calls[1].game == game, "nil completion settles the window")
  lu.assertEquals(calls[1].flag, false, "finish_choice receives an explicit false, not true")
end

function TestItemCompletions:test_settle_choice_window_keeps_the_window_untouched_on_stay_or_reopened()
  local calls = 0
  local complete = completions.build({
    finish_choice = function()
      calls = calls + 1
    end,
    finish_active_item_phase = function() end,
  })
  local game = _make_game()

  local stay = { stay = true }
  local stay_result = complete.settle_choice_window(game, stay)
  lu.assertIs(stay_result, stay)
  local reopened = { reopened = true }
  local reopened_result = complete.settle_choice_window(game, reopened)
  lu.assertIs(reopened_result, reopened)
  lu.assertEquals(calls, 0, "stay/reopened completions must not finish the choice window")
end

function TestItemCompletions:test_followup_cancel_defaults_elapsed_seconds_to_0_when_the_clock_field_is_absent()
  local complete = completions.build({
    finish_choice = function() end,
    finish_active_item_phase = function() end,
  })
  local game = _make_game()

  local captured = nil
  with_patches({
    { target = item_phase, key = "reopen_or_finish", value = function(_, _, _, open_opts)
      captured = open_opts
      return true
    end },
  }, function()
    local result = complete.followup_cancel(game, {
      kind = "k",
      meta = { player_id = 1, phase = "pre_action" },
    })
    lu.assertEvalToTrue(result and result.stay == true, "reopened phase asks the flow to stay")
  end)

  lu.assertNotNil(captured, "reopen_or_finish should be consulted")
  lu.assertEquals(captured.elapsed_seconds, 0, "absent choice_elapsed_seconds falls back to 0")
end

function TestItemCompletions:test_item_target_handler_pins_required_meta_and_default_seams()
  local execute_fn = function() end
  local handler = completions.item_target_handler("k", execute_fn, {})

  lu.assertEvalToTrue(#handler.required_meta == 2
    and handler.required_meta[1] == "player_id"
    and handler.required_meta[2] == "item_id",
    "required_meta declares player_id and item_id")
  lu.assertIs(handler.normalize_meta, normalize.item_target_meta)
  lu.assertIs(handler.meta_validator, normalize.validate_item_owner_meta)
  lu.assertIs(handler.execute, execute_fn)
end

function TestItemCompletions:test_item_target_handler_normalize_action_normalizes_option_id_through_the_kind()
  local handler = completions.item_target_handler("k", function() end, {})
  local action = { option_id = 7 }

  local normalized = handler.normalize_action(nil, nil, action)

  lu.assertEvalToTrue(normalized ~= nil and normalized.option_id == 7, "option_id survives normalization")
  lu.assertNotIs(normalized, action, "normalization returns a copy, not the original")
  luax.has_error(function()
    handler.normalize_action(nil, nil, {})
  end, "k requires numeric action.option_id")
end


return TestItemCompletions
