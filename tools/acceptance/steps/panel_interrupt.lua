local number_utils = require("src.foundation.number")
local item_atlas = require("src.ui.coord.item_atlas")
local skin_panel = require("src.ui.coord.skin_panel")
local event_log_view = require("src.ui.coord.event_log_view")
local panel_interrupt = require("src.ui.coord.panel_interrupt")
local view_command = require("src.ui.input.view_command")
local base_intents = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")
local tips = require("src.foundation.tips")

local panel_interrupt_steps = {}

local PANEL_OPENERS = {
  ["道具图鉴"] = function(state, role_id) item_atlas.open(state, role_id) end,
  ["皮肤商店"] = function(state, role_id) skin_panel.open(state, role_id) end,
  ["行动日志"] = function(state, role_id) event_log_view.open(state, role_id) end,
}

local PANEL_CLOSERS = {
  ["道具图鉴"] = function(state, role_id) item_atlas.close(state, role_id) end,
  ["皮肤商店"] = function(state, role_id) skin_panel.close(state, role_id) end,
  ["行动日志"] = function(state, role_id) event_log_view.close(state, role_id) end,
}

local PANEL_IS_OPEN = {
  ["道具图鉴"] = function(state)
    return state.ui.item_atlas ~= nil and state.ui.item_atlas.open == true
  end,
  ["皮肤商店"] = function(state)
    return state.ui.skin_panel ~= nil and state.ui.skin_panel.open == true
  end,
  ["行动日志"] = function(state, role_id) return event_log_view.is_open(state, role_id) end,
}

local INTENT_BY_PANEL = {
  ["道具图鉴"] = base_nodes.gallery_button,
  ["皮肤商店"] = base_nodes.skin_button,
  ["行动日志"] = base_nodes.action_log_button,
}

local SETTLEMENT_FLAGS = {
  ["黑市"] = "market_active",
  ["机会"] = "choice_active",
  ["弹窗"] = "popup_active",
  ["移动"] = "move_active",
}

local function _no_op() end

local function _other_role_id(role_id)
  local id = number_utils.to_integer(role_id) or 1
  if id == 1 then
    return 2
  end
  return 1
end

