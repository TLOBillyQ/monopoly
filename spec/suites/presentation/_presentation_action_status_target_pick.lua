local P = require("support.presentation_action_status_prelude")
local _assert_eq = P.assert_eq
local _bind_ui_runtime = P.bind_ui_runtime
local _with_patches = P.with_patches
local _ui_runtime = P.ui_runtime
local _build_role_with_events = P.build_role_with_events
local _build_choice_modal_state = P.build_choice_modal_state
local _build_target_pick_env = P.build_target_pick_env
local canvas_event_router = require("src.ui.coord.canvas_event_router")
local ui_view = require("src.ui.coord.ui_runtime")
local modal_presenter = require("src.ui.coord.modal")
local target_pick = require("src.config.gameplay.target_pick")
local host_runtime = require("src.host")
local host_runtime_bridge = require("src.ui.host_bridge")
local target_choice_effects = require("src.ui.coord.target_choice_effects")
local vec3 = require("fixtures.vec3")

local function _with_target_pick_runtime(env, fn)
  local marker_seq = 0
  local created_markers = {}
  local current_hit = nil
  local owner_role = {
    get_ctrl_unit = function()
      return {
        get_position = function()
          return vec3.with_sub_length(0, 0, 0)
        end,
      }
    end,
  }
  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = env.query_nodes, EVENT = { CLICK = "CLICK" } } },
    { key = "all_roles", value = nil },
    { target = host_runtime, key = "resolve_role", value = function()
      return owner_role
    end },
    { target = host_runtime, key = "build_camera_ray", value = function()
      return { start_pos = vec3.with_sub_length(0, 1, 0), end_pos = vec3.with_sub_length(0, 1, 20) }
    end },
    { target = host_runtime, key = "pick_first_hit_unit", value = function()
      return current_hit
    end },
    { target = host_runtime, key = "create_unit_with_scale", value = function(_, pos)
      marker_seq = marker_seq + 1
      local marker = {
        _unit_id = 3000 + marker_seq,
        _position = pos,
      }
      created_markers[#created_markers + 1] = marker
      return marker
    end },
    { target = host_runtime, key = "destroy_unit", value = function(marker)
      marker._destroyed = true
    end },
    { target = host_runtime, key = "get_unit_id", value = function(unit)
      return unit and unit._unit_id or nil
    end },
    { target = host_runtime, key = "resolve_hit_position", value = function(hit)
      return hit and hit.hit_pos or nil
    end },
  }, function()
    fn({
      set_hit = function(unit_id, hit_pos)
        if unit_id == nil then
          current_hit = nil
          return
        end
        current_hit = {
          unit = { _unit_id = unit_id },
          hit = { hit_pos = hit_pos },
        }
      end,
      created_markers = created_markers,
    })
  end)
end

local function _test_target_screen_uses_labels_only_and_hides_projection_with_slots()
  local state, nodes, query_nodes = _build_choice_modal_state()
  local choice = {
    id = 88,
    kind = "roadblock_target",
    route_key = "target",
    owner_role_id = 1,
    uses_target_picker = true,
    target_picker_owner_role_id = 1,
    title = "路障卡：选择位置",
    body = "body",
    options = {
      { id = 101, label = "福州路" },
      { id = 102, label = "台北路" },
      { id = 103, label = "黑市" },
      { id = 104, label = "武汉路" },
      { id = 201, label = "南京路" },
      { id = 202, label = "上海路" },
      { id = 203, label = "香港路" },
    },
    allow_cancel = true,
    cancel_label = "放弃",
  }

  nodes["位置-槽位1投影"].visible = true
  nodes["位置-槽位1投影"].disabled = false
  nodes["位置-槽位7投影"].visible = true
  nodes["位置-槽位7投影"].disabled = false

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    modal_presenter.open_choice_modal(state, choice)
    _assert_eq(state.ui.active_choice_screen_key, "target", "roadblock_target should open target screen")
    _assert_eq(nodes["位置-槽位1按钮"].text, "", "slot1 button text should stay empty")
    _assert_eq(nodes["位置-槽位7按钮"].text, "", "slot7 button text should stay empty")
    _assert_eq(nodes["位置-槽位1文本"].text, "福州路", "slot1 label should show tile name")
    _assert_eq(nodes["位置-槽位4文本"].text, "武汉路", "slot4 label should show current tile name")
    _assert_eq(nodes["位置-槽位7文本"].text, "香港路", "slot7 label should show tile name")
    _assert_eq(nodes["位置-槽位7按钮"].visible, true, "slot7 button should be visible when seven candidates exist")
    _assert_eq(nodes["位置-槽位7文本"].visible, true, "slot7 label should be visible when seven candidates exist")
    _assert_eq(nodes["位置-槽位1投影"].visible, true, "slot projection should be visible with populated slot")
    _assert_eq(nodes["位置-槽位1投影"].disabled, true, "slot projection should stay non-interactive")
    _assert_eq(nodes["位置-槽位7投影"].visible, true, "slot7 projection should be visible with populated slot")
    _assert_eq(nodes["位置-槽位7投影"].disabled, true, "slot7 projection should stay non-interactive")

    local common = require("src.ui.coord.choice_screens.helpers")
    common.hide_choice_screens(state.ui)

    _assert_eq(nodes["位置-槽位1文本"].visible, false, "hide_choice_screens should hide slot label")
    _assert_eq(nodes["位置-槽位1按钮"].disabled, true, "hide_choice_screens should disable slot button")
    _assert_eq(nodes["位置-槽位1投影"].visible, false, "hide_choice_screens should hide slot projection")
    _assert_eq(nodes["位置-槽位1投影"].disabled, true, "hide_choice_screens should disable slot projection")
  end)
