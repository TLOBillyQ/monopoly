-- src/ui/coord/modal.lua 的开关屏流程规约。首跑变异的幸存集中在:
-- skip-reopen 判定（同 choice 重复开屏 / market 豁免）、base_inline 的
-- 二次确认门控与 suppress-highlight 记号、item_phase_passive 接管、
-- _validate_choice 的拒绝返回值,以及 popup 在场时的关屏回画布路径。
-- 状态按规约内联铺陈,不抽 state helper(见 view_command_mutation_pin_spec 头注)。
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):五个 describe 均无钩子,合并拍平为
-- TestChoiceModalPresenter 单类;it 名全为中文,按「原名逐字保留」用 table
-- key 赋值写法;裸 assert(cond, msg) 机械映射为 lu.assertEvalToTrue,用例数
-- 与改写前一一对应(3+2+1+1+1 = 8 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local modal_presenter = require("src.ui.coord.modal")
local modal_state = require("src.ui.state.modal")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local choice_openers = require("src.ui.coord.choice_openers")
local secondary_confirm_screen = require("src.ui.screens.secondary_confirm")
local choice_common = require("src.ui.coord.choice_helpers")
local popup = require("src.ui.coord.popup")
local market_presenter = require("src.ui.screens.market")
local canvas = require("src.ui.coord.canvas_coordinator")
local runtime_state = require("src.ui.state.runtime")
local logger = require("src.foundation.log")

TestChoiceModalPresenter = {}

TestChoiceModalPresenter["test_同一个非 market choice 的屏已开着时,重复 open 被整体跳过"] = function()
  local dirty_calls = 0
  local opener_calls = 0
  local market_close_calls = 0
  local state = {
    ui = { choice_active = true, active_choice_screen_key = "target_pick", market_active = false },
  }
  runtime_state.set_pending_choice_id(state, 42)

  _with_patches({
    { target = choice_common, key = "resolve_screen_key", value = function() return "target_pick" end },
    { target = runtime_state, key = "set_ui_dirty", value = function() dirty_calls = dirty_calls + 1 end },
    { target = choice_openers, key = "open_choice_modal", value = function() opener_calls = opener_calls + 1 end },
    { target = market_presenter, key = "close", value = function() market_close_calls = market_close_calls + 1 end },
  }, function()
    modal_presenter.open_choice_modal(state, { id = 42 })
  end)

  _assert_eq(dirty_calls, 0, "a skipped reopen must not dirty the ui")
  _assert_eq(opener_calls, 0, "a skipped reopen must not re-run the generic choice opener")
  _assert_eq(market_close_calls, 0, "a skipped reopen must not touch the market screen")
end

TestChoiceModalPresenter["test_market choice 即使已是当前屏也照常重开(不享受 skip 豁免)"] = function()
  local market_open = nil
  local state = {
    ui = { choice_active = true, active_choice_screen_key = "market", market_active = true },
  }
  runtime_state.set_pending_choice_id(state, 42)
  local choice = { id = 42 }
  local market_snapshot = { stub = true }

  _with_patches({
    { target = choice_common, key = "resolve_screen_key", value = function() return "market" end },
    { target = runtime_state, key = "set_ui_dirty", value = function() end },
    { target = market_presenter, key = "open", value = function(s, c, choice_id, m)
      market_open = { state = s, choice = c, choice_id = choice_id, market = m }
    end },
  }, function()
    modal_presenter.open_choice_modal(state, choice, market_snapshot)
  end)

  lu.assertEvalToTrue(market_open ~= nil, "an already-active market choice must still reopen the market screen")
  _assert_eq(market_open.choice_id, 42, "market open must carry the choice id")
  _assert_eq(market_open.market, market_snapshot, "market open must carry the market snapshot")
end

TestChoiceModalPresenter["test_缺 choice / 缺 choice.id 时告警拒绝,不开任何屏也不弄脏 ui"] = function()
  local warns = {}
  local opener_calls = 0
  local dirty_calls = 0
  local market_open_calls = 0
  local state = { ui = { choice_active = false } }

  _with_patches({
    { target = logger, key = "warn", value = function(...)
      warns[#warns + 1] = table.concat({ ... }, " ")
    end },
    { target = choice_openers, key = "open_choice_modal", value = function() opener_calls = opener_calls + 1 end },
    { target = runtime_state, key = "set_ui_dirty", value = function() dirty_calls = dirty_calls + 1 end },
    { target = market_presenter, key = "open", value = function() market_open_calls = market_open_calls + 1 end },
  }, function()
    modal_presenter.open_choice_modal(state, nil)
    modal_presenter.open_choice_modal(state, {})
  end)

  _assert_eq(#warns, 2, "both rejects must warn exactly once each")
  lu.assertEvalToTrue(warns[1]:find("missing choice", 1, true), "nil choice must warn 'missing choice'")
  lu.assertEvalToTrue(warns[2]:find("missing choice id", 1, true), "id-less choice must warn 'missing choice id'")
  _assert_eq(opener_calls, 0, "a rejected open must not reach the generic choice opener")
  _assert_eq(market_open_calls, 0, "a rejected open must not reach the market screen")
  _assert_eq(dirty_calls, 0, "a rejected open must not dirty the ui")
end

TestChoiceModalPresenter["test_不需要二次确认的 base_inline choice 走关屏路径"] = function()
  local pre_confirm_calls = 0
  local close_calls = 0
  local reset_calls = 0
  local opener_calls = 0
  local canvas_targets = {}
  local state = { ui = { choice_active = false, market_active = false } }

  _with_patches({
    { target = choice_common, key = "resolve_screen_key", value = function() return "base_inline" end },
    { target = choice_common, key = "requires_item_slot_pre_confirm", value = function() return false end },
    { target = choice_common, key = "uses_item_slots", value = function() return false end },
    { target = choice_common, key = "switch_modal_canvas", value = function(_, target)
      canvas_targets[#canvas_targets + 1] = target
    end },
    { target = pending_confirmation, key = "is_item_phase_confirmed", value = function() return false end },
    { target = pending_confirmation, key = "reset_item_phase_confirmed", value = function() reset_calls = reset_calls + 1 end },
    { target = secondary_confirm_screen, key = "open_item_phase_pre_confirm", value = function() pre_confirm_calls = pre_confirm_calls + 1 end },
    { target = modal_state, key = "close_choice", value = function() close_calls = close_calls + 1 end },
    { target = runtime_state, key = "set_ui_dirty", value = function() end },
    { target = choice_openers, key = "open_choice_modal", value = function() opener_calls = opener_calls + 1 end },
  }, function()
    modal_presenter.open_choice_modal(state, { id = 7 })
  end)

  _assert_eq(pre_confirm_calls, 0,
    "a choice that does not require pre-confirm must never open the pre-confirm screen")
  _assert_eq(reset_calls, 1, "the inline close path must reset the item-phase confirmation")
  _assert_eq(close_calls, 1, "with no active choice screen the inline path closes the choice state")
  _assert_eq(canvas_targets[1], canvas.CANVAS_BASE, "the inline close path must return to the base canvas")
  _assert_eq(opener_calls, 0, "a special-screen choice must not fall through to the generic opener")
end

TestChoiceModalPresenter["test_已确认过道具阶段的 choice 不再弹二次确认"] = function()
  local pre_confirm_calls = 0
  local close_calls = 0
  local state = { ui = { choice_active = false, market_active = false } }

  _with_patches({
    { target = choice_common, key = "resolve_screen_key", value = function() return "base_inline" end },
    { target = choice_common, key = "requires_item_slot_pre_confirm", value = function() return true end },
    { target = choice_common, key = "uses_item_slots", value = function() return true end },
    { target = choice_common, key = "switch_modal_canvas", value = function() end },
    { target = pending_confirmation, key = "is_item_phase_confirmed", value = function() return true end },
    { target = pending_confirmation, key = "reset_item_phase_confirmed", value = function() end },
    { target = secondary_confirm_screen, key = "open_item_phase_pre_confirm", value = function() pre_confirm_calls = pre_confirm_calls + 1 end },
    { target = modal_state, key = "close_choice", value = function() close_calls = close_calls + 1 end },
    { target = runtime_state, key = "set_ui_dirty", value = function() end },
  }, function()
    modal_presenter.open_choice_modal(state, { id = 8 })
  end)

  _assert_eq(pre_confirm_calls, 0,
    "an already-confirmed item phase must go to the close path, not another pre-confirm")
  _assert_eq(close_calls, 1, "the confirmed choice must close the inline choice state")
end

TestChoiceModalPresenter["test_接管清掉道具阶段询问,不走通用开屏"] = function()
  local cleared_sources = {}
  local opener_calls = 0
  local canvas_targets = {}
  local state = { ui = { choice_active = false } }

  _with_patches({
    { target = choice_common, key = "resolve_screen_key", value = function() return "item_phase_passive" end },
    { target = choice_common, key = "switch_modal_canvas", value = function(_, target)
      canvas_targets[#canvas_targets + 1] = target
    end },
    { target = pending_confirmation, key = "clear", value = function(_, source)
      cleared_sources[#cleared_sources + 1] = source
    end },
    { target = runtime_state, key = "set_ui_dirty", value = function() end },
    { target = choice_openers, key = "open_choice_modal", value = function() opener_calls = opener_calls + 1 end },
  }, function()
    modal_presenter.open_choice_modal(state, { id = 9 })
  end)

  _assert_eq(cleared_sources[1], pending_confirmation.SOURCE_ITEM_PHASE_ASK,
    "the takeover must clear the item-phase ask confirmation")
  _assert_eq(canvas_targets[1], canvas.CANVAS_BASE, "the takeover must land on the base canvas")
  _assert_eq(opener_calls, 0, "the passive window must not fall through to the generic opener")
end

TestChoiceModalPresenter["test_popup 在场时关 choice 回 popup 画布,不走普通 modal 画布切换"] = function()
  local popup_switch = nil
  local modal_canvas_calls = 0
  local state = {
    ui = { choice_active = false, market_active = false, popup_active = true, popup_kind = nil },
  }

  _with_patches({
    { target = popup, key = "switch_popup_canvas", value = function(s, kind, target, fallback)
      popup_switch = { state = s, kind = kind, target = target, fallback = fallback }
    end },
    { target = choice_common, key = "switch_modal_canvas", value = function() modal_canvas_calls = modal_canvas_calls + 1 end },
    { target = modal_state, key = "close_choice", value = function() end },
    { target = runtime_state, key = "set_ui_dirty", value = function() end },
  }, function()
    modal_presenter.close_choice_modal(state)
  end)

  lu.assertEvalToTrue(popup_switch ~= nil, "closing with an active popup must switch back to the popup canvas")
  _assert_eq(popup_switch.kind, "card", "a nil popup_kind must default to the card popup")
  _assert_eq(popup_switch.target, canvas.CANVAS_POPUP, "the popup switch target must be the popup canvas")
  _assert_eq(popup_switch.fallback, canvas.CANVAS_BASE, "the popup switch fallback must be the base canvas")
  _assert_eq(modal_canvas_calls, 0, "an active popup must bypass the plain modal canvas switch")
end

TestChoiceModalPresenter["test_open 与 close 都以 true 弄脏 ui"] = function()
  -- kills open_choice_modal 与 close_choice_modal 里
  -- set_ui_dirty(state, true) 的两个 true->false。
  local dirty_flags = {}
  local state = { ui = { choice_active = false } }
  local close_state = {
    ui = { choice_active = false, market_active = false, popup_active = true, popup_kind = nil },
  }

  _with_patches({
    { target = choice_common, key = "resolve_screen_key", value = function() return "item_phase_passive" end },
    { target = choice_common, key = "switch_modal_canvas", value = function() end },
    { target = pending_confirmation, key = "clear", value = function() end },
    { target = choice_openers, key = "open_choice_modal", value = function() end },
    { target = popup, key = "switch_popup_canvas", value = function() end },
    { target = modal_state, key = "close_choice", value = function() end },
    { target = runtime_state, key = "set_ui_dirty", value = function(_, flag)
      dirty_flags[#dirty_flags + 1] = flag
    end },
  }, function()
    modal_presenter.open_choice_modal(state, { id = 9 })
    modal_presenter.close_choice_modal(close_state)
  end)

  _assert_eq(#dirty_flags, 2, "open and close must each dirty the ui once")
  _assert_eq(dirty_flags[1], true, "open must dirty the ui with true")
  _assert_eq(dirty_flags[2], true, "close must dirty the ui with true")
end


return TestChoiceModalPresenter
