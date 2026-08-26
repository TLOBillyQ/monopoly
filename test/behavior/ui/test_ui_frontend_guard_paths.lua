-- UI 前端各模块的兜底/守卫分支：这些路径在常规流程里不会走到
-- （宿主对象缺失、payload 缺字段、上游已先行判空），只能直接从模块入口打。
--
-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):describe/it 拍平为文件级 Test*
-- 类,describe 级 local 辅助函数提升到文件顶层,断言从 luassert 兼容层切到
-- lu.assertXxx,用例数与改写前一一对应(18 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq

local gameplay_read_port = require("src.ui.view.gameplay_read_port")
local state_callback_ports = require("src.ui.ports.callbacks")
local runtime_event_ports = require("src.ui.ports.events")
local route_item_slots = require("src.ui.input.route_item_slots")
local permanent_nodes = require("src.ui.schema.permanent")
local pre_confirm_flow = require("src.ui.input.pre_confirm")
local anim_ports = require("src.ui.ports.anim")
local tip_queue = require("src.foundation.tips")
local move_anim = require("src.ui.render.move_anim")
local ui_runtime = require("src.ui.coord.ui_runtime")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local runtime_state = require("src.ui.state.runtime")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local role_id_utils = require("src.foundation.identity")

-- state_callback_ports.show_tip 的局部装配（原 describe 级 local）。
local function _install(get_current_game)
  local state = {}
  state_callback_ports.install(state, get_current_game or function() return nil end)
  return state
end

-- anim_ports sequence lock exemption 的 stub 装配（原 describe 级 local）。
local function _with_stubs(fn)
  support.with_patches({
    { target = move_anim, key = "play_sequence", value = function() return 0 end },
    { target = ui_runtime, key = "apply_role_control_lock", value = function(_, enabled)
        fn.applied[#fn.applied + 1] = enabled
      end },
  }, fn.run)
end

-- event_log_view panel closer 捕获（原 describe 级 local）。closer 注册在
-- panel_interrupt 私有表里；重新 require 模块并拦下注册即可拿到它。
-- 用 stub 吞掉注册，真实注册表保持第一次加载时的闭包不变。
local function _capture_closer()
  local original_module = package.loaded["src.ui.coord.event_log_view"]
  local original_register = panel_interrupt.register_panel_closer
  local captured = nil
  panel_interrupt.register_panel_closer = function(name, close_fn)
    if name == "event_log_view" then
      captured = close_fn
    end
  end
  package.loaded["src.ui.coord.event_log_view"] = nil
  require("src.ui.coord.event_log_view")
  panel_interrupt.register_panel_closer = original_register
  package.loaded["src.ui.coord.event_log_view"] = original_module
  assert(captured ~= nil, "the event_log_view closer registers itself on load")
  return captured
end

TestUiFrontendGuardPaths = {}

function TestUiFrontendGuardPaths:test_returns_just_the_purchase_price_when_the_tile_carries_no_upgrade_costs()
  local total = gameplay_read_port.total_land_invested({ price = 100 }, 3)
  _assert_eq(total, 100, "no upgrade_costs table means nothing to add")
end

function TestUiFrontendGuardPaths:test_clamps_the_level_to_the_number_of_upgrade_costs_available()
  -- level 5 但只有 2 档升级费：多出来的档位不能凭空计价。
  local tile = { price = 100, upgrade_costs = { 10, 20 } }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 5), 130, "clamped to 2 levels")
end

function TestUiFrontendGuardPaths:test_sums_the_purchase_price_plus_the_costs_up_to_the_given_level()
  local tile = { price = 100, upgrade_costs = { 10, 20 } }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 1), 110, "one upgrade level")
end

function TestUiFrontendGuardPaths:test_treats_a_non_table_tile_as_zero_invested()
  _assert_eq(gameplay_read_port.total_land_invested(nil, 2), 0, "nil tile")
end

function TestUiFrontendGuardPaths:test_rejects_a_non_table_intent_without_reaching_the_host_bridge()
  local calls = 0
  support.with_patches({
    { target = tip_queue, key = "enqueue", value = function()
        calls = calls + 1
        return true
      end },
  }, function()
    local state = _install()
    _assert_eq(state:show_tip("not-a-table"), false, "string intent is rejected")
    _assert_eq(state:show_tip(nil), false, "nil intent is rejected")
    _assert_eq(calls, 0, "host bridge must not be called for a non-table intent")
  end)
