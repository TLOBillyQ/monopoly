local number_utils = require("src.foundation.number")
local panel_slice = require("src.ui.view.panel_slice")
local panel_presenter = require("src.ui.render.widgets.presenter")
local route_base = require("src.ui.input.route_base")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local ui_runtime = require("src.ui.coord.ui_runtime")
local ui_state = require("src.ui.coord.ui_state")
local base_nodes = require("src.ui.schema.base")

local base_screen_steps = {}
local SKIN_ENTRY_NODES = {
  ["按钮"] = base_nodes.skin_button,
  ["文字"] = base_nodes.skin_label,
}
local AUXILIARY_ENTRY_NODES = {
  ["道具图鉴"] = base_nodes.gallery_button,
  ["托管按钮"] = base_nodes.auto_button,
  ["行动日志"] = base_nodes.action_log_button,
}

local function _role_id(world)
  return number_utils.to_integer(world.ui_role_id) or 1
end

local function _parse_auto_state(value)
  local text = tostring(value or "")
  if text == "开启" then
    return true
  end
  if text == "关闭" then
    return false
  end
  return nil, "unknown auto state: " .. text
end

local function _make_game()
  local players = {}
  for role_id = 1, 4 do
    players[role_id] = {
      id = role_id,
      name = "P" .. tostring(role_id),
      cash = 1000,
      properties = {},
    }
  end
  return { players = players }
end

local function _make_auto_enabled_by_player(world)
  return {
    [_role_id(world)] = world.base_screen_auto_enabled == true,
  }
end

local function _current_action_role_id(world)
  if world.base_screen_action_role_unset == true then
    return nil
  end
  return number_utils.to_integer(world.base_screen_action_role_id) or _role_id(world)
end

local function _valid_role_id(role_id)
  return role_id ~= nil and role_id >= 1 and role_id <= 4
end

local function _set_role_id(world, value)
  local role_id = number_utils.to_integer(value)
  if not _valid_role_id(role_id) then
    return nil, "invalid role_id: " .. tostring(value)
  end
  world.ui_role_id = role_id
  return true
end

local OPTIONAL_ACTION_KIND_BY_NAME = {
  ["道具槽位"] = "item_phase_passive",
  ["选择控件"] = "item_phase_passive",
  ["落地选择"] = "landing_optional_effect",
}

local FOLLOWUP_BY_OPTIONAL_ACTION = {
  ["道具槽位"] = "投骰移动落地流程",
  ["选择控件"] = "必经流程",
  ["落地选择"] = "回合清理流程",
}

local BLOCKING_STATE_BY_NAME = {
  ["选择弹窗"] = true,
  ["二次确认弹窗"] = true,
  ["目标选择"] = true,
  ["黑市界面"] = true,
  ["弹窗提示"] = true,
  ["行动动画"] = true,
  ["移动动画"] = true,
  ["落地视觉等待"] = true,
}

local STAGE_STATE_BY_NAME = {
  ["扣留等待"] = true,
  ["医院等待"] = true,
  ["山路等待"] = true,
  ["回合间等待"] = true,
  ["游戏结束"] = true,
  ["空可选行动阶段"] = true,
}

local function _resolve_followup_flow(world)
  local action_name = tostring(world.base_screen_optional_action or "")
  return FOLLOWUP_BY_OPTIONAL_ACTION[action_name] or "必经流程"
end

local function _optional_choice_for_world(world, action_role_id)
  if world.base_screen_empty_optional_phase == true or world.base_screen_optional_action == nil then
    return nil
  end
  local action_name = tostring(world.base_screen_optional_action)
  local kind = OPTIONAL_ACTION_KIND_BY_NAME[action_name]
  if kind == nil then
    return nil
  end
  return {
    id = 9001,
    kind = kind,
    route_key = kind == "item_phase_passive" and "item_phase_passive" or "base_inline",
    allow_cancel = true,
    owner_role_id = action_role_id,
    options = { { id = "optional", label = action_name } },
    meta = {
      optional_action = action_name,
      followup_flow = _resolve_followup_flow(world),
    },
  }
end

local function _set_optional_action_phase(world, action_name)
  local text = tostring(action_name or "")
  if OPTIONAL_ACTION_KIND_BY_NAME[text] == nil then
    return nil, "unknown optional action: " .. text
  end
  world.base_screen_optional_action = text
  world.base_screen_empty_optional_phase = false
  return true
end

local function _set_blocking_state(world, state_name)
  local text = tostring(state_name or "")
  if BLOCKING_STATE_BY_NAME[text] ~= true then
    return nil, "unknown blocking state: " .. text
  end
  world.base_screen_blocking_state = text
  world.base_screen_input_blocked = true
  return true
