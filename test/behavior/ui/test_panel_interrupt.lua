local lu = require("luaunit")
local luax = require("test.support.luax")
require("src.app.compose_game") -- 组合根装配:注入 ui.ports.cosmetics 的 transaction 实现(工单 #244)
local support = require("test.support.shared_support")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local item_atlas = require("src.ui.screens.item_atlas")
local skin_panel = require("src.ui.screens.skin_panel")
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

TestPanelInterrupt = {}

function TestPanelInterrupt:setUp()
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
end

function TestPanelInterrupt:tearDown()
  tips.configure_runtime({ clear_presenter = true, clear_scheduler = true, test_mode = false })
  tips.clear()
  -- 清了共享 tips 基线必须装回,否则 mutate 车道窄 suite 子集撞空 presenter(#217)
  support.restore_runtime_services()
end

function TestPanelInterrupt:test_classifies_each_settlement_flag_and_stays_inert_without_flags()
  local s = _make_state()
  lu.assertEvalToTrue(panel_interrupt.is_settling(s) == false, "no flags -> not settling")
  lu.assertEvalToTrue(panel_interrupt.settlement_type(s.ui) == nil, "no flags -> no settlement type")

  -- 可观察面:每个结算旗标都被识别为「结算中」,并各自归到一个可区分的
  -- 结算类别(消费方只看 is_settling / 是否有类别,不看精确标签串)。
  local flags = { "popup_active", "market_active", "choice_active", "move_active" }
  local seen = {}
  for _, flag in ipairs(flags) do
    local flagged = _make_state()
    flagged.ui[flag] = true
    lu.assertEvalToTrue(panel_interrupt.is_settling(flagged) == true, flag .. " -> settling")
    local kind = panel_interrupt.settlement_type(flagged.ui)
    lu.assertEvalToTrue(kind ~= nil, flag .. " -> should classify into a settlement type")
    lu.assertEvalToTrue(seen[kind] == nil,
      flag .. " -> should be a distinct settlement type, got duplicate " .. tostring(kind))
    seen[kind] = flag
  end
end

function TestPanelInterrupt:test_only_the_acting_player_s_market_blocks_tip_is_deduped_by_panel_settlement()
  -- 不在结算 / 非黑市结算 / 他人黑市:一律不拦、无提示
  local idle = _make_state()
  lu.assertEvalToTrue(panel_interrupt.block_entry(idle, "skin") == false)

  local moving = _make_state()
  moving.ui.move_active = true
  moving.ui.current_action_role_id = 1
  lu.assertEvalToTrue(panel_interrupt.block_entry(moving, "gallery", 1) == false,
    "non-market settlement should not block basic panels")

  local others_market = _make_state()
  others_market.ui.market_active = true
  others_market.ui.current_action_role_id = 2
  lu.assertEvalToTrue(panel_interrupt.block_entry(others_market, "gallery", 1) == false,
    "other player's market should not block basic panels")
  lu.assertEvalToTrue(#_drain_tips() == 0, "non-blocking paths must not enqueue tips")

  -- 本人黑市:拦 + 提示,同 panel/结算重复只提示一次
  local s = _make_state()
  s.ui.market_active = true
  s.ui.current_action_role_id = 1
  lu.assertEvalToTrue(panel_interrupt.block_entry(s, "skin", 1) == true)
  lu.assertEvalToTrue(panel_interrupt.block_entry(s, "skin", 1) == true)
  local pending = _drain_tips()
  lu.assertEvalToTrue(#pending == 1, "duplicate tips for same panel/settlement should be deduped, got " .. #pending)
  lu.assertEvalToTrue(pending[1].text == "结算中，稍后再开", "tip text mismatch: " .. tostring(pending[1].text))
  -- 去重的可观察效果按「面板」区分:同一面板重复触发不再入队,换个面板
  -- 另起一条(而非被当作重复吞掉)——断可观察去重行为,不钉内部 dedupe_key 串。
  lu.assertEvalToTrue(tips.snapshot().pending_count == 0,
    "repeated same-panel block must not enqueue a second tip")
  lu.assertEvalToTrue(panel_interrupt.block_entry(s, "gallery", 1) == true)
  lu.assertEvalToTrue(tips.snapshot().pending_count == 1,
    "a different panel must not be deduped against the skin tip")
end

function TestPanelInterrupt:test_blocks_conservatively_when_market_actor_identity_is_incomplete()
  local s = _make_state()
  s.ui.market_active = true
  s.ui.current_action_role_id = 1

  lu.assertEvalToTrue(panel_interrupt.block_entry(s, "gallery", nil) == true,
    "missing actor role should block during market settlement")

  local s_without_current = _make_state()
  s_without_current.ui.market_active = true
  lu.assertEvalToTrue(panel_interrupt.block_entry(s_without_current, "gallery", 1) == true,
    "missing current action role should block during market settlement")
end

function TestPanelInterrupt:test_acting_player_s_market_closes_atlas_skin_panel_and_only_the_acting_role_s_event_log()
  local s = _make_state()
  item_atlas.open(s, 1)
  skin_panel.open(s, 1)
  event_log_view.open(s, 1)
  event_log_view.open(s, 2)
  lu.assertEvalToTrue(s.ui.item_atlas.open == true and s.ui.skin_panel.open == true)
  s.ui.market_active = true
  s.ui.current_action_role_id = 1

  panel_interrupt.interrupt(s)

  lu.assertEvalToTrue(s.ui.item_atlas.open == false, "atlas should be closed by interrupt")
  lu.assertEvalToTrue(s.ui.skin_panel.open == false, "skin panel should be closed by interrupt")
  lu.assertEvalToTrue(event_log_view.is_open(s, 1) == false, "role 1 event log should be closed")
  lu.assertEvalToTrue(event_log_view.is_open(s, 2) == true, "role 2 event log should remain open")
end

function TestPanelInterrupt:test_keeps_panels_open_for_non_market_settlements_and_other_players_market()
  local choice_state = _make_state()
  item_atlas.open(choice_state, 1)
  choice_state.ui.choice_active = true
  choice_state.ui.current_action_role_id = 1
  panel_interrupt.interrupt(choice_state)
  lu.assertEvalToTrue(choice_state.ui.item_atlas.open == true, "non-market settlement should not close atlas")

  item_atlas.reset_for_tests()
  local others_market = _make_state()
  item_atlas.open(others_market, 1)
  others_market.ui.market_active = true
  others_market.ui.current_action_role_id = 2
  panel_interrupt.interrupt(others_market)
  lu.assertEvalToTrue(others_market.ui.item_atlas.open == true, "other player's market should not close atlas")
end

function TestPanelInterrupt:test_is_a_no_op_when_no_panel_is_open()
  local s = _make_state()
  luax.has_no_error(function() panel_interrupt.interrupt(s) end)
end

function TestPanelInterrupt:test_is_a_no_op_when_no_skin_panel_exists()
  local s = _make_state()

  panel_interrupt.begin_player_action(s, 1)

  lu.assertEvalToTrue(s.ui.current_action_role_id == 1, "acting role should still be recorded")
  lu.assertEvalToTrue(#_drain_tips() == 0, "no tip should be shown without a skin panel")
end

function TestPanelInterrupt:test_closes_an_off_turn_skin_panel_for_the_acting_role_and_shows_the_action_tip()
  local s = _make_state()
  s.ui.current_action_role_id = 2
  skin_panel.open(s, 1)
  lu.assertEvalToTrue(s.ui.skin_panel.open == true)
  tips.clear()
  _drain_tips()

  panel_interrupt.begin_player_action(s, 1)

  lu.assertEvalToTrue(s.ui.current_action_role_id == 1, "acting role should be recorded")
  lu.assertEvalToTrue(s.ui.skin_panel.open == false, "off-turn skin panel should close when owner acts")
  local pending = _drain_tips()
  lu.assertEvalToTrue(#pending == 1, "expected one action-turn tip, got " .. #pending)
  lu.assertEvalToTrue(pending[1].text == "轮到你行动了", "tip text mismatch: " .. tostring(pending[1].text))
end

function TestPanelInterrupt:test_does_not_clear_an_unrelated_active_tip_when_closing_the_off_turn_skin_panel()
  local s = _make_state()
  s.ui.current_action_role_id = 2
  skin_panel.open(s, 1)
  tips.clear()
  _drain_tips()
  tips.enqueue({ text = "其他提示", duration = 2.0, dedupe_key = "other-tip" })
  _drain_tips()

  panel_interrupt.begin_player_action(s, 1)

  -- 可观察面:off-turn 皮肤面板被关掉,但已在展示的无关提示没被顶掉——
  -- 宿主 presenter 未被再次触发,动作提示排在活跃提示之后而不抢占。
  lu.assertEvalToTrue(s.ui.skin_panel.open == false, "off-turn skin panel should close when its owner acts")
  lu.assertEvalToTrue(#_drain_tips() == 0,
    "action-turn tip must wait behind the active unrelated tip, not preempt it")
end

function TestPanelInterrupt:test_keeps_an_off_turn_skin_panel_open_when_another_role_starts_acting()
  local s = _make_state()
  s.ui.current_action_role_id = 2
  skin_panel.open(s, 1)
  _drain_tips()

  panel_interrupt.begin_player_action(s, 2)

  lu.assertEvalToTrue(s.ui.skin_panel.open == true, "other role action should not close this skin panel")
  lu.assertEvalToTrue(#_drain_tips() == 0, "no tip should be shown for another role")
end

TestPanelInterrupt["test_nil_ui_视为无弹层"] = function(self)
  lu.assertEvalToTrue(panel_interrupt.is_overlay_visible(nil) == false, "nil ui must not read as an overlay")
end

TestPanelInterrupt["test_nil_ui_的 settlement_type_excluding_choice 返回 nil"] = function(self)
  lu.assertEvalToTrue(panel_interrupt.settlement_type_excluding_choice(nil) == nil,
    "nil ui must resolve to no settlement type")
end

TestPanelInterrupt["test_弹窗/黑市/机会三个真弹层各自触发"] = function(self)
  lu.assertEvalToTrue(panel_interrupt.is_overlay_visible({ popup_active = true }) == true, "popup is an overlay")
  lu.assertEvalToTrue(panel_interrupt.is_overlay_visible({ market_active = true }) == true, "market is an overlay")
  lu.assertEvalToTrue(panel_interrupt.is_overlay_visible({ choice_active = true }) == true, "chance choice is an overlay")
end

TestPanelInterrupt["test_阶段位不算弹层"] = function(self)
  lu.assertEvalToTrue(panel_interrupt.is_overlay_visible({ move_active = true }) == false, "move phase bit is not an overlay")
  lu.assertEvalToTrue(panel_interrupt.is_overlay_visible({ input_blocked = true }) == false, "input_blocked is not an overlay")
end

TestPanelInterrupt["test_面板视为归属任何角色,照常关闭"] = function(self)
  local closed = {}
  panel_interrupt.register_panel_closer("skin_panel", function(_, role_id)
    closed[#closed + 1] = role_id
  end)
  local state = {
    ui = {
      market_active = true,
      current_action_role_id = nil,
      skin_panel = { open = true, role_id = 3 },
    },
  }
  panel_interrupt.interrupt(state)
  panel_interrupt.unregister_panel_closer("skin_panel")
  lu.assertEvalToTrue(#closed == 1 and closed[1] == 3,
    "with no active action role the open panel must still be closed, got " .. tostring(#closed))
end

function TestPanelInterrupt:test_re_registering_a_fixed_panel_key_replaces_the_old_closer()
  local calls = {}
  panel_interrupt.register_panel_closer("skin_panel", function()
    calls[#calls + 1] = "old"
  end)
  panel_interrupt.register_panel_closer("skin_panel", function()
    calls[#calls + 1] = "new"
  end)

  panel_interrupt.interrupt({
    ui = {
      market_active = true,
      current_action_role_id = 1,
      skin_panel = { open = true, role_id = 1 },
    },
  })

  panel_interrupt.register_panel_closer("skin_panel", function(state, role_id, opts)
    skin_panel.close(state, role_id, opts)
  end)
  lu.assertEvalToTrue(#calls == 1 and calls[1] == "new",
    "fixed-key registration must replace the stale closer")
end

function TestPanelInterrupt:test_block_entry_tip_payload_pins_blocking_and_source()
  -- 杀 L91 blocks_inter_turn false->true 与 L92 source "ui.panel_interrupt"->nil。
  local s = _make_state()
  s.ui.market_active = true
  s.ui.current_action_role_id = 1
  panel_interrupt.block_entry(s, "skin", 1)
  local pending = _drain_tips()
  lu.assertEvalToTrue(#pending == 1, "expected one block tip")
  lu.assertEvalToTrue(pending[1].blocks_inter_turn == false, "block tip must not block inter-turn")
  lu.assertEvalToTrue(pending[1].source == "ui.panel_interrupt", "block tip source should be pinned")
end

function TestPanelInterrupt:test_action_turn_tip_payload_pins_blocking_and_source()
  -- 杀 L146 blocks_inter_turn false->true 与 L147 source "ui.panel_interrupt"->nil。
  local s = _make_state()
  s.ui.current_action_role_id = 2
  skin_panel.open(s, 1)
  tips.clear()
  _drain_tips()

  panel_interrupt.begin_player_action(s, 1)

  local pending = _drain_tips()
  lu.assertEvalToTrue(#pending == 1, "expected one action-turn tip")
  lu.assertEvalToTrue(pending[1].blocks_inter_turn == false, "action turn tip must not block inter-turn")
  lu.assertEvalToTrue(pending[1].source == "ui.panel_interrupt", "action turn tip source should be pinned")
end


return TestPanelInterrupt