end

function TestUiFrontendGuardPaths:test_forwards_a_table_intent_to_the_host_bridge_and_returns_its_result()
  local seen
  support.with_patches({
    { target = tip_queue, key = "enqueue", value = function(intent)
        seen = intent
        return true
      end },
  }, function()
    local state = _install()
    local intent = { text = "hi", duration = 1.5 }
    _assert_eq(state:show_tip(intent), true, "enqueued tip returns true")
    lu.assertEvalToTrue(seen == intent, "the intent is forwarded verbatim")
  end)
end

function TestUiFrontendGuardPaths:test_coerces_a_truthy_but_not_true_host_result_to_false()
  support.with_patches({
    { target = tip_queue, key = "enqueue", value = function() return "queued" end },
  }, function()
    local state = _install()
    _assert_eq(state:show_tip({ text = "hi" }), false, "pins the `== true` coercion")
  end)
end

function TestUiFrontendGuardPaths:test_ignores_a_payload_that_carries_no_choice()
  local game_lookups = 0
  local state = {}
  runtime_event_ports.on_need_choice(state, function()
    game_lookups = game_lookups + 1
    return {}
  end, { elapsed_seconds = 3 })
  _assert_eq(game_lookups, 0, "must return before resolving the current game")
  lu.assertEvalToTrue(runtime_state.get_pending_choice(state) == nil, "no pending choice is recorded")
end

function TestUiFrontendGuardPaths:test_ignores_a_nil_payload()
  local game_lookups = 0
  runtime_event_ports.on_need_choice({}, function()
    game_lookups = game_lookups + 1
    return {}
  end, nil)
  _assert_eq(game_lookups, 0, "nil payload short-circuits too")
end

-- 地块升级事件:payload 带 tile_id 且 state 有同步回调时转发单块地同步。
function TestUiFrontendGuardPaths:test_on_tile_upgraded_syncs_single_tile()
  local synced = nil
  local state = {
    on_board_visual_sync = function(_, payload)
      synced = payload
    end,
  }
  runtime_event_ports.on_tile_upgraded(state, { tile_id = 9 })
  lu.assertNotNil(synced, "on_tile_upgraded should sync the upgraded tile")
  lu.assertEquals(synced.tile_ids[1], 9, "sync payload should carry the upgraded tile id")

  runtime_event_ports.on_tile_upgraded(state, {})
  runtime_event_ports.on_tile_upgraded({}, { tile_id = 9 })
end

function TestUiFrontendGuardPaths:test_falls_back_to_the_permanent_schema_node_names_when_state_ui_carries_no_slot_list()
  -- 兜底分支：宿主还没把槽位节点名写进 state.ui（首帧/热重载）时，route 直接吃
  -- 常驻屏 schema 的节点表。槽位号跟节点序一一对应，不依赖任何局面数据。
  local state = { ui = {} }
  -- 顺带钉死：ui_model 里挂着一份过期的非道具 choice，也不影响 route 的产出——
  -- route 不读 choice，「在不在道具阶段」全归 turn 层裁定。
  runtime_state.set_ui_model(state, { choice = { id = "stale", uses_item_slots = false } })

  local specs = route_item_slots.build(state)
  local node_name = permanent_nodes.item_slots[3]
  local slot_spec = nil
  for _, spec in ipairs(specs) do
    if spec.name == node_name then
      slot_spec = spec
    end
  end
  lu.assertEvalToTrue(slot_spec ~= nil, "an intent spec is built for the schema slot node " .. tostring(node_name))

  local intent = slot_spec.build_intent({ role = { get_roleid = function() return 7 end } })
  lu.assertEvalToTrue(intent ~= nil, "an unoccluded click always dispatches")
  _assert_eq(intent.type, "item_slot_click", "intent type")
  _assert_eq(intent.slot_index, 3, "slot index follows the schema node order")
  _assert_eq(intent.actor_role_id, 7, "the clicker rides along for the turn-side verdict")
end

