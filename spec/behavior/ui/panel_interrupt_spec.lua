local panel_interrupt = require("src.ui.coord.panel_interrupt")
local item_atlas = require("src.ui.coord.item_atlas")
local skin_panel = require("src.ui.coord.skin_panel")
local event_log_view = require("src.ui.coord.event_log_view")
local tips = require("src.foundation.tips")

local function _make_state()
  return { ui = {} }
end

local _captured_tips = {}

local function _drain_tips()
  local copy = _captured_tips
  _captured_tips = {}
  return copy
end

describe("ui.coord.panel_interrupt", function()
  before_each(function()
    item_atlas.reset_for_tests()
    skin_panel.reset_for_tests()
    tips.clear()
    _captured_tips = {}
    tips.configure_runtime({
      presenter = function(text, duration, tip)
        _captured_tips[#_captured_tips + 1] = tip or { text = text, duration = duration }
      end,
      scheduler = function() return true end,
      test_mode = false,
    })
  end)

  after_each(function()
    tips.configure_runtime({ clear_presenter = true, clear_scheduler = true, test_mode = false })
    tips.clear()
  end)

  describe("is_settling / settlement_type", function()
    it("returns false when no settlement flag is set", function()
      local s = _make_state()
      assert(panel_interrupt.is_settling(s) == false, "no flags -> not settling")
      assert(panel_interrupt.settlement_type(s.ui) == nil, "no flags -> nil type")
    end)

    it("classifies popup_active as 弹窗", function()
      local s = _make_state()
      s.ui.popup_active = true
      assert(panel_interrupt.is_settling(s) == true)
      assert(panel_interrupt.settlement_type(s.ui) == "弹窗")
    end)

    it("classifies market_active as 黑市", function()
      local s = _make_state()
      s.ui.market_active = true
      assert(panel_interrupt.settlement_type(s.ui) == "黑市")
    end)

    it("classifies choice_active as 机会", function()
      local s = _make_state()
      s.ui.choice_active = true
      assert(panel_interrupt.settlement_type(s.ui) == "机会")
    end)

    it("classifies move_active as 移动", function()
      local s = _make_state()
      s.ui.move_active = true
      assert(panel_interrupt.settlement_type(s.ui) == "移动")
    end)
  end)

  describe("block_entry", function()
    it("returns false and enqueues nothing when not settling", function()
      local s = _make_state()
      assert(panel_interrupt.block_entry(s, "skin") == false)
      assert(#_drain_tips() == 0, "no tip when not settling")
    end)

    it("returns true and enqueues a tip for the acting player's market screen", function()
      local s = _make_state()
      s.ui.market_active = true
      s.ui.current_action_role_id = 1
      assert(panel_interrupt.block_entry(s, "skin", 1) == true)
      local pending = _drain_tips()
      assert(#pending == 1, "expected one tip enqueued, got " .. #pending)
      assert(pending[1].text == "结算中，稍后再开", "tip text mismatch: " .. tostring(pending[1].text))
      assert(pending[1].dedupe_key == "panel_interrupt:skin:黑市",
        "dedupe_key mismatch: " .. tostring(pending[1].dedupe_key))
    end)

    it("returns false for non-market settlements", function()
      local s = _make_state()
      s.ui.move_active = true
      s.ui.current_action_role_id = 1

      assert(panel_interrupt.block_entry(s, "gallery", 1) == false)
      assert(#_drain_tips() == 0, "non-market settlement should not block basic panels")
    end)

    it("returns false for another player's market screen", function()
      local s = _make_state()
      s.ui.market_active = true
      s.ui.current_action_role_id = 2

      assert(panel_interrupt.block_entry(s, "gallery", 1) == false)
      assert(#_drain_tips() == 0, "other player's market should not block basic panels")
    end)

    it("blocks conservatively when market actor identity is incomplete", function()
      local s = _make_state()
      s.ui.market_active = true
      s.ui.current_action_role_id = 1

      assert(panel_interrupt.block_entry(s, "gallery", nil) == true,
        "missing actor role should block during market settlement")

      local s_without_current = _make_state()
      s_without_current.ui.market_active = true
      assert(panel_interrupt.block_entry(s_without_current, "gallery", 1) == true,
        "missing current action role should block during market settlement")
    end)

    it("dedupes by panel_id and settlement_type", function()
      local s = _make_state()
      s.ui.market_active = true
      s.ui.current_action_role_id = 1
      panel_interrupt.block_entry(s, "gallery", 1)
      panel_interrupt.block_entry(s, "gallery", 1)
      assert(#_drain_tips() == 1, "duplicate tips for same panel/settlement should be deduped")
    end)
  end)

  describe("interrupt", function()
    it("closes an open item_atlas for the acting player's market screen", function()
      local s = _make_state()
      item_atlas.open(s, 1)
      assert(s.ui.item_atlas.open == true)
      s.ui.market_active = true
      s.ui.current_action_role_id = 1
      panel_interrupt.interrupt(s)
      assert(s.ui.item_atlas.open == false, "atlas should be closed by interrupt")
    end)

    it("keeps an open item_atlas during a non-market settlement", function()
      local s = _make_state()
      item_atlas.open(s, 1)
      s.ui.choice_active = true
      s.ui.current_action_role_id = 1

      panel_interrupt.interrupt(s)

      assert(s.ui.item_atlas.open == true, "non-market settlement should not close atlas")
    end)

    it("keeps an open item_atlas for another player's market screen", function()
      local s = _make_state()
      item_atlas.open(s, 1)
      s.ui.market_active = true
      s.ui.current_action_role_id = 2

      panel_interrupt.interrupt(s)

      assert(s.ui.item_atlas.open == true, "other player's market should not close atlas")
    end)

    it("closes an open skin_panel for the acting player's market screen", function()
      local s = _make_state()
      skin_panel.open(s, 1)
      assert(s.ui.skin_panel.open == true)
      s.ui.market_active = true
      s.ui.current_action_role_id = 1
      panel_interrupt.interrupt(s)
      assert(s.ui.skin_panel.open == false, "skin panel should be closed by interrupt")
    end)

    it("closes only the acting role event_log for the market screen", function()
      local s = _make_state()
      event_log_view.open(s, 1)
      event_log_view.open(s, 2)
      assert(event_log_view.is_open(s, 1) == true)
      assert(event_log_view.is_open(s, 2) == true)
      s.ui.market_active = true
      s.ui.current_action_role_id = 1
      panel_interrupt.interrupt(s)
      assert(event_log_view.is_open(s, 1) == false, "role 1 event log should be closed")
      assert(event_log_view.is_open(s, 2) == true, "role 2 event log should remain open")
    end)

    it("is a no-op when no panel is open", function()
      local s = _make_state()
      assert(function() panel_interrupt.interrupt(s) end, "should not raise")
    end)
  end)

  describe("begin_player_action", function()
    it("is a no-op when no skin panel exists", function()
      local s = _make_state()

      panel_interrupt.begin_player_action(s, 1)

      assert(s.ui.current_action_role_id == 1, "acting role should still be recorded")
      assert(#_drain_tips() == 0, "no tip should be shown without a skin panel")
    end)

    it("closes an off-turn skin panel for the acting role and shows the action tip", function()
      local s = _make_state()
      s.ui.current_action_role_id = 2
      skin_panel.open(s, 1)
      assert(s.ui.skin_panel.open == true)
      tips.clear()
      _drain_tips()

      panel_interrupt.begin_player_action(s, 1)

      assert(s.ui.current_action_role_id == 1, "acting role should be recorded")
      assert(s.ui.skin_panel.open == false, "off-turn skin panel should close when owner acts")
      local pending = _drain_tips()
      assert(#pending == 1, "expected one action-turn tip, got " .. #pending)
      assert(pending[1].text == "轮到你行动了", "tip text mismatch: " .. tostring(pending[1].text))
    end)

    it("does not clear an unrelated active tip when closing the off-turn skin panel", function()
      local s = _make_state()
      s.ui.current_action_role_id = 2
      skin_panel.open(s, 1)
      tips.clear()
      _drain_tips()
      tips.enqueue({ text = "其他提示", duration = 2.0, dedupe_key = "other-tip" })
      _drain_tips()

      panel_interrupt.begin_player_action(s, 1)

      local snapshot = tips.snapshot()
      assert(snapshot.active_text == "其他提示", "unrelated active tip should remain active")
      assert(snapshot.pending_count == 1, "action-turn tip should wait behind the active unrelated tip")
    end)

    it("keeps an off-turn skin panel open when another role starts acting", function()
      local s = _make_state()
      s.ui.current_action_role_id = 2
      skin_panel.open(s, 1)
      _drain_tips()

      panel_interrupt.begin_player_action(s, 2)

      assert(s.ui.skin_panel.open == true, "other role action should not close this skin panel")
      assert(#_drain_tips() == 0, "no tip should be shown for another role")
    end)

  end)
end)
