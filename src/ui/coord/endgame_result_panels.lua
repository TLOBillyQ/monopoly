-- 终局结算面板链(自 event_handlers.lua 拆分):game.finished 事件的胜/败者
-- 面板触发 + 整局收尾(end_game),宿主对象调用「跳过必留痕」(ADR 0046),禁止静默。
local runtime_ports = require("src.foundation.ports.runtime_ports")

local endgame_result_panels = {}
local context = { logger = nil, state = nil }

-- 胜/败结算面板的宿主方法名(#334 面板变体):集中文件头,grep 可达。
local _WINNER_PANEL_METHOD = "game_win_and_show_result_panel"
local _LOSER_PANEL_METHOD = "game_lose_and_show_result_panel"

-- 宿主对象调用「跳过必留痕」(ADR 0046):logger 缺位时(测试桩)静默可接受,
-- 生产路径 logger 恒在。
local function _warn(...)
  local logger = context.logger
  if logger and type(logger.warn) == "function" then
    logger.warn(...)
  end
end

-- 合成 AI 跳过按 info 留痕(ADR 0046「跳过必留痕」,但不是异常):每局 1~3 条
-- warn 会淹没真正的宿主异常留痕(#611)。必须走不限流通道:普通 info 受
-- debug_flags.info_log_per_turn_limit(生产为 1)每回合节流,终局所在回合的
-- 额度通常已被别处用掉,留痕会被整条丢弃 = 静默。
local function _info_unlimited(...)
  local logger = context.logger
  if logger and type(logger.info_unlimited) == "function" then
    logger.info_unlimited(...)
  end
end

local function _player_tag(player)
  return tostring(player and player.id or "?")
end

-- 终局结算面板走宿主「显示界面」方法(与 EggyAPI 注解对齐):胜利
-- game_win_and_show_result_panel / 失败 game_lose_and_show_result_panel(#334);
-- 方法缺失时跳过且留痕,不静默。pcall 隔离宿主异常:面板抛错若上抛会跳过
-- 整局收尾(end_game),会话悬挂不退出——异常必须吞成 warn(#609 审查收口)。
local function _show_panel(role, player, method_name)
  local method = role[method_name]
  if type(method) ~= "function" then
    _warn("endgame result panel skip: role", _player_tag(player), "lacks " .. method_name)
    return
  end
  local ok, err = pcall(method)
  if not ok then
    _warn("endgame result panel raised: role", _player_tag(player), method_name, err)
  end
end

-- resolve_role 经 port 触达宿主适配层,抛错与返回 nil 同判:各自吞成一条 warn
-- 并跳过该玩家面板,不阻塞其余玩家与 end_game 收尾——上抛会沿事件回调冒泡
-- 跳过收尾,会话悬挂不退出(#609 复审收口)。
local function _notify_player_result(player, is_winner)
  -- 合成 AI 没有客户端,结算面板本就无处显示:先于 resolve_role 静默跳过(#611)。
  -- 判定源取 runtime_ports.is_synthetic_player(由合成角色注册表按开局登记的
  -- player_id 回答),不取 resolve_role 返回的适配器上的 is_synthetic_actor:
  -- 合成 AI 淘汰时 die/lose 已把自己从注册表退役,终局 resolve_role 恒 nil,
  -- 适配器根本拿不到。也不取游戏层 player.is_ai——那是「补位电脑」席位身份
  -- (ADR 0061),既不等于宿主侧存在合成角色,ui 层也被 arch guard 禁止依赖
  -- src.player。本端口是注册表内的纯表查询,不触达宿主 API,故不需 pcall。
  -- 留痕文案与 warn 家族的 "endgame result panel skip:" 前缀刻意区分,按文本
  -- grep 日志也不会把本条静默跳过误当作宿主异常。
  if runtime_ports.is_synthetic_player(player.id) == true then
    _info_unlimited("endgame result panel synthetic skip: no client for player", _player_tag(player))
    return
  end
  local ok, role = pcall(runtime_ports.resolve_role, player.id)
  if not ok then
    _warn("endgame result panel skip: resolve_role raised for player", _player_tag(player), role)
    return
  end
  if role == nil then
    _warn("endgame result panel skip: role not resolved for player", _player_tag(player))
    return
  end
  if is_winner then
    _show_panel(role, player, _WINNER_PANEL_METHOD)
  else
    _show_panel(role, player, _LOSER_PANEL_METHOD)
  end
end

local function _game_players(game)
  local players = game and game.players or nil
  if type(players) ~= "table" then
    return nil
  end
  return players
end

local function _current_players()
  local state = context.state
  return _game_players(state and state.game or nil)
end

-- 终局总收尾(#609 复审更名,原名 _apply_game_result_panels 名不副实):先逐玩家
-- 路由胜/负面板,再无条件下发 end_game——职责是「面板 + 终局收尾」,不止面板。
local function _finalize_game_result(event_data)
  local players = _current_players()
  if players == nil then
    _warn("endgame result panel skip: no current players")
  else
    local winner_ids = event_data and event_data.winner_ids or {}
    for _, player in ipairs(players) do
      _notify_player_result(player, winner_ids[player.id] == true)
    end
  end
  -- 终局收尾:宿主要求「设置胜利或失败需要在结束之前」,故 end_game 放在全部
  -- 胜负标记(带面板)之后;面板链断裂不阻塞收尾,否则会话永久悬挂不退出。
  if runtime_ports.end_game() ~= true then
    _warn("endgame end_game not confirmed: session may stay open")
  end
end

function endgame_result_panels.set_context(logger, state)
  context.logger = logger
  context.state = state
end

function endgame_result_panels.install(register_handler, monopoly_event)
  register_handler(monopoly_event.game.finished, function(data)
    _finalize_game_result(data)
  end)
end

return endgame_result_panels

--[[ mutate4lua-manifest
version=4
projectHash=807c72dd7486f683
scope.0.id=chunk:src/ui/coord/endgame_result_panels.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=129
scope.0.semanticHash=def87abc9e36dacd
scope.1.id=function:_warn
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=38961a0b2c68bf4e
scope.2.id=function:_info_unlimited
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=30
scope.2.semanticHash=38961a0b2c68bf4e
scope.3.id=function:_player_tag
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=34
scope.3.semanticHash=7d072b025ad9bbab
scope.4.id=function:_show_panel
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=50
scope.4.semanticHash=752bcaaee9ede49d
scope.5.id=function:_notify_player_result
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=83
scope.5.semanticHash=cdad2315420236fc
scope.6.id=function:_game_players
scope.6.kind=function
scope.6.startLine=85
scope.6.endLine=91
scope.6.semanticHash=7ecf9f077756bf6c
scope.7.id=function:_current_players
scope.7.kind=function
scope.7.startLine=93
scope.7.endLine=96
scope.7.semanticHash=275c1bf841de2dc9
scope.8.id=function:_finalize_game_result
scope.8.kind=function
scope.8.startLine=100
scope.8.endLine=115
scope.8.semanticHash=82c1ef84988eb853
scope.9.id=function:endgame_result_panels.set_context
scope.9.kind=function
scope.9.startLine=117
scope.9.endLine=120
scope.9.semanticHash=10c5c24adc1f4b32
scope.10.id=function:endgame_result_panels.install
scope.10.kind=function
scope.10.startLine=122
scope.10.endLine=126
scope.10.semanticHash=c3c02a023052b3ea
scope.11.id=function:<anonymous>
scope.11.kind=function
scope.11.startLine=123
scope.11.endLine=125
scope.11.semanticHash=c772a22f8680e278
]]