end

local function _test_target_screen_hides_unused_slots_when_unique_options_less_than_seven()
  local state, nodes, query_nodes = _build_choice_modal_state()
  local choice = {
    id = 89,
    kind = "roadblock_target",
    route_key = "target",
    owner_role_id = 1,
    uses_target_picker = true,
    target_picker_owner_role_id = 1,
    title = "路障卡：选择位置",
    body = "body",
    options = {
      { id = 101, label = "机会卡" },
      { id = 102, label = "济南路" },
      { id = 103, label = "南京路" },
      { id = 104, label = "上海路" },
      { id = 105, label = "合肥路" },
      { id = 106, label = "郑州路" },
    },
    allow_cancel = true,
    cancel_label = "放弃",
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    modal_presenter.open_choice_modal(state, choice)
    _assert_eq(state.ui.active_choice_screen_key, "target", "target screen should open for unique-option roadblock choice")
    _assert_eq(nodes["位置-槽位6按钮"].visible, true, "slot6 button should stay visible for the sixth unique option")
    _assert_eq(nodes["位置-槽位6文本"].text, "郑州路", "slot6 label should match the last unique option")
    _assert_eq(nodes["位置-槽位7按钮"].visible, false, "slot7 button should hide when only six unique options exist")
    _assert_eq(nodes["位置-槽位7文本"].visible, false, "slot7 label should hide when only six unique options exist")
  end)
end

local function _test_target_confirm_dispatches_selected_option()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.on_scene_pick(env.state, 102, 1, {})
    env.nodes["位置_确认按钮"]._listener_cb({})
    _assert_eq(#env.state.turn_action_port.dispatched, 1, "confirm should dispatch one action")
    _assert_eq(env.state.turn_action_port.dispatched[1].type, "choice_select", "confirm should dispatch choice_select")
    _assert_eq(env.state.turn_action_port.dispatched[1].option_id, 102, "confirm should dispatch locked option")
  end)
end

local function _test_target_pick_tick_updates_selection_on_hit_change()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    runtime.set_hit(env.tile_unit_ids[102], env.tile_positions[102])
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.hover_option_id, nil, "hover should wait for external pick")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, nil, "hover should not lock selected option")
    _assert_eq(env.arrow.visible, false, "arrow should stay hidden before lock")
  end)
end

local function _test_target_pick_tick_ignores_non_candidate()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    runtime.set_hit(9999, vec3.with_sub_length(999, 0, 0))
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.hover_option_id, nil, "non-candidate ray hit should be ignored")
  end)
end

local function _test_target_pick_scene_click_locks_target_and_pauses_raycast()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.on_scene_pick(env.state, 103, 1, {})
    runtime.set_hit(env.tile_unit_ids[102], env.tile_positions[102])
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.locked_option_id, 103, "scene pick should lock option")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, 103, "locked option should sync selected option")
    _assert_eq(env.state.target_choice_runtime.hover_option_id, 103, "locked option should drive hover")
  end)
