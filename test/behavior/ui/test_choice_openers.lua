-- choice_openers.lua 直测:覆盖导出 helper 函数的未测分支
-- (_set_action_button / store_target_button_labels / _compact_options /
--  _sync_slot_label / _sync_projection_node / _sync_option_slot /
--  resolve_player_or_remote_options / fill_option_nodes / open_choice_modal)
local lu = require("luaunit")
local support = require("test.support.shared_support")

local _assert_eq = support.assert_eq
local openers = require("src.ui.coord.choice_openers")
local screens_registry = require("src.ui.screens_registry")
local screen_openers_seam = require("src.ui.seams.screen_openers")

TestChoiceOpeners = {}

-- _set_action_button: name 为 nil 时跳过,set_button 与控件状态都不被触及
function TestChoiceOpeners:test_set_action_button_skips_when_name_nil()
  local button_calls = {}
  local ui = {
    set_button = function(_, name, label)
      button_calls[#button_calls + 1] = {name, label}
    end,
  }
  local state_calls = {}
  local ui_controls = require("src.ui.render.support.ui_controls")
  local orig = ui_controls.set_control_state
  ui_controls.set_control_state = function(_, node, state)
    state_calls[#state_calls + 1] = {node, state}
  end

  openers.set_action_button(ui, nil, true, true, "测试")

  ui_controls.set_control_state = orig
  lu.assertEquals(#button_calls, 0)
  lu.assertEquals(#state_calls, 0)
end

-- _set_action_button: 同时 visible 且有 label 时调用 set_button
function TestChoiceOpeners:test_set_action_button_sets_label_when_visible_and_label_given()
  local calls = {}
  local ui = {
    set_button = function(_, name, label)
      calls[#calls + 1] = {name, label}
    end,
  }
  -- 需要 mock ui_controls.set_control_state
  local ui_controls = require("src.ui.render.support.ui_controls")
  local orig = ui_controls.set_control_state
  ui_controls.set_control_state = function() end

  openers.set_action_button(ui, "btn1", true, true, "开始")

  ui_controls.set_control_state = orig
  lu.assertEquals(#calls, 1)
  lu.assertEquals(calls[1][1], "btn1")
  lu.assertEquals(calls[1][2], "开始")
end

-- _set_action_button: label 为 nil 时不调 set_button
function TestChoiceOpeners:test_set_action_button_skips_label_when_label_nil()
  local calls = {}
  local ui = {
    set_button = function(_, name, label)
      calls[#calls + 1] = {name, label}
    end,
  }
  local ui_controls = require("src.ui.render.support.ui_controls")
  local orig = ui_controls.set_control_state
  ui_controls.set_control_state = function() end

  openers.set_action_button(ui, "btn1", true, true, nil)

  ui_controls.set_control_state = orig
  lu.assertEquals(#calls, 0)
end

-- _store_target_button_labels: choice 带 cancel_label
function TestChoiceOpeners:test_store_target_button_labels_with_choice_cancel_label()
  local screen = {}
  openers.store_target_button_labels(screen, { cancel_label = "返回" })
  lu.assertEquals(screen.confirm_label, "确定")
  lu.assertEquals(screen.cancel_label, "返回")
end

-- _store_target_button_labels: choice 不带 cancel_label → 默认 "取消"
function TestChoiceOpeners:test_store_target_button_labels_defaults_cancel()
  local screen = {}
  openers.store_target_button_labels(screen, {})
  lu.assertEquals(screen.confirm_label, "确定")
  lu.assertEquals(screen.cancel_label, "取消")
end

-- _store_target_button_labels: choice 为 nil
function TestChoiceOpeners:test_store_target_button_labels_nil_choice()
  local screen = {}
  openers.store_target_button_labels(screen, nil)
  lu.assertEquals(screen.confirm_label, "确定")
  lu.assertEquals(screen.cancel_label, "取消")
end

-- _compact_options: 过滤尾随 nil 元素
function TestChoiceOpeners:test_resolve_player_or_remote_options_compact_nils()
  -- ipairs 在第一个 nil 处停止，所以只能过滤尾随 nil
  local result = openers.resolve_player_or_remote_options(
    { options = { "a", nil, "b", nil } }, "remote"
  )
  -- ipairs({"a", nil, "b", nil}) 只迭代 "a" (index 1)，在 index 2 的 nil 处停止
  lu.assertEquals(#result, 1)
  lu.assertEquals(result[1], "a")
end

-- _compact_options: options 为空
function TestChoiceOpeners:test_resolve_player_or_remote_options_empty()
  local result = openers.resolve_player_or_remote_options({}, "remote")
  lu.assertEquals(#result, 0)
end

-- resolve_player_or_remote_options: player screen 走 target_slot_layout
function TestChoiceOpeners:test_resolve_player_or_remote_options_with_target_layout()
  local result = openers.resolve_player_or_remote_options(
    { options = { "x", "y", "z" }, target_slot_layout = { 3, 1, 2 } }, "player"
  )
  -- 按 layout 重排: layout[1]=3→slot[3]="x", layout[2]=1→slot[1]="y", layout[3]=2→slot[2]="z"
  lu.assertEquals(result[3], "x")
  lu.assertEquals(result[1], "y")
  lu.assertEquals(result[2], "z")
end

-- resolve_player_or_remote_options: player screen 无 layout 走 compact
function TestChoiceOpeners:test_resolve_player_or_remote_options_player_no_layout()
  local result = openers.resolve_player_or_remote_options(
    { options = { "a", "b" } }, "player"
  )
  lu.assertEquals(#result, 2)
  lu.assertEquals(result[1], "a")
  lu.assertEquals(result[2], "b")

  -- player 屏无 layout 时走 compact(ipairs 在首个空洞处截断),不得原样返回
  local compacted = openers.resolve_player_or_remote_options(
    { options = { "a", nil, "c" } }, "player"
  )
  lu.assertEquals(#compacted, 1, "compact should stop at the first nil option")
  lu.assertEquals(compacted[3], nil, "compact must not keep options after the hole")
end

-- order_target_options: 无 layout 返回原 options
function TestChoiceOpeners:test_order_target_options_no_layout_returns_original()
  local result = openers.order_target_options({ options = { "a", "b" } })
  lu.assertEquals(#result, 2)
  lu.assertEquals(result[1], "a")
  lu.assertEquals(result[2], "b")
end

-- open_choice_modal: base_inline/market 屏早退,registry 不得被触及(#332)。
function TestChoiceOpeners:test_open_choice_modal_early_returns_without_registry()
  local consulted = 0
  local function _run_with_registry_guard(choice)
    local result
    support.with_patches({
      {
        target = screens_registry,
        key = "opener_for",
        value = function()
          consulted = consulted + 1
          error("registry must not be consulted for screenless routes")
        end,
      },
    }, function()
      result = openers.open_choice_modal({}, choice, nil, screens_registry.opener_for)
    end)
    return result
  end

  lu.assertEvalToTrue(_run_with_registry_guard({ route_key = "base_inline" }) == false,
    "base_inline route should return false without consulting the registry")
  lu.assertEvalToTrue(_run_with_registry_guard({ route_key = "market" }) == false,
    "market route should return false without consulting the registry")
  _assert_eq(consulted, 0, "screenless routes must never reach the registry opener")
end

-- open_choice_modal: registry 有 opener 时开屏成功并返回 true。
function TestChoiceOpeners:test_open_choice_modal_success_path_returns_true()
  local opened = 0
  local result
  support.with_patches({
    {
      target = screens_registry,
      key = "opener_for",
      value = function()
        return function()
          opened = opened + 1
        end
      end,
    },
  }, function()
    result = openers.open_choice_modal({}, { route_key = "secondary_confirm" }, nil, screens_registry.opener_for)
  end)
  lu.assertEvalToTrue(result == true, "a registered screen should open and report true")
  _assert_eq(opened, 1, "the registry opener should be invoked once")
end

-- open_choice_modal: 未知屏 key → 留痕并返回 false(#332 装配遗漏即刻暴露)。
function TestChoiceOpeners:test_open_choice_modal_unknown_key_warns_and_returns_false()
  local warns = {}
  local result
  support.with_patches({
    {
      target = screens_registry,
      key = "opener_for",
      value = function()
        return nil
      end,
    },
    {
      target = require("src.foundation.log"),
      key = "warn",
      value = function(...)
        warns[#warns + 1] = table.concat({ ... }, " ")
      end,
    },
  }, function()
    result = openers.open_choice_modal({}, { route_key = "secondary_confirm" }, nil, screens_registry.opener_for)
  end)
  lu.assertEvalToTrue(result == false, "an unknown screen key should yield false")
  _assert_eq(#warns, 1, "an unknown screen key should leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("unsupported choice screen key", 1, true) ~= nil,
    "warn should carry the skip reason; got " .. tostring(warns[1]))
  lu.assertEvalToTrue(warns[1]:find("secondary_confirm", 1, true) ~= nil,
    "warn should carry the screen key context; got " .. tostring(warns[1]))
end

-- fill_option_nodes:槽位标签文案与显隐状态按 option 有无同步。
function TestChoiceOpeners:test_fill_option_nodes_syncs_labels_and_control_states()
  local labels = {}
  local states = {}
  local button_texts = {}
  local ui = {
    set_label = function(_, node, text)
      labels[node] = text
    end,
    set_button = function(_, name, text)
      button_texts[name] = text
    end,
  }
  local screen = {
    option_buttons = { "btn_1", "btn_2" },
    slot_labels = { "lbl_1", "lbl_2" },
    slot_projections = { "proj_1", "proj_2" },
  }
  local option_ids, selected
  support.with_patches({
    {
      target = require("src.ui.coord.choice_helpers"),
      key = "set_option_node",
      value = function(_, name)
        return name .. "_id"
      end,
    },
    {
      target = require("src.ui.render.support.ui_controls"),
      key = "set_control_state",
      value = function(_, node, state)
        states[node] = state
      end,
    },
  }, function()
    option_ids, selected = openers.fill_option_nodes(ui, screen, {
      { label = "A" },
      nil,
    })
    openers.fill_option_nodes(ui, screen, { { label = "B" } }, { clear_button_text = true })
  end)
  _assert_eq(option_ids[1], "btn_1_id", "the first option id should come from the option node")
  _assert_eq(selected, "btn_1_id", "the first filled option is the selected one")
  _assert_eq(labels.lbl_1, "B", "a present option should carry its label")
  _assert_eq(labels.lbl_2, "", "a missing option should clear the label")
  _assert_eq(states.lbl_1.visible, true, "a present option shows its slot")
  _assert_eq(states.lbl_1.touch_enabled, false, "slot labels are never touch enabled")
  _assert_eq(states.lbl_2.visible, false, "a missing option hides its slot")
  _assert_eq(states.proj_1.visible, true, "a present option shows its projection node")
  _assert_eq(states.proj_1.touch_enabled, false, "projection nodes are never touch enabled")
  _assert_eq(states.proj_2.visible, false, "a missing option hides its projection node")
  _assert_eq(button_texts.btn_1, "", "clear_button_text should blank the option button")
end

-- open_screen 的标题/正文文案:choice 显式值优先,缺省回落默认文案。
function TestChoiceOpeners:test_open_screen_copy_falls_back_to_default_copy()
  local writes = {}
  local canvas_args = {}
  local ui = {
    choice_screens = {
      test_screen = { title = "t", body = "b", root = {} },
    },
    set_label = function(_, node, text)
      writes[#writes + 1] = { node = node, text = text }
    end,
  }
  support.with_patches({
    {
      target = require("src.ui.coord.choice_helpers"),
      key = "hide_choice_screens",
      value = function() end,
    },
    {
      target = require("src.ui.render.support.ui_controls"),
      key = "set_control_state",
      value = function() end,
    },
    {
      target = require("src.ui.coord.choice_helpers"),
      key = "switch_modal_canvas",
      value = function(_, canvas)
        canvas_args[#canvas_args + 1] = canvas
      end,
    },
    {
      target = require("src.ui.state.panel_interrupt"),
      key = "interrupt",
      value = function() end,
    },
  }, function()
    openers.open_screen({ ui = ui }, "test_screen", { title = "自定义标题" })
    openers.open_screen({ ui = ui }, "test_screen", {})
  end)
  _assert_eq(writes[1].text, "自定义标题", "an explicit title should win")
  _assert_eq(writes[2].text, "", "a missing body should fall back to empty")
  _assert_eq(writes[3].text, "请选择", "a missing title should fall back to the default copy")
  _assert_eq(writes[4].text, "", "a missing body should fall back to empty on the second open")
  lu.assertEvalToTrue(canvas_args[1] ~= nil, "the canvas switch must receive the resolved canvas")
end

-- 二次确认开屏经 screen_openers 接缝委托:返回值原样穿透(#332)。
function TestChoiceOpeners:test_open_pre_confirm_screen_forwards_through_the_seam()
  local received = nil
  local result
  support.with_patches({
    {
      target = screen_openers_seam,
      key = "open_pre_confirm",
      value = function(state, choice, option_id, title, body)
        received = { state = state, choice = choice, option_id = option_id, title = title, body = body }
        return "seam_ret"
      end,
    },
  }, function()
    result = openers.open_pre_confirm_screen({ s = 1 }, { c = 1 }, 7, "标题", "正文")
  end)
  lu.assertEvalToTrue(result == "seam_ret", "open_pre_confirm_screen should return the seam's value")
  _assert_eq(received.option_id, 7, "option_id should pass through")
  _assert_eq(received.title, "标题", "title should pass through")
end

return TestChoiceOpeners
