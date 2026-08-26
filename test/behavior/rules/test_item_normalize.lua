-- item_normalize 直测:规范化/校验辅助的边界与错误路径。
-- 这些纯函数被 choice_handlers 各 completion 复用,集成 spec 只覆盖成功路径;
-- 本 spec 补缺失/非法输入的 fail-fast 契约(变异清扫 #259 survivor 真缺口闭合)。
--
-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,断言词汇从 luassert
-- 兼容层切到 lu.assertXxx,用例数与改写前一一对应(7 例)。

-- 窄车道自备共享运行时端口基线（#217）：缺失才补装，在位 no-op。
do
  local baseline_guard = require("test.support.runtime_baseline_guard")
  if #baseline_guard.missing_ports() > 0 then
    baseline_guard.restore()
  end
end

local lu = require("luaunit")
local luax = require("test.support.luax")
local normalize = require("src.rules.choice_handlers.item_normalize")

TestItemNormalize = {}

function TestItemNormalize:test_choice_action_option_id_requires_a_numeric_action_option_id()
  -- 缺 option_id 且 required=true:报错且消息带 action 前缀(不是裸 meta)。
  luax.has_error(function()
    normalize.choice_action_option_id("k", {})
  end, "k requires numeric action.option_id")
end

function TestItemNormalize:test_is_repeatable_phase_meta_rejects_non_table_meta_and_non_repeatable_phases()
  lu.assertFalse(normalize.is_repeatable_phase_meta(nil))
  lu.assertFalse(normalize.is_repeatable_phase_meta({ phase = "post_move" }))
  lu.assertTrue(normalize.is_repeatable_phase_meta({ phase = "pre_action" }))
end

function TestItemNormalize:test_merge_after_action_anim_only_merges_table_payloads()
  local final = {}
  local merged = normalize.merge_after_action_anim({ after_action_anim = "not-a-table" }, final)
  lu.assertNil(merged.after_action_anim)

  local anim = { key = "x" }
  local merged2 = normalize.merge_after_action_anim({ after_action_anim = anim }, {})
  lu.assertIs(merged2.after_action_anim, anim)
end

function TestItemNormalize:test_item_phase_meta_rejects_an_empty_string_phase()
  luax.has_error(function()
    normalize.item_phase_meta(nil, { phase = "" }, { kind = "k" })
  end, "k requires string meta.phase")
end

function TestItemNormalize:test_item_target_meta_rejects_a_non_numeric_item_id()
  luax.has_error(function()
    normalize.item_target_meta(nil, { item_id = "abc" }, { kind = "k" })
  end, "k requires numeric meta.item_id")
end

function TestItemNormalize:test_remote_dice_meta_rejects_a_non_numeric_dice_count()
  luax.has_error(function()
    normalize.remote_dice_meta(nil, { dice_count = "abc" }, { kind = "k" })
  end, "k requires numeric meta.dice_count")
end

function TestItemNormalize:test_validate_remote_dice_meta_rejects_a_non_positive_dice_count()
  local game = { find_player_by_id = function()
    return {}
  end }
  luax.has_error(function()
    normalize.validate_remote_dice_meta(game, { player_id = 1, dice_count = 0 }, { kind = "k" })
  end, "k requires positive meta.dice_count")
end


return TestItemNormalize