end

local function _set_stage_state(world, stage_name)
  local text = tostring(stage_name or "")
  if STAGE_STATE_BY_NAME[text] ~= true then
    return nil, "unknown stage state: " .. text
  end
  world.base_screen_stage_state = text
  world.base_screen_optional_action = nil
  world.base_screen_empty_optional_phase = text == "空可选行动阶段"
  if text ~= "空可选行动阶段" then
    world.base_screen_input_blocked = true
  end
  return true
end

local function _make_runtime(role_id)
  local role = { id = role_id }
  return {
    set_client_role = function() end,
    resolve_role_id = function(target_role)
      return target_role and target_role.id or nil
    end,
    for_each_role_or_global = function(callback)
      callback(role)
    end,
    query_node = function()
      return {}
    end,
    set_node_texture_native_size = function() end,
  }
end

local function _make_render_state(world)
  local state = { ui = ui_state.build_ui_state() }
  state.ui_refs = { images = { Empty = "EMPTY" } }
  state.ui.labels = {}
  state.ui.buttons = {}
  state.ui.visibility = {}
  state.ui.touch = {}
  state.ui.input_blocked = world and world.base_screen_input_blocked == true or false
  state.ui.set_label = function(self, name, text)
    self.labels[name] = text
  end
  state.ui.set_button = function(self, name, text)
    self.buttons[name] = text
  end
  state.ui.set_visible = function(self, name, value)
    self.visibility[name] = value
  end
  state.ui.set_touch_enabled = function(self, name, enabled)
    self.touch[name] = enabled
  end
  state.ui.query_node = function()
    return {}
  end
  return state
end

local function _build_ui_model(world)
  local game = _make_game()
  local action_role_id = _current_action_role_id(world)
  local panel_role_id = action_role_id or _role_id(world)
  local auto_enabled_by_player = _make_auto_enabled_by_player(world)
  local item_slots_by_player = {}
  if world.base_screen_viewer_is_spectator ~= true then
    item_slots_by_player[_role_id(world)] = {}
  end
  if action_role_id ~= nil then
    item_slots_by_player[action_role_id] = {}
  end
  return {
    current_player_id = action_role_id,
    auto_enabled_by_player = auto_enabled_by_player,
    board = { players = game.players },
    item_slots_by_player = item_slots_by_player,
    choice = _optional_choice_for_world(world, action_role_id),
    panel = panel_slice.build(
      game,
      { game = { board = {} } },
      { turn_count = 1, countdown_seconds = 0 },
      panel_role_id,
      auto_enabled_by_player
    ),
  }
end

local function _refresh_base_screen_for_player(world)
  world.base_screen_render_state = _make_render_state(world)
  world.base_screen_ui_model = _build_ui_model(world)
  world.base_screen_render_state.ui_runtime = {
    ui_model = world.base_screen_ui_model,
  }
  panel_presenter.refresh(world.base_screen_render_state, world.base_screen_ui_model, {
    runtime = _make_runtime(_role_id(world)),
    refresh_item_slots = function() end,
  })
  return world.base_screen_render_state
end

local function _find_base_route(state, node_name)
  for _, spec in ipairs(route_base.build(state)) do
    if spec.name == node_name then
      return spec
    end
  end
  return nil
end

local function _build_base_intent(world, node_name)
  if world.base_screen_render_state == nil then
    _refresh_base_screen_for_player(world)
  end
  local spec = _find_base_route(world.base_screen_render_state, node_name)
  if spec == nil or type(spec.build_intent) ~= "function" then
    return nil
  end
  return spec.build_intent()
end

local function _trigger_action_button(world)
  local intent = _build_base_intent(world, base_nodes.action_button)
  world.base_screen_action_button_triggered = true
  world.base_screen_action_button_intent = intent
  if intent and intent.type == "ui_button" and intent.id == "next" then
    world.base_screen_required_flow_started = true
  end
  return intent
end

local function _mark_optional_completed(world, intent)
  world.base_screen_optional_completed = true
  world.base_screen_pending_choice_cleared = true
  world.base_screen_followup_flow = _resolve_followup_flow(world)
  world.base_screen_end_button_intent = intent or world.base_screen_end_button_intent
  if world.base_screen_ui_model then
    world.base_screen_ui_model.choice = nil
  end
  local ui_model = world.base_screen_render_state
    and world.base_screen_render_state.ui_runtime
    and world.base_screen_render_state.ui_runtime.ui_model
  if ui_model then
    ui_model.choice = nil
  end
