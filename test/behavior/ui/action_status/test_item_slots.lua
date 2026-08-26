---@diagnostic disable: need-check-nil, different-requires, undefined-field

-- 道具槽渲染/路由/item_phase_ask 规约（#191 降密）。公共 fixture:
-- _make_slot_state(槽位 state + touch/visible/label 捕获)、_event_patches
-- (ui_events 扇出捕获)、_make_ask_state(item_phase_ask 待确认 state)。
local luax = require("test.support.luax")
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local _bind_ui_runtime = P.bind_ui_runtime
local _with_patches = P.with_patches
local _build_asset_context = P.build_asset_context
local _has_event = P.has_event
local ui_view = require("src.ui.coord.ui_runtime")
local ui_events = require("src.ui.coord.ui_events")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local ids = require("test.fixtures.item_slot_ids")
local pending_confirmation = require("src.state.pending_confirmation")
local highlight_lifecycle = require("src.ui.state.item_slot_highlight_lifecycle_queue")

-- 通过公开接口把 state 置为「item_phase 询问已确认」：enter 后立即 confirm。
local function _confirm_item_phase_ask(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
end

-- 宿主点击事件的最小形状：data.role 携带点击者 roleid，路由据此解析行动者。
local function _role_event(role_id)
  return { role = { get_roleid = function() return role_id end } }
end

local _KEEP_SIZE_MANAGER = {
  client_role = nil,
  query_nodes_by_name = function()
    return { { set_texture_keep_size = function() end } }
  end,
}

-- n 个槽位的 state,附 touch/visible/label 捕获表;icon_ids 注入资源上下文。
local function _make_slot_state(slot_count, icon_ids, extra)
  local caps = { touch = {}, visible = {}, label = {} }
  local refs = { ["Empty"] = "EMPTY" }
  for _, id in ipairs(icon_ids or {}) do
    refs[tostring(id)] = "ICON" .. tostring(id)
  end
  local state = {
    runtime_asset_context = _build_asset_context(refs),
    ui = {
      item_slots = ids.slots(slot_count),
      set_touch_enabled = function(_, name, enabled)
        caps.touch[name] = enabled == true
      end,
      set_visible = function(_, name, visible)
        caps.visible[name] = visible == true
      end,
      set_label = function(_, name, text)
        caps.label[name] = text
      end,
    },
  }
  for key, value in pairs(extra or {}) do
    state[key] = value
  end
  return state, caps
end

local function _refresh(state, ui_model, opts)
  _with_patches({
    { key = "UIManager", value = _KEEP_SIZE_MANAGER },
  }, function()
    ui_view.refresh_item_slots(state, ui_model, opts or {
      display_player_id = 1,
      allow_interact = true,
    })
  end)
end

-- UIManager + ui_events 全量捕获补丁;事件顺次写入 events。
local function _event_patches(events)
  return {
    { key = "UIManager", value = _KEEP_SIZE_MANAGER },
    { target = ui_events, key = "send_to_all", value = function(event_name)
      events[#events + 1] = event_name
    end },
    { target = ui_events, key = "send_to_role", value = function(_, event_name)
      events[#events + 1] = event_name
    end },
  }
end

local function _count_event(events, event_name)
  local count = 0
  for _, value in ipairs(events) do
    if value == event_name then
      count = count + 1
    end
  end
  return count
end

-- item_phase_ask 已 enter 的 state;counters.closed 记录 modal 关闭次数。
local function _make_ask_state(choice, counters)
  counters = counters or {}
  local state = {
    gameplay_loop_ports = {
      modal = {
        close_choice_modal = function()
          counters.closed = (counters.closed or 0) + 1
        end,
      },
    },
    ui_model = { choice = choice },
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  return state
end

TestItemSlots = {}

function TestItemSlots:test_refresh_requires_ui_item_slots()
  -- kills L68 assert 的 and->or 与消息 -> nil(#262):
  -- ui=nil 时 or 变异体索引 nil 报异消息;ui 缺 item_slots 时 or 变异体
  -- 放行后跌进 ipairs(nil) 报异消息,只有精确消息能两种都封死。
  luax.has_error(function()
    ui_view.refresh_item_slots({ ui = nil }, { current_player_id = 1 })
  end, "missing ui item slots")
  luax.has_error(function()
    ui_view.refresh_item_slots({ ui = {} }, { current_player_id = 1 })
  end, "missing ui item slots")
end

function TestItemSlots:test_empty_slot_touch_stays_disabled()
  -- kills L88 空槽 `set_touch_enabled(slot_name, false)` 的 false->true(#262):
  -- 既有用例槽槽有道具,只钉到持卡槽的 touch。
  local state, caps = _make_slot_state(2, { 2001 })
  local ui_model = {
    current_player_id = 1,
    item_slots_by_player = { [1] = { 2001 } },
    choice = nil,
  }

  _refresh(state, ui_model)

  _assert_eq(caps.touch[ids.slot[1]], true, "slot with item should be clickable")
  _assert_eq(caps.touch[ids.slot[2]], false, "empty slot touch must stay disabled")
end

function TestItemSlots:test_item_slot_uses_keep_size_path()
  local keep_size_calls = 0
  local last_image_key = nil
  local slot_node = {
    set_texture_keep_size = function(_, image_key)
      keep_size_calls = keep_size_calls + 1
      last_image_key = image_key
    end,
  }
  local state = {
    runtime_asset_context = _build_asset_context({
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
    }),
    ui = {
      item_slots = ids.slots(1),
      set_touch_enabled = function() end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    item_slots = { 2001 },
    item_slots_by_player = {
      [1] = { 2001 },
    },
    choice = nil,
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = function() return { slot_node } end } },
  }, function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = false,
    })
  end)

  _assert_eq(keep_size_calls, 1, "item slot should use keep-size texture path")
  _assert_eq(last_image_key, "ICON2001", "item slot should set expected image key")
end

-- 触摸门合并用例:
-- #162 全时段可点口径:阶段外(choice 不用道具槽/无 choice)本人持卡槽位 touch
-- 保持开启,点击照样上报由 turn 裁定并给出拒因提示;他人回合门比「本地视角」;
-- 他人槽位与 allow_interact=false 仍关。
function TestItemSlots:test_item_slot_touch_gate_scenarios()
  local scenarios = {
    {
      model = {
        current_player_id = 1,
        item_choice_owner_id = 1,
        item_slots = { 2001 },
        item_slots_by_player = { [1] = { 2001 } },
        choice = { kind = "other", route_key = "base_inline" },
      },
      opts = { display_player_id = 1, allow_interact = true },
      expect = true,
      message = "own held card stays clickable outside an item-slot choice so turn can tip the reason",
    },
    {
      -- 行动者是对手,本地视角是玩家1
      model = {
        current_player_id = 2,
        item_slots_by_player = { [1] = { 2001 } },
        choice = nil,
      },
      opts = { display_player_id = 1, role_id = 1, allow_interact = true },
      expect = true,
      message = "local player's held card must stay clickable during another player's turn",
    },
    {
      model = {
        current_player_id = 1,
        item_slots = { 2001 },
        item_slots_by_player = { [2] = { 2001 } },
        choice = nil,
      },
      opts = { display_player_id = 2, allow_interact = true },
      expect = false,
      message = "another player's slots must not be clickable",
    },
    {
      model = {
        current_player_id = 1,
        item_choice_owner_id = 1,
        item_slots = { 2001 },
        item_slots_by_player = { [1] = { 2001 } },
        choice = {
          kind = "item_phase_passive",
          route_key = "base_inline",
          uses_item_slots = true,
          options = { { id = 2001 } },
        },
      },
      opts = { display_player_id = 1, allow_interact = false },
      expect = false,
      message = "slot should not be clickable when allow_interact is false",
    },
  }

  for _, scenario in ipairs(scenarios) do
    local state, caps = _make_slot_state(1, { 2001 })
    _refresh(state, scenario.model, scenario.opts)
    _assert_eq(caps.touch[ids.slot[1]], scenario.expect, scenario.message)
  end
end

-- #264 回归:无真人 role 的局走 for_each_role_or_global 全局兜底(role=nil),
-- presenter 传给 refresh 的 opts.role_id 就是 nil。钉死这条路径连刷不抛错、
-- 渲染结果与显式真人 role 分支一致(历史上这里用 table 当 pool key,沙盒一帧一抛;
-- 现 pool 已整体退场,本用例守的是 nil role 语义不再回归)。
function TestItemSlots:test_nil_role_global_fallback_matches_explicit_role_render()
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = { [1] = { 2002 } },
    choice = {
      kind = "item_phase_passive",
      route_key = "base_inline",
      uses_item_slots = true,
      options = { { id = 2002 } },
    },
  }

  local function _capture_refresh(opts)
    local image_keys = {}
    local state, caps = _make_slot_state(1, { 2002 })
    _with_patches({
      { key = "UIManager", value = {
        client_role = nil,
        query_nodes_by_name = function(name)
          return { { set_texture_keep_size = function(_, image_key)
            image_keys[name] = image_key
          end } }
        end,
      } },
    }, function()
      -- 连刷多次,钉住「每帧刷新」场景也不抛错。
      for _ = 1, 3 do
        ui_view.refresh_item_slots(state, ui_model, opts)
      end
    end)
    return caps, image_keys
  end

  local global_caps, global_images = _capture_refresh({
    display_player_id = 1,
    allow_interact = true,
  })
  local role_caps, role_images = _capture_refresh({
    display_player_id = 1,
    role_id = 1,
    allow_interact = true,
  })

  _assert_eq(global_caps.touch[ids.slot[1]], true, "nil role refresh should keep own slot clickable")
  _assert_eq(global_caps.touch[ids.slot[1]], role_caps.touch[ids.slot[1]],
    "nil role refresh should match explicit role touch semantics")
  _assert_eq(global_images[ids.slot[1]], role_images[ids.slot[1]],
    "nil role refresh should render the same slot image as explicit role")
  _assert_eq(global_images[ids.slot[1]], "ICON2002", "nil role refresh should resolve the item icon")
end

-- 展示层只报事实:不读 choice、不猜阶段,无论有没有道具窗都照常产出点击。
-- 「这一下能不能出牌」全部归 turn 裁定(test/behavior/turn/test_item_slot_click.lua)。
-- 唯一留在展示层的静默门是遮挡:弹层盖住时点击属误触。
function TestItemSlots:test_item_slot_click_is_choice_blind_and_silenced_only_by_overlay()
  local route = require("src.ui.input.route_item_slots")
  local slot_choice = {
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
  }
  local cases = {
    {
      ui_model = { choice = nil },
      message = "no choice at all must still raise the click",
    },
    {
      ui_model = { choice = { kind = "modal", uses_item_slots = false } },
      message = "a non item-slot choice must still raise the click",
    },
    {
      ui_model = { choice = slot_choice },
      message = "an item-slot choice raises the same click, not a special one",
    },
    {
      ui_model = { choice = { kind = "modal", uses_item_slots = false } },
      pending_choice = slot_choice,
      message = "runtime pending choice changes nothing for the presentation layer",
    },
  }

  for _, case in ipairs(cases) do
    local state = {
      ui = {
        item_slots = ids.slots(1),
      },
      ui_model = case.ui_model,
      pending_choice = case.pending_choice,
    }
    _bind_ui_runtime(state)

    local specs = route.build(state)
    for _, spec in ipairs(specs) do
      local intent = spec.build_intent(_role_event(3))
      _assert_eq(intent and intent.type, "item_slot_click", case.message)
      _assert_eq(intent and intent.slot_index, 1, "click should carry its slot index: " .. case.message)
      _assert_eq(intent and intent.actor_role_id, 3, "click should carry the clicking role: " .. case.message)
    end
  end

  -- 遮挡:槽位静默,不产出 intent。
  local blocked_state = {
    ui = {
      item_slots = ids.slots(1),
      popup_active = true,
    },
    ui_model = { choice = slot_choice },
  }
  _bind_ui_runtime(blocked_state)
  local blocked_specs = route.build(blocked_state)
  _assert_eq(blocked_specs[1].build_intent(_role_event(3)), nil,
    "slot click under an overlay is a mis-tap and must stay silent")
end

function TestItemSlots:test_item_phase_ask_confirm_queues_freeze_event()
  local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
  local counters = {}
  local state = _make_ask_state({
    id = 66,
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
  }, counters)

  local handled = item_phase_ask_flow.dispatch(state, {}, { type = "choice_select" }, {}, {
    dispatch_action = function()
      error("choice_select on item_phase_ask should not dispatch action directly")
    end,
  })

  _assert_eq(handled, true, "item_phase_ask choice_select should be handled")
  _assert_eq(pending_confirmation.is_active(state), false, "item_phase_ask should clear after confirm")
  _assert_eq(pending_confirmation.is_item_phase_confirmed(state), true, "item_phase_confirmed should become true after confirm")
  -- #595:确认登记 confirm_item_use 生命周期事件,冻结表示只此一份。
  local queued = highlight_lifecycle.drain(state)
  _assert_eq(queued ~= nil and #queued, 1, "confirm should queue one lifecycle event")
  _assert_eq(queued[1].kind, "confirm_item_use", "confirm queues a freeze event")
  _assert_eq(queued[1].choice_id, 66, "the freeze carries the confirmed choice id")
  _assert_eq(counters.closed, 1, "item_phase ask confirm should close modal once")
end

function TestItemSlots:test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select()
  local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
  local dispatched = {}
  local counters = {}
  local state = _make_ask_state({
    id = 88,
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    options = {
      { id = 2002, label = "导弹卡" },
    },
  }, counters)

  local handled = item_phase_ask_flow.dispatch(state, {}, {
    type = "choice_select",
    actor_role_id = 5,
  }, {
    source = "item_phase_ask",
  }, {
    dispatch_action = function(_, _, action, opts)
      dispatched[#dispatched + 1] = {
        action = action,
        opts = opts,
      }
    end,
  })

  _assert_eq(handled, true, "single-option item_phase_ask confirm should be handled")
  _assert_eq(pending_confirmation.is_active(state), false, "single-option item_phase_ask should clear active flag")
  _assert_eq(pending_confirmation.is_item_phase_confirmed(state), true, "single-option item_phase_ask should mark confirmed")
  _assert_eq(counters.closed, 1, "single-option item_phase_ask should close modal once")
  _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.type, "choice_select",
    "single-option item_phase_ask should dispatch choice_select directly")
  _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.choice_id, 88,
    "single-option item_phase_ask should keep choice id")
  _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.option_id, 2002,
    "single-option item_phase_ask should select the only option")
  _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.actor_role_id, 5,
    "single-option item_phase_ask should preserve actor role id")