function TestUiFrontendGuardPaths:test_refuses_to_open_when_the_intent_resolves_no_option_id()
  local state = {}
  runtime_state.set_ui_model(state, {
    choice = { id = "c1" },
    current_player_id = "p1",
  })

  -- choice_select 但没带 option_id：_resolve_enter_params 解不出参数。
  local opened = pre_confirm_flow.enter(state, { type = "choice_select", actor_role_id = "p1" })
  _assert_eq(opened, false, "enter must report failure")
  lu.assertEvalToTrue(not pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_CHOICE_SELECT),
    "no pre-confirm session is opened")
end

-- #443:owner 门控只认事件载荷里的 actor_role_id;「上一次点击者缓存」随 #601
-- 整体退役后,身份更无第二来源。
function TestUiFrontendGuardPaths:test_refuses_to_open_when_the_intent_actor_is_not_the_choice_owner()
  local state = {}
  runtime_state.set_ui_model(state, {
    choice = { id = "c1", owner_role_id = "p1" },
  })

  local opened = pre_confirm_flow.enter(state, { type = "choice_select", option_id = "opt", actor_role_id = "p2" })
  _assert_eq(opened, false, "a non-owner click must be refused")
  lu.assertEvalToTrue(not pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_CHOICE_SELECT),
    "no pre-confirm session is opened")
end

function TestUiFrontendGuardPaths:test_refuses_to_open_when_the_intent_carries_no_actor_role_id()
  local state = {}
  runtime_state.set_ui_model(state, {
    choice = { id = "c1", owner_role_id = "p1" },
  })

  local opened = pre_confirm_flow.enter(state, { type = "choice_select", option_id = "opt" })
  _assert_eq(opened, false, "a missing actor_role_id must refuse to open without crashing")
  lu.assertEvalToTrue(not pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_CHOICE_SELECT),
    "no pre-confirm session is opened")
end