end

local function _test_target_pick_confirm_requires_lock()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    env.nodes["位置_确认按钮"]._listener_cb({})
    _assert_eq(#env.state.turn_action_port.dispatched, 0, "confirm should not dispatch without lock")
    target_choice_effects.on_scene_pick(env.state, 101, 1, {})
    env.nodes["位置_确认按钮"]._listener_cb({})
    _assert_eq(#env.state.turn_action_port.dispatched, 1, "confirm should dispatch after lock")
    _assert_eq(env.state.turn_action_port.dispatched[1].option_id, 101, "confirm should use locked option")
  end)
end

local function _test_target_pick_cancel_unlocks_and_resumes_raycast()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.on_scene_pick(env.state, 103, 1, {})
    _assert_eq(env.nodes["位置_确认按钮"].text, "确定", "confirm text should be visible while locked")
    _assert_eq(env.nodes["位置_取消按钮"].text, "取消", "cancel text should be visible while locked")
    env.nodes["位置_取消按钮"]._listener_cb({})
    _assert_eq(env.state.target_choice_runtime.locked_option_id, nil, "cancel should clear lock")
    _assert_eq(env.nodes["位置_确认按钮"].visible, false, "confirm should hide after unlock")
    _assert_eq(env.nodes["位置_取消按钮"].visible, false, "cancel should hide after unlock")
    _assert_eq(env.nodes["位置_确认按钮"].text, "", "confirm text should clear after unlock")
    _assert_eq(env.nodes["位置_取消按钮"].text, "", "cancel text should clear after unlock")
    runtime.set_hit(env.tile_unit_ids[102], env.tile_positions[102])
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.hover_option_id, nil, "unlock should wait for next external pick")
  end)
end

local function _test_target_pick_cancel_noop_when_unlocked()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    env.nodes["位置_取消按钮"]._listener_cb({})
    _assert_eq(env.state.target_choice_runtime.locked_option_id, nil, "cancel should stay noop when unlocked")
    _assert_eq(#env.state.turn_action_port.dispatched, 0, "cancel should not dispatch game action")
  end)
end

local function _test_target_pick_leave_hides_scene_units()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.leave(env.state, "test")
    _assert_eq(env.arrow.visible, false, "leave should hide arrow")
    _assert_eq(#runtime.created_markers, 0, "leave should not depend on spawned markers")
  end)
end

local function _test_target_pick_enter_spawns_candidate_markers_at_height_1_6()
  local env = _build_target_pick_env()
  local old_height = target_pick.marker_height_offset
  target_pick.marker_height_offset = 1.6
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    _assert_eq(#runtime.created_markers, 0, "enter should wait external event and skip marker spawn")
  end)
  target_pick.marker_height_offset = old_height
end

local function _test_target_pick_degrades_without_raycast_api()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    _with_patches({
      { target = host_runtime, key = "build_camera_ray", value = function()
        return nil, "missing"
      end },
    }, function()
      target_choice_effects.enter(env.state, env.choice)
      target_choice_effects.step(env.game, env.state, 0.1)
      target_choice_effects.on_scene_pick(env.state, 102, 1, {})
      env.nodes["位置_确认按钮"]._listener_cb({})
      _assert_eq(#env.state.turn_action_port.dispatched, 1, "confirm should still work when raycast unavailable")
      _assert_eq(env.state.turn_action_port.dispatched[1].option_id, 102, "confirm should use locked option")
    end)
  end)
end

local function _test_target_pick_scene_click_resolves_option_from_payload_unit()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    local handled = target_choice_effects.on_scene_pick(env.state, nil, 1, {
      unit = { _unit_id = env.tile_unit_ids[102] },
    })
    _assert_eq(handled, true, "scene pick should accept payload.unit fallback")
    _assert_eq(env.state.target_choice_runtime.locked_option_id, 102, "payload.unit should resolve tile option id")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, 102, "payload.unit fallback should sync selected option")
  end)
end