end

-- 折叠 options 到单一 id 的分支：冲突 / nil id / 重复同 id / 裸 id。
-- 只有「所有 option 指向同一个 id」时才允许 pre-confirm 直接派发。
local function _dispatch_pre_confirm_with_options(options)
  local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
  local dispatched = {}
  local state = _make_ask_state({
    id = 91,
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    options = options,
  })
  item_phase_ask_flow.dispatch(state, {}, { type = "choice_select", actor_role_id = 5 }, {}, {
    dispatch_action = function(_, _, action)
      dispatched[#dispatched + 1] = action
    end,
  })
  return dispatched
end

function TestItemSlots:test_item_phase_ask_option_id_folding_gates_pre_confirm()
  -- 不同 id 冲突:不派发
  _assert_eq(#_dispatch_pre_confirm_with_options({ { id = 2002 }, { id = 2003 } }), 0,
    "options pointing at different ids are ambiguous and must not pre-confirm")

  -- 重复同 id:折叠到该 id
  local repeated = _dispatch_pre_confirm_with_options({ { id = 2002 }, { id = 2002 } })
  _assert_eq(#repeated, 1, "options all pointing at one id should pre-confirm")
  _assert_eq(repeated[1] and repeated[1].option_id, 2002,
    "repeated same-id options should resolve to that id")

  -- 缺 id 的 option table 会被 _option_id 当作「裸 id」原样返回（即 table 自身），
  -- 因而与真正的 id 冲突 —— 保守起见不 pre-confirm。这里钉的是现状行为。
  _assert_eq(#_dispatch_pre_confirm_with_options({ { label = "无 id" }, { id = 2002 } }), 0,
    "an option table lacking an id is not a match for the known id, so pre-confirm must not fire")

  -- 裸(非 table) id 同样折叠
  local bare = _dispatch_pre_confirm_with_options({ 2002, 2002 })
  _assert_eq(#bare, 1, "bare (non-table) option ids should resolve too")
  _assert_eq(bare[1] and bare[1].option_id, 2002, "bare option ids should resolve to that id")

  -- 冲突是终态:后续再匹配也不复活
  _assert_eq(#_dispatch_pre_confirm_with_options({ { id = 2002 }, { id = 2003 }, { id = 2002 } }), 0,
    "a conflict must stay terminal; a later id matching the first must not revive pre-confirm")
end

function TestItemSlots:test_item_phase_ask_cancel_dispatches_only_with_choice_id()
  local item_phase_ask_flow = require("src.ui.input.item_phase_ask")

  -- 有 choice id:派发 choice_cancel 并保留 actor
  local dispatched = {}
  local state = _make_ask_state({
    id = 77, kind = "item_phase_passive", route_key = "base_inline", uses_item_slots = true,
  })
  local handled = item_phase_ask_flow.dispatch(state, {}, { type = "choice_cancel", actor_role_id = 5 }, {}, {
    dispatch_action = function(_, _, action)
      dispatched[#dispatched + 1] = action
    end,
  })
  _assert_eq(handled, true, "item_phase_ask choice_cancel should be handled")
  _assert_eq(dispatched[1] and dispatched[1].type, "choice_cancel",
    "cancel with a live model choice should dispatch choice_cancel")
  _assert_eq(dispatched[1] and dispatched[1].choice_id, 77, "cancel should carry the model choice id")
  _assert_eq(dispatched[1] and dispatched[1].actor_role_id, 5, "cancel should preserve actor role id")

  -- 缺 choice id:handled 但不派发
  local skipped = {}
  local idless_state = _make_ask_state({
    kind = "item_phase_passive", route_key = "base_inline", uses_item_slots = true,
  })
  local idless_handled = item_phase_ask_flow.dispatch(idless_state, {}, { type = "choice_cancel", actor_role_id = 5 }, {}, {
    dispatch_action = function(_, _, action)
      skipped[#skipped + 1] = action
    end,
  })
  _assert_eq(idless_handled, true, "cancel without a choice id should still be handled")
  _assert_eq(#skipped, 0, "cancel without a choice id must not dispatch choice_cancel")
end

-- #595:关闭要登记「关的是哪个选择」的 choice_released 事件。只有带上正确的
-- choice_id,刷新层才能区分「关掉当前冻结的选择」和「迟到的旧选择关闭」
-- (场景 017/018)。关窗前读取:关窗后 ui_model 上的待决选择可能已消失。
function TestItemSlots:test_item_phase_ask_cancel_queues_the_closing_choice_id()
  local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
  local state = _make_ask_state({
    id = 77, kind = "item_phase_passive", route_key = "base_inline", uses_item_slots = true,
  })
  item_phase_ask_flow.dispatch(state, {}, { type = "choice_cancel", actor_role_id = 5 }, {}, {
    dispatch_action = function() end,
  })

  local queued = highlight_lifecycle.drain(state)
  _assert_eq(queued ~= nil and #queued, 1, "cancel should queue one lifecycle event")
  _assert_eq(queued[1].kind, "choice_released", "cancel queues a release event")
  _assert_eq(queued[1].choice_id, 77, "the release carries the choice being closed")
end

-- 缺 choice id 时仍要登记关闭事件(种类不变),只是选择标识缺失。
function TestItemSlots:test_item_phase_ask_cancel_without_choice_id_still_queues_release()
  local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
  local state = _make_ask_state({
    kind = "item_phase_passive", route_key = "base_inline", uses_item_slots = true,
  })
  item_phase_ask_flow.dispatch(state, {}, { type = "choice_cancel", actor_role_id = 5 }, {}, {
    dispatch_action = function() end,
  })

  local queued = highlight_lifecycle.drain(state)
  _assert_eq(queued ~= nil and #queued, 1, "cancel still queues a lifecycle event")
  _assert_eq(queued[1].kind, "choice_released", "the event kind stays choice_released")
  _assert_eq(queued[1].choice_id, nil, "a missing choice id stays missing")
end

function TestItemSlots:test_item_phase_ask_unknown_intent_type_is_not_handled()
  local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
  local state = _make_ask_state(nil)

  local handled = item_phase_ask_flow.dispatch(state, {}, { type = "unrelated_intent" }, {}, {
    dispatch_action = function()
      error("unknown intent must not dispatch")
    end,
  })

  _assert_eq(handled, false, "unknown intent type under item_phase_ask should not be handled")
end

function TestItemSlots:test_item_phase_confirmed_skips_replay_before_slot_click()
  local events = {}
  local state = _make_slot_state(1, { 2002 })
  _confirm_item_phase_ask(state)
  -- #595:冻结经生命周期事件登记(输入侧 choice_select 会 push 同样的事件)。
  highlight_lifecycle.push(state, "confirm_item_use", 77)
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = { [1] = { 2002 } },
    choice = {
      id = 77,
      kind = "item_phase_passive",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2002 } },
    },
  }

  _with_patches(_event_patches(events), function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)

  _assert_eq(_has_event(events, "高亮道具槽位牌1"), false,
    "confirmed item phase should not replay slot highlight before click")
  _assert_eq(_has_event(events, "重置高亮"), false,
    "confirmed item phase should not replay global highlight reset before click")
  -- 首次观察即被冻结:没有旧记忆,屏上没有陈旧高亮框可清,故连 reset 都不发。
  _assert_eq(highlight_lifecycle.drain(state), nil,
    "the freeze event is consumed by this refresh, not left to replay again")
end

function TestItemSlots:test_slot_click_unfreezes_and_emits_reset_on_next_refresh()
  local events = {}
  local dispatched = {}
  local state = _make_slot_state(1, { 2002 }, {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
      should_block_action = function()
        return false
      end,
    },
    ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots_by_player = { [1] = { 2002 } },
      choice = {
        id = 77,
        kind = "item_phase_passive",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
        options = { { id = 2002 } },
      },
    },
  })
  state.ui.active_choice_screen_key = "base_inline"
  _confirm_item_phase_ask(state)
  _bind_ui_runtime(state)

  _with_patches(_event_patches(events), function()
    ui_intent_dispatcher.dispatch(state, {}, {
      type = "item_slot_click",
      slot_index = 1,
      actor_role_id = 1,
    }, {})

    ui_view.refresh_item_slots(state, state.ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)

  -- #595:槽位命令登记 slot_command 解冻事件,刷新期被 drain 掉。
  _assert_eq(highlight_lifecycle.drain(state), nil,
    "the slot_command event is consumed by the refresh that follows the click")
  _assert_eq(_has_event(events, "重置高亮"), true,
    "next refresh after slot click should emit global reset to stop slot animation")
end

function TestItemSlots:test_phase_advance_hook_tracks_pickable_signature_not_phase_flips()
  -- #362 D3:phase-advance hook 锚定可选槽集合签名——集合不变时 phase 空翻
  -- 不发全局重置;集合变为空仍发清场重置。
  local events = {}
  local state = _make_slot_state(1, { 2002 }, {
    game = { turn = { phase = "roll", item_phase_active = "" } },
  })
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = { [1] = { 2002 } },
    -- choice 带 options 使槽 1 进入可选集合(签名 "1");choice 无
    -- pre_confirm_before_slot_pick,pending 未 enter → 仍走 passive 路径。
    choice = {
      id = 77,
      kind = "item_phase_passive",
      route_key = "base_inline",
      uses_item_slots = true,
      options = { { id = 2002 } },
    },
  }
  local function _refresh_once()
    ui_view.refresh_item_slots(state, ui_model, { display_player_id = 1, allow_interact = true })
  end

  _with_patches(_event_patches(events), function()
    _refresh_once()
    local baseline_count = _count_event(events, "重置高亮")

    -- 集合不变:不追加 reset
    _refresh_once()
    _assert_eq(_count_event(events, "重置高亮"), baseline_count,
      "unchanged pickable set should not emit additional 重置高亮 from phase-advance hook")

    -- phase 翻转但集合不变:仍不追加(可见签名锚定)
    state.game.turn.phase = "post_action"
    _refresh_once()
    _assert_eq(_count_event(events, "重置高亮"), baseline_count,
      "phase flip without pickable change should not emit 重置高亮 from phase-advance hook")

    -- 集合变为空:补发清场 reset
    ui_model.item_slots_by_player = { [1] = {} }
    _refresh_once()
    _assert_eq(_count_event(events, "重置高亮") > baseline_count, true,
      "the pickable set emptying should emit a fresh 重置高亮 event")
  end)
end

-- 他人回合回归:pending choice 属于行动方(飘飘),其可选集里的卡 id
-- (请神卡/送神卡)不得套到本地同名卡上抬槽;持卡槽位 touch 仍开(点由
-- turn 裁定弹「现阶段该卡无法使用」)。
function TestItemSlots:test_opponent_item_phase_choice_never_highlights_local_slots()
  local events = {}
  local state, caps = _make_slot_state(2, { 2005, 2006 })
  local ui_model = {
    current_player_id = 2,
    item_choice_owner_id = 2,
    item_slots_by_player = {
      [1] = { 2005, 2006 },
      [2] = { 2007 },
    },
    choice = {
      id = 88,
      kind = "item_phase_passive",
      route_key = "base_inline",
      uses_item_slots = true,
      owner_role_id = 2,
      options = { { id = 2005 }, { id = 2006 } },
    },
  }

  _with_patches(_event_patches(events), function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      role_id = 1,
      allow_interact = true,
    })
  end)

  _assert_eq(_has_event(events, "高亮道具槽位牌1"), false,
    "opponent-owned choice must not highlight local slot 1")
  _assert_eq(_has_event(events, "高亮道具槽位牌2"), false,
    "opponent-owned choice must not highlight local slot 2")
  _assert_eq(caps.touch[ids.slot[1]], true,
    "local held card stays clickable during another player's turn for the unusable tip")
end

function TestItemSlots:test_flat_single_tap_leaves_no_residual_item_phase_ask_state()
  local dispatched = {}
  local state = _make_slot_state(1, { 2002 }, {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
      should_block_action = function()
        return false
      end,
    },
    ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots_by_player = {
        [1] = { 2002 },
      },
      choice = {
        id = 66,
        kind = "item_phase_passive",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = false,
        options = { { id = 2002 } },
      },
    },
  })
  state.ui.active_choice_screen_key = "base_inline"
  _bind_ui_runtime(state)

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    ui_intent_dispatcher.dispatch(state, {}, {
      type = "item_slot_click",
      slot_index = 1,
      actor_role_id = 1,
    }, {})
  end)

  _assert_eq(#dispatched, 1, "flat single-tap should dispatch the original click once")
  _assert_eq(dispatched[1] and dispatched[1].type, "item_slot_click",
    "flat single-tap should hand the raw click to turn, not pre-chew it into a choice_select")
  _assert_eq(dispatched[1] and dispatched[1].slot_index, 1, "flat single-tap should keep the slot index")

  local fields = {
    "_pending_confirmation",
  }
  for _, field in ipairs(fields) do
    _assert_eq(state[field], nil, field .. " should be nil after flat single-tap dispatch")
  end
  -- #595/#596:冻结曾由扁平旗标表示,现由生命周期队列表示。断言活着的那份
  -- 表示——对已删除的字段断言 nil 会因「没人写它」而恒真,证明不了任何事。
  local queued = highlight_lifecycle.drain(state)
  _assert_eq(queued ~= nil and #queued, 1,
    "flat single-tap queues exactly one lifecycle event")
  _assert_eq(queued[1].kind, "slot_command",
    "a flat single-tap is a slot command, never a confirm freeze")
  _assert_eq(pending_confirmation.is_active(state), false,
    "flat single-tap should leave no pending confirmation")
  _assert_eq(pending_confirmation.is_item_phase_confirmed(state), false,
    "flat single-tap should leave no item_phase confirmed latch")
end

function TestItemSlots:test_item_slot_refresh_item_phase_ask_replays_highlight_immediately()
  -- #459:0.35s 外框延迟门控退役,ask 开窗即重放高亮,不再调度 reveal 定时器;
  -- 槽位集合不变的重复刷新不重放。
  local events = {}
  local timers = {}
  local state = _make_slot_state(3, { 2002, 2003 })
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = {
      [1] = { 2002, nil, 2003 },
    },
    choice = {
      id = 99,
      kind = "item_phase_passive",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2002 }, { id = 2003 } },
    },
  }

  local patches = _event_patches(events)
  patches[#patches + 1] = {
    key = "SetTimeOut",
    value = function(_, cb)
      timers[#timers + 1] = cb
    end,
  }

  _with_patches(patches, function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    _assert_eq(_count_event(events, "高亮道具槽位牌1"), 1, "item_phase_ask should emit highlight for slot1 once")
    _assert_eq(_count_event(events, "高亮道具槽位牌3"), 1, "item_phase_ask should emit highlight for slot3 once")
    _assert_eq(_count_event(events, "重置高亮"), 1, "item_phase_ask should emit global reset once")
    _assert_eq(#timers, 0, "item_phase_ask must not schedule any reveal timer (#459)")

    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    _assert_eq(_count_event(events, "高亮道具槽位牌1"), 1, "highlight should not replay every refresh")
    _assert_eq(_count_event(events, "高亮道具槽位牌3"), 1, "highlight should not replay every refresh")
    _assert_eq(#timers, 0, "repeat refreshes must stay timer-free")
  end)
end

function TestItemSlots:test_item_slot_refresh_resets_highlight_without_client_role()
  local events = {}
  local phase = ""

  local function _record(event_name)
    events[#events + 1] = { phase = phase, event_name = event_name }
  end

  local function _local_has_event(phase_name, event_name)
    for _, entry in ipairs(events) do
      if entry.phase == phase_name and entry.event_name == event_name then
        return true
      end
    end
    return false
  end

  local state = _make_slot_state(5, { 2002, 2003, 2004, 2007, 2008 })

  local pre_action_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = {
      [1] = { 2002, 2004, 2007, 2008, 2003 },
    },
    choice = {
      kind = "item_phase_passive",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2002 } },
    },
  }

  local remote_choice_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = {
      [1] = { 2002, 2004, 2007, 2008, 2003 },
    },
    choice = {
      kind = "remote_dice_value",
      route_key = "remote",
      options = { { id = 1 }, { id = 2 } },
    },
  }

  _with_patches({
    { key = "UIManager", value = _KEEP_SIZE_MANAGER },
    { target = ui_events, key = "send_to_all", value = function(event_name)
      _record(event_name)
    end },
    { target = ui_events, key = "send_to_role", value = function(_, event_name)
      _record(event_name)
    end },
  }, function()
    local function _refresh_model(model)
      ui_view.refresh_item_slots(state, model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end

    phase = "pre_action"
    _refresh_model(pre_action_model)

    phase = "repeat_item_phase"
    _refresh_model(pre_action_model)

    phase = "remote_choice"
    _refresh_model(remote_choice_model)

    phase = "pre_action_dice_multiplier"
    _refresh_model({
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots_by_player = {
        [1] = { 2004, 2007, 2008, 2003, nil },
      },
      choice = {
        kind = "item_phase_passive",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
        options = { { id = 2003 } },
      },
    })
  end)

  _assert_eq(_local_has_event("pre_action", "高亮道具槽位牌1"), true, "pre_action should highlight remote dice slot")
  _assert_eq(_local_has_event("pre_action", "重置高亮"), true, "pre_action should issue global reset before highlighting")
  _assert_eq(_local_has_event("repeat_item_phase", "重置高亮"), false,
    "an unchanged pickable set must not re-emit the global reset")
  _assert_eq(_local_has_event("repeat_item_phase", "高亮道具槽位牌1"), false,
    "an unchanged pickable set must not replay per-slot highlight events")
  _assert_eq(_local_has_event("remote_choice", "重置高亮"), true, "remote choice should issue global reset before slot reorder")
  _assert_eq(_local_has_event("remote_choice", "重置高亮道具槽位牌1"), true, "remote choice should reset slot1 highlight without client role")
  _assert_eq(_local_has_event("pre_action_dice_multiplier", "重置高亮"), true,
    "pre_action should issue global reset before highlighting dice multiplier slot")
  _assert_eq(_local_has_event("pre_action_dice_multiplier", "高亮道具槽位牌4"), true,
    "pre_action should highlight dice multiplier slot")
  _assert_eq(_local_has_event("pre_action_dice_multiplier", "重置高亮道具槽位牌1"), true,
    "pre_action should clear stale slot1 highlight")
end

function TestItemSlots:test_passive_slot_rendering_touch_states()
  -- passive 路由:全部槽位保持可点(不可用槽点了出原因提示)。
  local state, caps = _make_slot_state(5, { 2001, 2002, 2003, 2004, 2005 })
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots = { 2001, 2002, 2003, 2004, 2005 },
    item_slots_by_player = { [1] = { 2001, 2002, 2003, 2004, 2005 } },
    choice = {
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      uses_item_slots = true,
      options = { { id = 2001 }, { id = 2003 } },
    },
  }

  _refresh(state, ui_model)

  _assert_eq(caps.touch[ids.slot[1]], true, "passive: available slot 1 should be touchable")
  _assert_eq(caps.touch[ids.slot[2]], true, "passive: unavailable slot 2 should stay clickable so a reason tip can show")
  _assert_eq(caps.touch[ids.slot[3]], true, "passive: available slot 3 should be touchable")
  _assert_eq(caps.touch[ids.slot[4]], true, "passive: unavailable slot 4 should stay clickable so a reason tip can show")
  _assert_eq(caps.touch[ids.slot[5]], true, "passive: unavailable slot 5 should stay clickable so a reason tip can show")
