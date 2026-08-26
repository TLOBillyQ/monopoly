local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local item_atlas = require("src.ui.screens.item_atlas")
local skin_panel = require("src.ui.screens.skin_panel")
local event_log_view = require("src.ui.coord.event_log_view")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local view_command = require("src.ui.input.view_command")
local base_intents = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")
local presentation_ports = require("src.ui.ports")
local tips = require("src.foundation.tips")

-- 基础屏面板打断域绑定：服务 panel_interrupt（回合打断句面被 skin_shop.feature 复用）。
-- 三面板经各自 screen 模块公开面开合，结算打断走 src.ui.state.panel_interrupt；提示经
-- foundation tips presenter 捕获到 world.pi_tips（unusable_card_tip 域的字面提示断言同样读它）。

local PANELS = {
  ["道具图鉴"] = { open = function(s, rid) item_atlas.open(s, rid) end, node = base_nodes.gallery_button,
    is_open = function(s) return s.ui.item_atlas ~= nil and s.ui.item_atlas.open == true end },
  ["皮肤商店"] = { open = function(s, rid) skin_panel.open(s, rid) end, node = base_nodes.skin_button,
    is_open = function(s) return s.ui.skin_panel ~= nil and s.ui.skin_panel.open == true end },
  ["行动日志"] = { open = function(s, rid) event_log_view.open(s, rid) end, node = base_nodes.action_log_button,
    is_open = function(s, rid) return event_log_view.is_open(s, rid) end },
}
local SETTLEMENT_FLAGS = { ["黑市"] = "market_active", ["机会"] = "choice_active", ["弹窗"] = "popup_active", ["移动"] = "move_active" }

local function _no_op() end
local function _rid(w) return number_utils.to_integer(w.ui_role_id) or 1 end
local function _other(w) return _rid(w) == 1 and 2 or 1 end

local function _ensure_state(w)
  if w.pi_state then return w.pi_state end
  tips.clear()
  w.pi_tips = {}
  tips.configure_runtime({
    presenter = function(text, duration, tip) w.pi_tips[#w.pi_tips + 1] = tip or { text = text, duration = duration } end,
    scheduler = function() return true end, test_mode = false,
  })
  item_atlas.reset_for_tests()
  skin_panel.reset_for_tests()
  w.pi_state = {
    ui = { market_active = false, choice_active = false, popup_active = false, move_active = false,
      debug_visible_by_role = {}, debug_log_enabled_by_role = {},
      set_visible = _no_op, set_label = _no_op, set_button = _no_op, set_touch_enabled = _no_op,
      set_event_log = _no_op, set_event_log_visible = _no_op },
    runtime_asset_context = { refs = { images = {} } },
    gameplay_loop_ports = presentation_ports.build(),
  }
  return w.pi_state
end

local function _panel(a)
  local name = tostring(a["面板"] or "")
  local panel = PANELS[name]
  if panel == nil then return nil, nil, "unknown panel: " .. name end
  return panel, name
end

-- 打开面板句面工厂：open_role 决定当下行动角色（回合外打开时指到别人）。
local function _open_step(offturn)
  return function(w, a)
    local panel, _, err = _panel(a)
    if panel == nil then return nil, err end
    local state = _ensure_state(w)
    if offturn then state.ui.current_action_role_id = _other(w) end
    panel.open(state, _rid(w))
    return true
  end
end

local function _open_assert_step(expect_open)
  return function(w, a)
    local panel, name, err = _panel(a)
    if panel == nil then return nil, err end
    return dsl.eq(panel.is_open(_ensure_state(w), _rid(w)) == true, expect_open, name .. " 屏幕开启态")
  end
end

local function _show_market(w, role_id, interrupt_now)
  local state = _ensure_state(w)
  state.ui.current_action_role_id, state.ui.market_active = role_id, true
  if interrupt_now then panel_interrupt.interrupt(state) end
  return true
end

local function _begin_action(w, role_id)
  local state = _ensure_state(w)
  tips.clear()
  panel_interrupt.begin_player_action(state, role_id)
  return true
end

local function _assert_tip(w, expected)
  if w.pi_tips == nil then return nil, "no tip queue capture; ensure scenario opens panel_interrupt state first" end
  for _, tip in ipairs(w.pi_tips) do
    if tip.text == expected then return true end
  end
  return nil, "expected tip missing: " .. tostring(expected)
end

return dsl.steps({
  ["玩家打开<面板>"] = _open_step(false),
  ["玩家在回合外打开<面板>"] = _open_step(true),
  ["<面板>屏幕已开启"] = _open_assert_step(true),
  ["<面板>屏幕已关闭"] = _open_assert_step(false),
  ["玩家自己的<结算>结算开始"] = function(w, a)
    local flag = SETTLEMENT_FLAGS[tostring(a["结算"] or "")]
    if flag == nil then return nil, "unknown settlement type: " .. tostring(a["结算"]) end
    local state = _ensure_state(w)
    state.ui.current_action_role_id = _rid(w)
    if flag == "move_active" then panel_interrupt.begin_move(state)
    else state.ui[flag] = true panel_interrupt.interrupt(state) end
    return true
  end,
  ["玩家自己的黑市屏打开"] = function(w) return _show_market(w, _rid(w), true) end,
  ["其他玩家的黑市屏打开"] = function(w) return _show_market(w, _other(w), true) end,
  ["玩家自己的黑市屏正在显示"] = function(w) return _show_market(w, _rid(w), false) end,
  ["其他玩家的黑市屏正在显示"] = function(w) return _show_market(w, _other(w), false) end,
  ["轮到玩家行动"] = function(w) return _begin_action(w, _rid(w)) end,
  ["轮到其他玩家行动"] = function(w) return _begin_action(w, _other(w)) end,
  ["触发基础屏<面板>按钮"] = function(w, a)
    local panel, _, err = _panel(a)
    if panel == nil then return nil, err end
    local state = _ensure_state(w)
    for _, spec in ipairs(base_intents.build(state)) do
      if spec.name == panel.node then
        local intent = spec.build_intent()
        intent.actor_role_id = _rid(w)
        view_command.dispatch(state, intent)
        return true
      end
    end
    return nil, "base canvas 未注册入口路由: " .. tostring(panel.node)
  end,
  ['提示"<提示文本>"已显示'] = function(w, a) return _assert_tip(w, tostring(a["提示文本"] or "")) end,
  ['提示"轮到你行动了"已显示'] = function(w) return _assert_tip(w, "轮到你行动了") end,
}, { name = "panel_interrupt" })