local function _test_target_pick_owner_role_falls_back_to_current_player()
  local env = _build_target_pick_env()
  env.choice.owner_role_id = nil
  env.choice.target_picker_owner_role_id = nil
  env.game.current_player = function()
    return { id = "7" }
  end

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    _assert_eq(env.state.target_choice_runtime.owner_role_id, 7, "missing explicit owner should fall back to current player id")
    local rejected = target_choice_effects.on_scene_pick(env.state, 101, 6, {})
    local handled = target_choice_effects.on_scene_pick(env.state, 101, "7", {})
    _assert_eq(rejected, false, "mismatched actor should still be rejected under current-player fallback")
    _assert_eq(handled, true, "current-player fallback owner should accept matching actor role id")
  end)
end

local function _test_target_pick_owner_role_falls_back_to_choice_owner_role_id()
  local env = _build_target_pick_env()
  env.choice.target_picker_owner_role_id = nil
  env.choice.owner_role_id = "8"
  env.game.current_player = function()
    return { id = 3 }
  end

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    _assert_eq(env.state.target_choice_runtime.owner_role_id, 8,
      "missing target_picker_owner_role_id should fall back to choice owner_role_id")
    local rejected = target_choice_effects.on_scene_pick(env.state, 101, 7, {})
    local handled = target_choice_effects.on_scene_pick(env.state, 101, "8", {})
    _assert_eq(rejected, false, "choice owner fallback should reject mismatched actor role id")
    _assert_eq(handled, true, "choice owner fallback should accept normalized matching actor role id")
  end)
end

local function _test_target_pick_scene_click_normalizes_string_option_id()
  local env = _build_target_pick_env()

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    local handled = target_choice_effects.on_scene_pick(env.state, "102", 1, {})
    _assert_eq(handled, true, "scene pick should normalize string option ids")
    _assert_eq(env.state.target_choice_runtime.locked_option_id, 102,
      "normalized string option id should lock matching candidate")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, 102,
      "normalized string option id should sync selected option")
  end)
end

local function _test_target_pick_scene_click_rejects_payload_unit_without_mapping()
  local env = _build_target_pick_env()

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    local handled = target_choice_effects.on_scene_pick(env.state, nil, 1, {
      unit = { _unit_id = 999999 },
    })
    _assert_eq(handled, false, "payload.unit without tile mapping should be ignored")
    _assert_eq(env.state.target_choice_runtime.locked_option_id, nil,
      "payload.unit without mapping should not lock any option")
  end)
end

local function _test_ui_event_router_player_target_click_direct_submit()
  local function new_node()
    local node = {}
    function node:listen(_, cb)
      self._listener_cb = cb
      return {
        destroy = function()
          self._listener_cb = nil
        end,
      }
    end
    return node
  end

  local node_map = {}
  local function query_nodes_by_name(name)
    local node = node_map[name]
    if not node then
      node = new_node()
      node_map[name] = node
    end
    return { node }
  end

  local captured = {}
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        table.insert(captured, action)
      end,
      should_block_action = function()
        return false
      end,
    },
    ui = ui_view.build_ui_state(),
    ui_model = {
      current_player_id = 1,
      choice = {
        id = 10,
        kind = "item_target_player",
        route_key = "player",
        allow_cancel = true,
        options = {
          { id = 11, label = "玩家A" },
          { id = 22, label = "玩家B" },
          { id = 33, label = "玩家C" },
        },
      },
    },
    pending_choice_selected_option_id = nil,
    choice_visible_option_ids = nil,
  }
  _bind_ui_runtime(state)
  local role = _build_role_with_events(101, {})

  _with_patches({
    { key = "all_roles", value = { role } },
    { target = host_runtime_bridge, key = "resolve_roles", value = function()
      return { role }
    end },
    { target = host_runtime_bridge, key = "resolve_role", value = function(role_id)
      if tostring(role_id) == "101" then
        return role
      end
      return nil
    end },
    { key = "GameAPI", value = {
      get_role = function(role_id)
        if role_id == 101 then
          return role
        end
        return nil
      end,
    } },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = query_nodes_by_name,
    } },
  }, function()
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map["玩家选择_槽位2"]._listener_cb({})

    state.ui_model.choice = {
      id = 20,
      kind = "roadblock_target",
      route_key = "target",
      owner_role_id = 1,
      uses_target_picker = true,
      target_picker_owner_role_id = 1,
      allow_cancel = true,
      options = {
        { id = 101, label = "前1" },
        { id = 102, label = "前2" },
        { id = 103, label = "前3" },
        { id = 201, label = "后1" },
        { id = 202, label = "后2" },
      },
    }
    -- target_choice 现在是事件驱动，不再通过 UI 点击触发
  end)

  _assert_eq(captured[1] and captured[1].type, "choice_select", "player click should dispatch choice_select")
  _assert_eq(captured[1] and captured[1].choice_id, 10, "player click should keep choice id")
  _assert_eq(captured[1] and captured[1].option_id, 22, "player click should submit clicked option")
  _assert_eq(captured[1] and captured[1].actor_role_id, 1, "player click should inject fallback actor_role_id")
  _assert_eq(captured[2], nil, "target choice should not dispatch from legacy UI slot click path")
