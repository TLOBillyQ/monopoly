local number_utils = require("src.foundation.number")
local panel_slice = require("src.ui.view.panel_slice")
local panel_presenter = require("src.ui.render.widgets.presenter")
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
  state.ui.visibility = {}
  state.ui.touch = {}
  state.ui.input_blocked = world and world.base_screen_input_blocked == true or false
  state.ui.set_label = function(self, name, text)
    self.labels[name] = text
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
  local item_slots_by_player = {
    [_role_id(world)] = {},
  }
  if action_role_id ~= nil then
    item_slots_by_player[action_role_id] = {}
  end
  return {
    current_player_id = action_role_id,
    auto_enabled_by_player = auto_enabled_by_player,
    board = { players = game.players },
    item_slots_by_player = item_slots_by_player,
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
  panel_presenter.refresh(world.base_screen_render_state, world.base_screen_ui_model, {
    runtime = _make_runtime(_role_id(world)),
    refresh_item_slots = function() end,
  })
  return world.base_screen_render_state
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

    ["当前轮到角色ID为<行动角色ID>"] = function(world, example)
      local role_id = number_utils.to_integer(example["行动角色ID"])
      if not _valid_role_id(role_id) then
        return nil, "invalid action role_id: " .. tostring(example["行动角色ID"])
      end
      world.base_screen_action_role_id = role_id
      world.base_screen_action_role_unset = false
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

    ["基础屏为该玩家刷新"] = function(world)
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
