-- 分享按钮域绑定（v104 share_button）。
-- 触发步骤走真实路由+派发路径：base_intents.build 取分享按钮 route 产
-- { type = "open_share_panel" } intent，经 src.ui.input.view_command.dispatch
-- 到真实 ports 层 handler，handler 调 runtime_ports.emit_event 发全局自定义
-- 事件「打开分享任务」（#458 真机实证通路，编辑器侧同名监听打开分享任务
-- 面板）；只桩进程级 runtime_ports.emit_event 以捕获/操纵宿主事件发送
-- （rng_next_int 端口按 new_game 的口径保留，避免毒化同进程后续场景）。
-- Then 断言全部落在桩捕获与 dispatch 受理结果上——src 语义漂移时验收会红，
-- 不再有「步骤内复刻被测逻辑」的第二份实现。
local dsl = require("packages.acceptance.step_dsl")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local view_command = require("src.ui.input.view_command")
local base_intents = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")
local ui_mock = require("packages.acceptance.support.ui_mock")

-- 与 view_command 的 SHARE_TASK_OPEN_EVENT 同一真源：事件名以编辑器配置为准，
-- 这里重复字面量是有意的——src 侧漂移时验收变红。
local EXPECTED_EVENT = "打开分享任务"

local function _game(w)
  return w.driver and w.driver.game or nil
end

local function _ensure_state(w)
  if not w.share_btn_state then
    local state = ui_mock.build_render_state({ with_buttons = true })
    w.share_btn_state = state
  end
  return w.share_btn_state
end

-- 桩 emit_event：emit_impl 捕获/操纵宿主事件发送（返回 false 表示通道失败）。
-- rng 端口保留 driver game 口径（与 game_driver.new_game 的注释同理）。
local function _stub_emit_event(w, emit_impl)
  local game = _game(w)
  if game == nil then return nil, "缺少真实对局（背景应先初始化标准棋盘）" end
  runtime_ports.configure({
    rng_next_int = function(min, max)
      return game.rng:next_int(min, max)
    end,
    emit_event = emit_impl,
  })
  return true
end

return dsl.steps({
  ["分享按钮事件发送已桩获"] = function(w)
    return _stub_emit_event(w, function(event_name, payload)
      w.share_btn_calls[#w.share_btn_calls + 1] = { event_name = event_name, payload = payload }
      return true
    end)
  end,

  ["分享按钮事件通道将失败"] = function(w)
    return _stub_emit_event(w, function()
      return false
    end)
  end,

  ["触发基础屏分享按钮"] = function(w)
    local state = _ensure_state(w)
    -- 每次点击重置捕获：Then 的「已/未发送」只针对本次点击。
    w.share_btn_calls = {}
    for _, spec in ipairs(base_intents.build(state)) do
      if spec.name == base_nodes.share_button then
        local intent = spec.build_intent()
        w.share_btn_accepted = view_command.dispatch(state, intent)
        return true
      end
    end
    return nil, "canvas 未注册路由: " .. tostring(base_nodes.share_button)
  end,

  ["分享按钮已发送打开分享任务事件"] = function(w)
    local calls = w.share_btn_calls
    if calls == nil then return nil, "触发步骤未执行" end
    if #calls == 0 then return nil, "分享按钮已发送打开分享任务事件" end
    return dsl.eq(calls[#calls].event_name, EXPECTED_EVENT, "分享按钮已发送打开分享任务事件")
  end,

  ["分享按钮未发送打开分享任务事件"] = function(w)
    local calls = w.share_btn_calls
    if calls == nil then return nil, "触发步骤未执行" end
    return dsl.eq(#calls, 0, "分享按钮未发送打开分享任务事件")
  end,

  ["分享按钮点击已被受理"] = function(w)
    return dsl.eq(w.share_btn_accepted, true, "分享按钮点击已被受理")
  end,
}, { name = "share_button" })