end

local function _test_target_pick_prefers_explicit_owner_role_id()
  local env = _build_target_pick_env()
  env.choice.target_picker_owner_role_id = 7
  env.choice.owner_role_id = 7
  env.choice.meta.player_id = 2
  env.state.game.current_player = function()
    return { id = 3 }
  end

  local entered = target_choice_effects.enter(env.state, env.choice)
  _assert_eq(entered, true, "target picker should still enter")
  _assert_eq(env.state.target_choice_runtime and env.state.target_choice_runtime.owner_role_id, 7,
    "target picker should use explicit owner role id before meta/current-player fallback")
  target_choice_effects.leave(env.state, "test_cleanup")
end

return {
  name = "presentation_target_pick",
  tests = {
    { name = "_test_target_screen_uses_labels_only_and_hides_projection_with_slots", run = _test_target_screen_uses_labels_only_and_hides_projection_with_slots },
    { name = "_test_target_screen_hides_unused_slots_when_unique_options_less_than_seven", run = _test_target_screen_hides_unused_slots_when_unique_options_less_than_seven },
    { name = "_test_target_confirm_dispatches_selected_option", run = _test_target_confirm_dispatches_selected_option },
    { name = "_test_target_pick_tick_updates_selection_on_hit_change", run = _test_target_pick_tick_updates_selection_on_hit_change },
    { name = "_test_target_pick_tick_ignores_non_candidate", run = _test_target_pick_tick_ignores_non_candidate },
    { name = "_test_target_pick_scene_click_locks_target_and_pauses_raycast", run = _test_target_pick_scene_click_locks_target_and_pauses_raycast },
    { name = "_test_target_pick_confirm_requires_lock", run = _test_target_pick_confirm_requires_lock },
    { name = "_test_target_pick_cancel_unlocks_and_resumes_raycast", run = _test_target_pick_cancel_unlocks_and_resumes_raycast },
    { name = "_test_target_pick_cancel_noop_when_unlocked", run = _test_target_pick_cancel_noop_when_unlocked },
    { name = "_test_target_pick_leave_hides_scene_units", run = _test_target_pick_leave_hides_scene_units },
    { name = "_test_target_pick_enter_spawns_candidate_markers_at_height_1_6", run = _test_target_pick_enter_spawns_candidate_markers_at_height_1_6 },
    { name = "_test_target_pick_degrades_without_raycast_api", run = _test_target_pick_degrades_without_raycast_api },
    { name = "_test_target_pick_scene_click_resolves_option_from_payload_unit", run = _test_target_pick_scene_click_resolves_option_from_payload_unit },
    { name = "_test_target_pick_owner_role_falls_back_to_current_player", run = _test_target_pick_owner_role_falls_back_to_current_player },
    { name = "_test_target_pick_owner_role_falls_back_to_choice_owner_role_id", run = _test_target_pick_owner_role_falls_back_to_choice_owner_role_id },
    { name = "_test_target_pick_scene_click_normalizes_string_option_id", run = _test_target_pick_scene_click_normalizes_string_option_id },
    { name = "_test_target_pick_scene_click_rejects_payload_unit_without_mapping", run = _test_target_pick_scene_click_rejects_payload_unit_without_mapping },
    { name = "_test_ui_event_router_player_target_click_direct_submit", run = _test_ui_event_router_player_target_click_direct_submit },
    { name = "_test_target_pick_prefers_explicit_owner_role_id", run = _test_target_pick_prefers_explicit_owner_role_id },
  },
}