end

function TestItemSlots:test_passive_highlight_dedupes_consecutive_refresh()
  local events = {}
  local state = _make_slot_state(2, { 2001, 2002 })
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots = { 2001, 2002 },
    item_slots_by_player = { [1] = { 2001, 2002 } },
    choice = {
      id = 333,
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      uses_item_slots = true,
      options = { { id = 2001 } },
    },
  }

  _with_patches(_event_patches(events), function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)

  _assert_eq(_count_event(events, "重置高亮"), 1,
    "passive highlight should emit global reset once for identical consecutive refreshes")
  _assert_eq(_count_event(events, "高亮道具槽位牌1"), 1,
    "passive highlight should emit slot highlight once for identical consecutive refreshes")
end

function TestItemSlots:test_confirm_freeze_blocks_slot_highlight_anim()
  -- #595:确认使用道具后冻结同一待决选择的重复高亮(场景 016)——冻结期间即使
  -- 首次观察到可选集合也不播放弹起动画,也不发 reset(屏上没有陈旧高亮框可清)。
  local events = {}
  local state = _make_slot_state(1, { 2001 })
  highlight_lifecycle.push(state, "confirm_item_use", 444)
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots = { 2001 },
    item_slots_by_player = { [1] = { 2001 } },
    choice = {
      id = 444,
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      uses_item_slots = true,
      options = { { id = 2001 } },
    },
  }

  _with_patches(_event_patches(events), function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)

  for _, name in ipairs(events) do
    _assert_eq(name:find("高亮道具槽位", 1, true), nil,
      "the confirm freeze must block the slot highlight animation, saw " .. name)
  end
  _assert_eq(_count_event(events, "重置高亮"), 0,
    "a frozen first observation has no stale highlight to reset")
end

function TestItemSlots:test_action_button_label_never_written()
  local state, caps = _make_slot_state(1, { 2001 })
  local function _model_with_route(route_key)
    return {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots = { 2001 },
      item_slots_by_player = { [1] = { 2001 } },
      choice = {
        kind = "item_phase_passive",
        route_key = route_key,
        uses_item_slots = true,
        options = { { id = 2001 } },
      },
    }
  end

  _refresh(state, _model_with_route("item_phase_passive"))
  _assert_eq(caps.label["基础_行动按钮"], nil, "guard: passive should not write action button label")

  caps.label = {}
  _refresh(state, _model_with_route("base_inline"))
  _assert_eq(caps.label["基础_行动按钮"], nil, "guard: non-passive should not write action button label")
end


return TestItemSlots