end

local function _trigger_end_button(world)
  local intent = _build_base_intent(world, base_nodes.end_button)
  world.base_screen_end_button_intent = intent
  if intent and intent.type == "choice_cancel" then
    _mark_optional_completed(world, intent)
  end
  return intent
end

local function _assert_end_button_hidden(world)
  local state = world.base_screen_render_state
  local actual = state and state.ui and state.ui.visibility and state.ui.visibility[base_nodes.end_button]
  if actual ~= false then
    return nil, "expected end button hidden, got " .. tostring(actual)
  end
  return true
end

local function _assert_end_button_not_touchable(world)
  local state = world.base_screen_render_state
  local actual = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.end_button]
  if actual == true then
    return nil, "expected end button not touchable"
  end
  return true
end

local function _auxiliary_entry_node(name)
  return AUXILIARY_ENTRY_NODES[tostring(name or "")]
end

function base_screen_steps.handlers()
  return {
    ["玩家托管状态为<托管状态>"] = function(world, example)
      local enabled, err = _parse_auto_state(example["托管状态"])
      if enabled == nil and err ~= nil then
        return nil, err
      end
      world.base_screen_auto_enabled = enabled
      return true
    end,

    ["基础屏刷新"] = function(world)
      local role_id = _role_id(world)
      world.base_screen_panel = panel_slice.build(
        _make_game(),
        { game = { board = {} } },
        { turn_count = 1, countdown_seconds = 0 },
        role_id,
        _make_auto_enabled_by_player(world)
      )
      return true
    end,

    ["玩家角色ID为<观察角色ID>"] = function(world, example)
      return _set_role_id(world, example["观察角色ID"])
    end,

    ["观察身份为<观察身份>"] = function(world, example)
      local identity = tostring(example["观察身份"] or "")
      if identity ~= "旁观角色" then
        return nil, "unknown observer identity: " .. identity
      end
      world.ui_role_id = 99
      world.base_screen_viewer_is_spectator = true
      return true
    end,

    ["当前轮到角色ID为<行动角色ID>"] = function(world, example)
      local role_id = number_utils.to_integer(example["行动角色ID"])
      if not _valid_role_id(role_id) then
        return nil, "invalid action role_id: " .. tostring(example["行动角色ID"])
      end
      world.base_screen_action_role_id = role_id
      world.base_screen_action_role_unset = false
      return true
    end,

    ["当前轮到角色ID为<角色ID>"] = function(world, example)
      local role_id = number_utils.to_integer(example["角色ID"])
      if not _valid_role_id(role_id) then
        return nil, "invalid action role_id: " .. tostring(example["角色ID"])
      end
      world.base_screen_action_role_id = role_id
      world.base_screen_action_role_unset = false
      return true
    end,

    ["当前行动控制为人类"] = function(world)
      world.base_screen_action_control = "人类"
      world.base_screen_input_blocked = false
      return true
    end,

    ["当前行动控制为<行动控制>"] = function(world, example)
      local control = tostring(example["行动控制"] or "")
      if control ~= "人类" and control ~= "AI" and control ~= "托管" then
        return nil, "unknown action control: " .. control
      end
      world.base_screen_action_control = control
      if control ~= "人类" then
        world.base_screen_input_blocked = true
      end
      return true
    end,

    ["当前轮次未定"] = function(world)
      world.base_screen_action_role_id = nil
      world.base_screen_action_role_unset = true
      return true
    end,

    ["输入门已锁"] = function(world)
      world.base_screen_input_blocked = true
      return true
    end,

    ["玩家处于行动等待阶段"] = function(world)
      world.base_screen_optional_action = nil
      world.base_screen_empty_optional_phase = false
      world.base_screen_stage_state = "行动等待阶段"
      return true
    end,

    ["玩家处于包含<可选行动>的可选行动阶段"] = function(world, example)
      return _set_optional_action_phase(world, example["可选行动"])
    end,

    ["行动角色处于包含<可选行动>的可选行动阶段"] = function(world, example)
      return _set_optional_action_phase(world, example["可选行动"])
    end,

    ["没有阻断性界面或动画等待"] = function(world)
      world.base_screen_input_blocked = false
      world.base_screen_blocking_state = nil
      return true
    end,

    ["<阻断状态>正在生效"] = function(world, example)
      return _set_blocking_state(world, example["阻断状态"])
    end,

    ["玩家处于<阶段状态>"] = function(world, example)
      return _set_stage_state(world, example["阶段状态"])
    end,

    ["基础屏为该玩家刷新"] = function(world)
      _refresh_base_screen_for_player(world)
      return true
    end,

    ["基础屏为观察玩家刷新"] = function(world)
      _refresh_base_screen_for_player(world)
      return true
    end,

    ["基础屏为观察身份刷新"] = function(world)
      _refresh_base_screen_for_player(world)
      return true
    end,

    ["基础屏刷新后应用输入锁"] = function(world)
      world.base_screen_input_blocked = true
      ui_runtime.apply_input_lock(_refresh_base_screen_for_player(world))
      return true
    end,

    ["基础屏当前行动角色ID为<预期行动角色ID>"] = function(world, example)
      local expected = number_utils.to_integer(example["预期行动角色ID"])
      if expected == nil then
        return nil, "invalid expected action role_id: " .. tostring(example["预期行动角色ID"])
      end
      local actual = world.base_screen_ui_model and world.base_screen_ui_model.current_player_id or nil
      if actual ~= expected then
        return nil, "expected current action role_id " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏<入口>未被输入锁隐藏"] = function(world, example)
      local node = _auxiliary_entry_node(example["入口"])
      if node == nil then
        return nil, "unknown base auxiliary entry: " .. tostring(example["入口"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[node]
      if actual == false then
        return nil, "expected " .. node .. " not hidden by input lock"
      end
      return true
    end,

    ["基础屏<入口>未被输入锁禁用"] = function(world, example)
      local node = _auxiliary_entry_node(example["入口"])
      if node == nil then
        return nil, "unknown base auxiliary entry: " .. tostring(example["入口"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.touch and state.ui.touch[node]
      if actual ~= true then
        return nil, "expected " .. node .. " explicitly enabled by input lock, got " .. tostring(actual)
      end
      return true
    end,

    ['基础屏托管按钮文字为"<按钮文字>"'] = function(world, example)
      local expected = tostring(example["按钮文字"] or "")
      local panel = world.base_screen_panel or {}
      local role_id = _role_id(world)
      local by_player = panel.auto_label_by_player or {}
      local actual = by_player[role_id] or panel.auto_label
      if actual ~= expected then
        return nil, "expected base auto label " .. expected .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏行动按钮已展示且可点击"] = function(world)
      local state = world.base_screen_render_state
      local visible = state and state.ui and state.ui.visibility and state.ui.visibility[base_nodes.action_button]
      local touch = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.action_button]
      if visible ~= true or touch ~= true then
        return nil, "expected action button visible and touchable, visible="
          .. tostring(visible) .. " touch=" .. tostring(touch)
      end
      return true
    end,

    ["基础屏结束按钮已隐藏"] = function(world)
      return _assert_end_button_hidden(world)
    end,

    ["基础屏结束按钮已展示且可点击"] = function(world)
      local state = world.base_screen_render_state
      local visible = state and state.ui and state.ui.visibility and state.ui.visibility[base_nodes.end_button]
      local touch = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.end_button]
      if visible ~= true or touch ~= true then
        return nil, "expected end button visible and touchable, visible="
          .. tostring(visible) .. " touch=" .. tostring(touch)
      end
      return true
    end,

    ['基础屏结束按钮文字为"结束"'] = function(world)
      local state = world.base_screen_render_state
      local ui = state and state.ui or {}
      local actual = ui.buttons and ui.buttons[base_nodes.end_button]
        or ui.labels and ui.labels[base_nodes.end_button]
      if actual ~= "结束" then
        return nil, "expected end button label 结束, got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏结束按钮不额外写入文字"] = function(world)
      local state = world.base_screen_render_state
      local ui = state and state.ui or {}
      local button_text = ui.buttons and ui.buttons[base_nodes.end_button]
      local label_text = ui.labels and ui.labels[base_nodes.end_button]
      if button_text ~= nil or label_text ~= nil then
        return nil, "expected end button to skip extra text, button="
          .. tostring(button_text) .. " label=" .. tostring(label_text)
      end
      return true
    end,

    ["基础屏行动按钮未作为可点击推进入口"] = function(world)
      local state = world.base_screen_render_state
      local touch = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.action_button]
      if touch == true then
        return nil, "action button should not be touchable during optional action"
      end
      local intent = _build_base_intent(world, base_nodes.action_button)
      if intent ~= nil then
        return nil, "action button should not build progression intent during optional action"
      end
      return true
    end,

    ["<可选行动>仍可作为主动选择入口"] = function(world, example)
      local expected = tostring(example["可选行动"] or "")
      local choice = world.base_screen_ui_model and world.base_screen_ui_model.choice or nil
      local actual = choice and choice.meta and choice.meta.optional_action or nil
      if actual ~= expected then
        return nil, "expected optional action entry " .. expected .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["触发基础屏行动按钮"] = function(world)
      _trigger_action_button(world)
      return true
    end,

    ["玩家进入必经回合流程"] = function(world)
      if world.base_screen_required_flow_started ~= true then
        return nil, "action button did not enter required flow"
      end
      return true
    end,

    ["触发基础屏结束按钮"] = function(world)
      _trigger_end_button(world)
      return true
    end,

    ["玩家完成可选行动阶段"] = function(world)
      if world.base_screen_optional_completed ~= true then
        return nil, "optional phase was not completed"
      end
      return true
    end,

    ["当前待处理选择已按完成语义清除"] = function(world)
      if world.base_screen_pending_choice_cleared ~= true then
        return nil, "pending choice was not cleared by completion"
      end
      return true
    end,

    ["没有打开二次确认弹窗"] = function(world)
      local screen = world.base_screen_render_state
        and world.base_screen_render_state.ui
        and world.base_screen_render_state.ui.active_choice_screen_key
      if screen == "secondary_confirm" or world.base_screen_secondary_confirm_open == true then
        return nil, "secondary confirm should not open"
      end
      return true
    end,

    ["未派发通用结束动作"] = function(world)
      local intent = world.base_screen_end_button_intent or world.base_screen_action_button_intent
      if intent and intent.type == "ui_button" and (intent.id == "end" or intent.id == "end_turn") then
        return nil, "generic end action was dispatched"
      end
      return true
    end,

    ["回合继续到<后续流程>"] = function(world, example)
      local expected = tostring(example["后续流程"] or "")
      local actual = world.base_screen_followup_flow
      if expected == "必经流程" then
        if actual == nil then
          return nil, "expected any required follow-up flow"
        end
        return true
      end
      if actual ~= expected then
        return nil, "expected follow-up flow " .. expected .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["后续必经流程未被跳过"] = function(world)
      if world.base_screen_followup_flow == nil then
        return nil, "follow-up required flow was skipped"
      end
      return true
    end,

    ["可选行动阶段超时"] = function(world)
      if world.base_screen_render_state == nil then
        _refresh_base_screen_for_player(world)
      end
      local choice = world.base_screen_ui_model and world.base_screen_ui_model.choice or nil
      local intent = choice_auto_policy.decide({}, {}, choice, { mode = "tick_timeout" })
      world.base_screen_timeout_intent = intent
      if intent and intent.type == "choice_cancel" then
        _mark_optional_completed(world, intent)
      end
      return true
    end,

    ["未触发基础屏行动按钮"] = function(world)
      if world.base_screen_action_button_triggered == true then
        return nil, "action button should not have been triggered"
      end
      return true
    end,

    ["基础屏结束按钮不可派发完成可选行动阶段"] = function(world)
      local ok, err = _assert_end_button_not_touchable(world)
      if not ok then
        return nil, err
      end
      if world.base_screen_input_blocked == true or (world.base_screen_ui_model and world.base_screen_ui_model.choice) == nil then
        local intent = _build_base_intent(world, base_nodes.end_button)
        if intent ~= nil then
          return nil, "end button built an intent while blocked or without optional choice"
        end
      end
      return true
    end,

    ["基础屏只展示被动当前回合提示"] = function(world)
      local state = world.base_screen_render_state
      local action_touch = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.action_button]
      if action_touch == true then
        return nil, "passive view should not expose action touch"
      end
      local ok, err = _assert_end_button_hidden(world)
      if not ok then
        return nil, err
      end
      return true
    end,

    ["可选行动阶段不会停在空选择入口"] = function(world)
      local choice = world.base_screen_ui_model and world.base_screen_ui_model.choice or nil
      if choice ~= nil then
        return nil, "empty optional phase should not create a choice"
      end
      return true
    end,

    ["基础屏皮肤<节点>已隐藏"] = function(world, example)
      local node = SKIN_ENTRY_NODES[tostring(example["节点"] or "")]
      if node == nil then
        return nil, "unknown skin entry node: " .. tostring(example["节点"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[node]
      if actual ~= false then
        return nil, "expected " .. node .. " hidden, got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏皮肤<节点>已展示"] = function(world, example)
      local node = SKIN_ENTRY_NODES[tostring(example["节点"] or "")]
      if node == nil then
        return nil, "unknown skin entry node: " .. tostring(example["节点"])
      end
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[node]
      if actual ~= true then
        return nil, "expected " .. node .. " visible, got " .. tostring(actual)
      end
      return true
    end,
  }
end

return base_screen_steps