local function _ensure_state(world)
  if world.pi_state then
    return world.pi_state
  end
  tips.clear()
  world.pi_tips = {}
  tips.configure_runtime({
    presenter = function(text, duration, tip)
      world.pi_tips[#world.pi_tips + 1] = tip or { text = text, duration = duration }
    end,
    scheduler = function() return true end,
    test_mode = false,
  })
  item_atlas.reset_for_tests()
  skin_panel.reset_for_tests()
  local state = {
    ui = {
      market_active = false,
      choice_active = false,
      popup_active = false,
      move_active = false,
      debug_visible_by_role = {},
      debug_log_enabled_by_role = {},
      set_visible = _no_op,
      set_label = _no_op,
      set_button = _no_op,
      set_touch_enabled = _no_op,
      set_event_log = _no_op,
      set_event_log_visible = _no_op,
    },
    ui_refs = { images = {} },
  }
  world.pi_state = state
  return state
end

local function _role_id(world)
  return number_utils.to_integer(world.ui_role_id) or 1
end

local function _panel_name(example)
  return tostring(example["面板"] or "")
end

local function _settlement_name(example)
  return tostring(example["结算"] or example.p3 or "")
end

local function _settlement_flag(example)
  local name = _settlement_name(example)
  local flag = SETTLEMENT_FLAGS[name]
  if flag == nil then
    return nil, "unknown settlement type: " .. name
  end
  return flag
end

local function _assert_panel(example)
  local name = _panel_name(example)
  if PANEL_OPENERS[name] == nil then
    return nil, "unknown panel: " .. name
  end
  return name
end

local function _begin_player_action(state, role_id)
  tips.clear()
  if type(panel_interrupt.begin_player_action) == "function" then
    panel_interrupt.begin_player_action(state, role_id)
    return
  end
  state.ui.current_action_role_id = role_id
end

local function _assert_tip_shown(world, expected)
  if world.pi_tips == nil then
    return nil, "no tip queue capture; ensure scenario opens panel_interrupt state first"
  end
  for _, tip in ipairs(world.pi_tips) do
    if tip.text == expected then
      return true
    end
  end
  return nil, "expected tip missing: " .. expected
end

local function _start_settlement(state, settlement, role_id)
  local flag = SETTLEMENT_FLAGS[settlement]
  if flag == nil then
    return nil, "unknown settlement type: " .. tostring(settlement)
  end
  state.ui.current_action_role_id = role_id
  if flag == "move_active" then
    panel_interrupt.begin_move(state)
  else
    state.ui[flag] = true
    panel_interrupt.interrupt(state)
  end
  return true
end

local function _show_market_screen(state, role_id)
  state.ui.current_action_role_id = role_id
  state.ui.market_active = true
  panel_interrupt.interrupt(state)
end

function panel_interrupt_steps.handlers()
  return {
    ["玩家打开<面板>"] = function(world, example)
      local name, err = _assert_panel(example)
      if name == nil then return nil, err end
      local state = _ensure_state(world)
      PANEL_OPENERS[name](state, _role_id(world))
      return true
    end,

    ["玩家关闭<面板>"] = function(world, example)
      local name, err = _assert_panel(example)
      if name == nil then return nil, err end
      local state = _ensure_state(world)
      PANEL_CLOSERS[name](state, _role_id(world))
      return true
    end,

    ["玩家在回合外打开<面板>"] = function(world, example)
      local name, err = _assert_panel(example)
      if name == nil then return nil, err end
      local state = _ensure_state(world)
      state.ui.current_action_role_id = _other_role_id(_role_id(world))
      PANEL_OPENERS[name](state, _role_id(world))
      return true
    end,

    ["<面板>屏幕已开启"] = function(world, example)
      local name, err = _assert_panel(example)
      if name == nil then return nil, err end
      local state = _ensure_state(world)
      if not PANEL_IS_OPEN[name](state, _role_id(world)) then
        return nil, name .. " 屏幕未开启"
      end
      return true
    end,

    ["<面板>屏幕已关闭"] = function(world, example)
      local name, err = _assert_panel(example)
      if name == nil then return nil, err end
      local state = _ensure_state(world)
      if PANEL_IS_OPEN[name](state, _role_id(world)) then
        return nil, name .. " 屏幕仍在开启"
      end
      return true
    end,

    ["<结算>结算开始"] = function(world, example)
      local flag, err = _settlement_flag(example)
      if flag == nil then return nil, err end
      local state = _ensure_state(world)
      if flag == "move_active" then
        panel_interrupt.begin_move(state)
      else
        state.ui[flag] = true
        panel_interrupt.interrupt(state)
      end
      return true
    end,

    ["玩家自己的<结算>结算开始"] = function(world, example)
      local state = _ensure_state(world)
      return _start_settlement(state, _settlement_name(example), _role_id(world))
    end,

    ["玩家自己的黑市屏打开"] = function(world)
      local state = _ensure_state(world)
      _show_market_screen(state, _role_id(world))
      return true
    end,

    ["其他玩家的黑市屏打开"] = function(world)
      local state = _ensure_state(world)
      _show_market_screen(state, _other_role_id(_role_id(world)))
      return true
    end,

    ["玩家自己的黑市屏正在显示"] = function(world)
      local state = _ensure_state(world)
      state.ui.current_action_role_id = _role_id(world)
      state.ui.market_active = true
      return true
    end,

    ["其他玩家的黑市屏正在显示"] = function(world)
      local state = _ensure_state(world)
      state.ui.current_action_role_id = _other_role_id(_role_id(world))
      state.ui.market_active = true
      return true
    end,

    ["<结算>结算正在进行"] = function(world, example)
      local flag, err = _settlement_flag(example)
      if flag == nil then return nil, err end
      local state = _ensure_state(world)
      state.ui[flag] = true
      return true
    end,

    ["<结算>结算结束"] = function(world, example)
      local flag, err = _settlement_flag(example)
      if flag == nil then return nil, err end
      local state = _ensure_state(world)
      if flag == "move_active" then
        panel_interrupt.end_move(state)
      else
        state.ui[flag] = false
      end
      return true
    end,

    ["轮到玩家行动"] = function(world)
      local state = _ensure_state(world)
      _begin_player_action(state, _role_id(world))
      return true
    end,

    ["轮到其他玩家行动"] = function(world)
      local state = _ensure_state(world)
      _begin_player_action(state, _other_role_id(_role_id(world)))
      return true
    end,

    ["触发基础屏<面板>按钮"] = function(world, example)
      local name, err = _assert_panel(example)
      if name == nil then return nil, err end
      local state = _ensure_state(world)
      local target_node = INTENT_BY_PANEL[name]
      for _, spec in ipairs(base_intents.build(state)) do
        if spec.name == target_node then
          local intent = spec.build_intent()
          intent.actor_role_id = _role_id(world)
          view_command.dispatch(state, intent)
          return true
        end
      end
      return nil, "base canvas 未注册入口路由: " .. tostring(target_node)
    end,

    ['提示"<提示文本>"已显示'] = function(world, example)
      return _assert_tip_shown(world, tostring(example["提示文本"] or ""))
    end,

    ['提示"<面板>"已显示'] = function(world, example)
      return _assert_tip_shown(world, tostring(example["面板"] or ""))
    end,

    ['提示"轮到你行动了"已显示'] = function(world)
      return _assert_tip_shown(world, "轮到你行动了")
    end,
  }
end

return panel_interrupt_steps
