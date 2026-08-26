-- 自动托管按钮分享界面域绑定（#v103 auto_button_share）。
-- 触发步骤走真实派发路径：背景「游戏已初始化标准棋盘」建好 driver 真实对局，
-- 本步骤经 turn_dispatch.dispatch_action 派发 { type = "ui_button", id = "auto" }，
-- 只桩住进程级 runtime_ports.resolve_role 以捕获宿主的 show_map_share_panel 调用
-- （rng_next_int 端口按 new_game 的口径保留，避免毒化同进程后续场景）。
-- Then 断言全部落在真实 player 字段与桩捕获结果上——src 语义漂移时验收会红，
-- 不再有「步骤内复刻被测逻辑」的第二份实现。
--
-- 复用前提：Given「玩家托管状态为开启」复用 unusable_card_tip 域绑定，写死
-- players[1] 的控制状态；本域其余步骤按 find_player_by_id(行动角色ID) 定位玩家。
-- 两者仅在 行动角色ID == players[1].id 时指向同一玩家——本 feature 的例子表
-- 必须保持该等式成立（当前为 1），扩例子到非 1 角色前需先改 unusable_card_tip
-- 的绑定口径。
local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local control = require("src.player.control")

local function _game(w)
  return w.driver and w.driver.game or nil
end

-- 与 base_screen 的 _rid/_action_rid 同口径：world 键可能被字符串参数步骤
-- 写入，一律先 to_integer 归一，否则 role_id 比较（number vs string）恒不等、
-- resolve_role 桩静默落空。
local function _action_role_id(w)
  return number_utils.to_integer(w.bs_action_role_id)
    or number_utils.to_integer(w.ui_role_id)
    or 1
end

local function _player(w)
  local game = _game(w)
  if game == nil then return nil end
  return game:find_player_by_id(_action_role_id(w))
end

return dsl.steps({
  -- 托管状态 Given（"玩家托管状态为开启" 由 unusable_card_tip.lua 提供，
  -- 同样写真实玩家控制状态；本域只补"关闭"字面量）
  ["玩家托管状态为关闭"] = function(w)
    local player = _player(w)
    if player == nil then return nil, "缺少行动玩家（背景应先初始化标准棋盘）" end
    if control.is_delegated(player) then
      control.toggle_manual_delegation(player)
    end
    return true
  end,

  ["该玩家从未弹出过分享界面"] = function(w)
    local player = _player(w)
    if player == nil then return nil, "缺少行动玩家（背景应先初始化标准棋盘）" end
    player.auto_share_panel_shown = false
    return true
  end,

  ["该玩家分享界面已弹出过"] = function(w)
    local player = _player(w)
    if player == nil then return nil, "缺少行动玩家（背景应先初始化标准棋盘）" end
    player.auto_share_panel_shown = true
    return true
  end,

  ["触发基础屏托管按钮"] = function(w)
    local game = _game(w)
    if game == nil then return nil, "缺少真实对局（背景应先初始化标准棋盘）" end
    local rid = _action_role_id(w)
    if game:find_player_by_id(rid) == nil then
      return nil, "role 无对局玩家: " .. tostring(rid)
    end
    -- 真实派发路径：handlers.handle_auto_toggle 内部经 runtime_ports.resolve_role
    -- 找宿主 Role 并调 show_map_share_panel；此处桩 resolve_role 捕获该调用。
    w.abs_share_calls = {}
    runtime_ports.configure({
      rng_next_int = function(min, max)
        return game.rng:next_int(min, max)
      end,
      resolve_role = function(role_id)
        if role_id ~= rid then return nil end
        return {
          show_map_share_panel = function()
            w.abs_share_calls[#w.abs_share_calls + 1] = role_id
          end,
        }
      end,
    })
    w.abs_dispatch_result = turn_dispatch.dispatch_action(game, {}, {
      type = "ui_button",
      id = "auto",
      actor_role_id = rid,
      input_source = "touch",
    }, nil)
    return true
  end,

  ["玩家托管状态变为开启"] = function(w)
    local player = _player(w)
    if player == nil then return nil, "缺少行动玩家" end
    return dsl.eq(control.is_delegated(player), true, "托管状态变为开启（dispatch: "
      .. tostring(w.abs_dispatch_result and w.abs_dispatch_result.status) .. "）")
  end,

  ["玩家托管状态变为关闭"] = function(w)
    local player = _player(w)
    if player == nil then return nil, "缺少行动玩家" end
    return dsl.eq(control.is_delegated(player), false, "托管状态变为关闭（dispatch: "
      .. tostring(w.abs_dispatch_result and w.abs_dispatch_result.status) .. "）")
  end,

  ["地图分享界面已弹出"] = function(w)
    local calls = w.abs_share_calls
    if calls == nil then return nil, "触发步骤未执行" end
    return dsl.eq(#calls > 0, true, "地图分享界面已弹出")
  end,

  ["地图分享界面未弹出"] = function(w)
    local calls = w.abs_share_calls
    if calls == nil then return nil, "触发步骤未执行" end
    return dsl.eq(#calls, 0, "地图分享界面未弹出")
  end,
}, { name = "auto_button_share" })