function TestUiFrontendGuardPaths:test_re_applies_the_lock_without_touching_the_exempt_tables_when_the_meta_carries_no_player_id()
  local applied = {}
  local state = {}
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  turn_runtime.role_control_lock_active = true

  local anim_ctx = {}
  _with_stubs({
    applied = applied,
    run = function()
      local ports = anim_ports.build()
      ports.play_move_anim(state, anim_ctx)
      anim_ctx.on_sequence_lock(false, 1.0, nil)
    end,
  })

  lu.assertEvalToTrue(state.role_control_lock_exempt_count_by_role == nil,
    "an anonymous sequence must not create per-role exempt bookkeeping")
  lu.assertEvalToTrue(state.role_control_lock_exempt_by_role == nil,
    "an anonymous sequence must not create per-role exempt bookkeeping")
  _assert_eq(applied[#applied], true, "the active lock flag is re-applied")
  _assert_eq(anim_ctx.role_control_exempt, true, "unlocking marks the context exempt")
end

function TestUiFrontendGuardPaths:test_books_the_exemption_against_the_player_when_the_sequence_carries_a_player_id()
  local applied = {}
  local state = {}
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  turn_runtime.role_control_lock_active = true

  local anim_ctx = { player_id = "p1" }
  _with_stubs({
    applied = applied,
    run = function()
      local ports = anim_ports.build()
      ports.play_move_anim(state, anim_ctx)
      anim_ctx.on_sequence_lock(false, 1.0, nil)
    end,
  })

  lu.assertEvalToTrue(type(state.role_control_lock_exempt_by_role) == "table", "exempt table is created")
  _assert_eq(role_id_utils.read(state.role_control_lock_exempt_by_role, "p1"), true,
    "the player is booked as exempt")
end

function TestUiFrontendGuardPaths:test_does_nothing_when_the_state_has_no_ui()
  local closer = _capture_closer()
  local ok = pcall(closer, {}, nil)
  lu.assertEvalToTrue(ok, "a state without ui must not crash the closer")
end

function TestUiFrontendGuardPaths:test_does_nothing_when_debug_visible_by_role_is_not_a_table()
  local closer = _capture_closer()
  local calls = 0
  local state = {
    ui = {
      debug_visible_by_role = "not-a-table",
      set_event_log_visible = function()
        calls = calls + 1
      end,
    },
  }
  closer(state, nil)
  _assert_eq(calls, 0, "no visibility writes when the role map is malformed")
end

function TestUiFrontendGuardPaths:test_closes_the_visible_event_log_of_every_role_when_no_active_role_is_given()
  local closer = _capture_closer()
  local visible_writes = {}
  local state = {
    ui = {
      debug_visible_by_role = {},
      set_event_log_visible = function(_, visible)
        visible_writes[#visible_writes + 1] = visible
      end,
    },
  }
  role_id_utils.write(state.ui.debug_visible_by_role, "p1", true)

  closer(state, nil)

  _assert_eq(role_id_utils.read(state.ui.debug_visible_by_role, "p1"), false,
    "the role's event log is marked hidden")
  _assert_eq(visible_writes[#visible_writes], false, "the ui hook is driven to hidden")
end

function TestUiFrontendGuardPaths:test_restores_a_non_inline_source_screen_and_clears_the_pending_choice()
  local state = {
    gameplay_loop_ports = {
      modal = {},
    },
  }
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, { source_screen = "market" })
  local open_calls = 0
  local close_calls = 0
  state.gameplay_loop_ports.modal.open_choice_modal = function(_, choice)
    open_calls = open_calls + 1
    _assert_eq(choice.id, "choice1", "cancel should restore current choice")
  end
  state.gameplay_loop_ports.modal.close_choice_modal = function()
    close_calls = close_calls + 1
  end
  runtime_state.set_ui_model(state, {
    choice = { id = "choice1" },
  })
  runtime_state.set_pending_choice_id(state, "choice1")

  pre_confirm_flow.cancel(state)

  _assert_eq(pending_confirmation.is_active(state), false, "cancel should clear active record")
  _assert_eq(pending_confirmation.source_screen(state), nil, "cancel should clear source")
  _assert_eq(runtime_state.get_pending_choice_id(state), nil, "cancel should clear pending choice id")
  _assert_eq(open_calls, 1, "non-inline cancel should reopen prior modal")
  _assert_eq(close_calls, 0, "non-inline cancel should not close modal")
end

function TestUiFrontendGuardPaths:test_needs_pre_confirm_returns_false_without_ui()
  _assert_eq(pre_confirm_flow.needs_pre_confirm({}, { type = "choice_select" }), false,
    "a state without ui should never require pre-confirm")
end

function TestUiFrontendGuardPaths:test_cancel_with_inline_source_closes_the_choice_modal()
  local state = {
    gameplay_loop_ports = {
      modal = {},
    },
  }
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    option_id = "opt_1",
    source_screen = "base_inline",
  })
  local close_calls = 0
  local open_calls = 0
  state.gameplay_loop_ports.modal.close_choice_modal = function()
    close_calls = close_calls + 1
  end
  state.gameplay_loop_ports.modal.open_choice_modal = function()
    open_calls = open_calls + 1
  end
  runtime_state.set_ui_model(state, {
    choice = { id = "choice1" },
  })
  runtime_state.set_pending_choice_id(state, "choice1")

  pre_confirm_flow.cancel(state)

  _assert_eq(close_calls, 1, "inline cancel should close the choice modal")
  _assert_eq(open_calls, 0, "inline cancel should not reopen a modal")
end

function TestUiFrontendGuardPaths:test_records_the_popup_owner_index_on_a_successful_push()
  local modal = require("src.ui.coord.popup_presenter")
  local state = { ui = {} }
  local game_with_turn = {
    turn = { current_player_index = 3 },
  }

  support.with_patches({
    { target = modal, key = "push_popup", value = function(_, s, payload, opts)
      return true
    end },
  }, function()
    state_callback_ports.install(state, function() return game_with_turn end)
    local ok = state.push_popup(nil, "hello", {})
    _assert_eq(ok, true, "push_popup should return modal success")
    _assert_eq(state.ui.popup_owner_index, 3, "successful popup should record current player index")
  end)

  local state2 = { ui = {} }
  support.with_patches({
    { target = modal, key = "push_popup", value = function() return false end },
  }, function()
    state_callback_ports.install(state2, function() return game_with_turn end)
    local ok = state2.push_popup(nil, "hello", {})
    _assert_eq(ok, false, "push_popup should return modal failure")
    _assert_eq(state2.ui.popup_owner_index, nil, "failed popup should clear owner index")
  end)

  local state3 = {}
  support.with_patches({
    { target = modal, key = "push_popup", value = function() return true end },
  }, function()
    state_callback_ports.install(state3, function() return nil end)
    local ok = state3.push_popup(nil, "hello", {})
    _assert_eq(ok, true, "push_popup should succeed even without ui table")
  end)
end



	-- #524 时序裁定：事件路径只记账不开屏——任何路由键（含此前直开的
	-- base_inline / item_phase_passive）都不得触达 modal.open_choice_modal、
	-- choice_slice 构建或 gate 判定；开屏收敛到 dirty 刷新。
	function TestUiFrontendGuardPaths:test_on_need_choice_records_only_without_opening_modal()
	  local state = {}
	  local modal_opened = nil
	  local slice_consulted = false
	  local gate_consulted = false
	  local route_consulted = false
	  local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state
	  support.with_patches({
	    { target = runtime_state, key = "set_pending_choice", value = function() end },
	    { target = runtime_state, key = "set_ui_dirty", value = function() end },
	    { target = require("src.ui.view.choice_slice"), key = "build_choice_and_market",
	      value = function() slice_consulted = true return { id = "built_c1" }, {} end },
	    { target = choice_ui_state, key = "resolve_route_key",
	      value = function() route_consulted = true return "base_inline" end },
	    { target = choice_ui_state, key = "resolve_gate_state",
	      value = function() gate_consulted = true return { expects_ui = true } end },
	    { target = require("src.ui.coord.modal"), key = "open_choice_modal",
	      value = function(_, choice) modal_opened = choice end },
	  }, function()
	    runtime_event_ports.on_need_choice(state, function() return {} end, {
	      choice = { id = "c1" },
	    })
	  end)
	  lu.assertNil(modal_opened, "event path must not open modal even for base_inline route (#524)")
	  lu.assertEvalToTrue(not slice_consulted, "event path must not build choice view")
	  lu.assertEvalToTrue(not route_consulted, "event path must not resolve route key")
	  lu.assertEvalToTrue(not gate_consulted, "event path must not consult gate state")
	end

	-- _record_pending_choice：elapsed_seconds 透传、缺失时默认 0、set_ui_dirty(true)
	-- 的桩验证（杀掉 or→and、0→1、true→false 突变）。
	function TestUiFrontendGuardPaths:test_record_pending_choice_passes_through_elapsed_seconds_and_defaults_to_zero()
	  local state = {}
	  local captured_choice = nil
	  local captured_opts = nil
	  local ui_dirty_value = nil
	  support.with_patches({
	    { target = runtime_state, key = "set_pending_choice",
	      value = function(_, choice, opts)
	        captured_choice = choice
	        captured_opts = opts
	      end },
	    { target = runtime_state, key = "set_ui_dirty",
	      value = function(_, dirty) ui_dirty_value = dirty end },
	  }, function()
	    -- 带 elapsed_seconds 的 payload：透传给 set_pending_choice。
	    runtime_event_ports.on_need_choice(state, function() return nil end, {
	      choice = { id = "ca" },
	      elapsed_seconds = 3.5,
	    })
	    lu.assertEvalToTrue(captured_choice ~= nil and captured_choice.id == "ca",
	      "choice is forwarded to set_pending_choice")
	    lu.assertEquals(captured_opts.elapsed_seconds, 3.5,
	      "elapsed_seconds is passed through from payload")
	    lu.assertEquals(ui_dirty_value, true, "set_ui_dirty is called with true")

	    -- 不带 elapsed_seconds 的 payload：默认 0
	    captured_opts = nil
	    ui_dirty_value = nil
	    runtime_event_ports.on_need_choice(state, function() return nil end, {
	      choice = { id = "cb" },
	    })
	    lu.assertEquals(captured_opts.elapsed_seconds, 0,
	      "missing elapsed_seconds defaults to 0")

	    -- nil payload：不触发 _record_pending_choice
	    captured_choice = nil
	    captured_opts = nil
	    ui_dirty_value = nil
	    runtime_event_ports.on_need_choice(state, function() return nil end, nil)
	    lu.assertNil(captured_choice, "nil payload must not record pending choice")
	  end)
	end


return TestUiFrontendGuardPaths
