-- 排行榜结算接线:游戏结束(gm.finished 经宿主自定义事件回环)→leaderboard.settle;
-- 另在开局时对每名真人玩家注册宿主「离开游戏」触发器,退出即标记 quit_reason,
-- settle 据此把中途退出者排除在富豪榜资产累计之外。
-- game 只存在于 bootstrap 之后,装配侧注入惰性访问器,事件触发时解析;
-- 缺 get_current_game(如 context-only 测试装配)时跳过接线。
local leaderboard = require("src.app.host_integrations.leaderboard")
local host_runtime = require("src.host.init")
local monopoly_event = require("src.foundation.events")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")

-- 宿主「指定玩家离开游戏」触发器事件(注册参数 Role)。真机取证(#585)已证:
-- 运行时 EVENT.SPEC_ROLE_EXIT_GAME 的值带 ET_ 前缀,带前缀注册成功并返回
-- trigger 句柄;EggyAPI 注解的裸名会被宿主拒(event is not supported),
-- 故以运行时值为准硬编码,值漂移时由注册失败 warn 留痕暴露。未取证项:
-- 回调 (event_name, actor, data) 形态与真人退出真实触发,多人局待验——
-- 宿主不给退出原因细分,统一记 "disconnect"(与 leaderboard.quit_reasons 口径一致)。
local ROLE_EXIT_EVENT = "ET_SPEC_ROLE_EXIT_GAME"

local leaderboard_settlement = {}

function leaderboard_settlement.install(opts)
  local get_current_game = opts and opts.get_current_game or nil
  if type(get_current_game) ~= "function" then
    return false
  end
  local registered = host_runtime.register_custom_event(monopoly_event.game.finished, function()
    leaderboard.settle(get_current_game())
  end)
  return registered == true
end

local function _mark_player_quit(player)
  if player.quit_reason ~= nil then
    return
  end
  player.quit_reason = "disconnect"
end

-- 跳过必留痕(ADR 0046):三类跳过共用 quit watch skip 前缀,reason 区分。
local function _skip_warn(reason, player_id)
  logger.warn("[leaderboard]", "quit watch skip: " .. reason .. " for player", tostring(player_id))
end

-- 退出触发语义未取证(#585):宿主若不按注册 role 过滤,任一玩家退出会触发
-- 全部回调。payload role 读出的 id 与本玩家不符时视为他人退出;读不出
-- (含未知 proxy 形态)时不排除,保守按本玩家退出标记。id 提取口径与
-- role_ports 的 _try_get_role_id 一致(get_roleid 优先,.id 兜底)。
local function _role_id_from_proxy(event_role)
  if type(event_role.get_roleid) == "function" then
    local ok, got = pcall(event_role.get_roleid)
    if ok and got ~= nil then
      return got
    end
  end
  return event_role.id
end

-- id 提取(CRAP 门禁):proxy / 标量两种形态的解析收敛到本函数,
-- _is_other_role_exit 只留「读不出即不排除」与比对。
local function _event_role_id(event_role)
  if type(event_role) == "table" then
    return _role_id_from_proxy(event_role)
  end
  if type(event_role) == "string" or number_utils.is_numeric(event_role) then
    return event_role
  end
  return nil
end

local function _is_other_role_exit(data, player_id)
  local event_role = data and data.role or nil
  if event_role == nil then
    return false
  end
  local role_id = _event_role_id(event_role)
  if role_id == nil then
    return false
  end
  return tostring(role_id) ~= tostring(player_id)
end

-- AI 玩家无宿主 role,不产生宿主退出事件;真人玩家 role 解析失败或注册
-- 失败时跳过且留痕(ADR 0046 跳过必留痕),不静默。
-- 注册两级失败判定(CRAP 门禁):端口不可用与宿主拒绝各自留痕,
-- _watch_player_quit 只留 AI/role 前置短路与注册调用。
local function _warn_register_failure(player_id, port_ok, trigger)
  if not port_ok then
    _skip_warn("global_register_trigger_event unavailable", player_id)
    return
  end
  -- 真机取证(#585):宿主拒绝注册时 SDK 包装层吞错、句柄返回 nil,
  -- 首返回值恒为 true,失败只认句柄(ADR 0046 成功按明确返回值判定)。
  if trigger == nil then
    _skip_warn("host rejected exit-event registration", player_id)
  end
end

local function _watch_player_quit(player)
  if player == nil or player.is_ai then
    return
  end
  local role = runtime_ports.resolve_role(player.id)
  if role == nil then
    _skip_warn("role not resolved", player.id)
    return
  end
  local port_ok, trigger = host_runtime.register_trigger_event({ ROLE_EXIT_EVENT, role }, function(_, _, data)
    if not _is_other_role_exit(data, player.id) then
      _mark_player_quit(player)
    end
  end)
  _warn_register_failure(player.id, port_ok, trigger)
end

-- 开局装配点调用:为这局每名真人玩家挂宿主退出监听,中途离开即标记
-- quit_reason,排行榜结算(settle)据此跳过其资产累计。
function leaderboard_settlement.watch_game(game)
  if game == nil or type(game.players) ~= "table" then
    return false
  end
  for _, player in ipairs(game.players) do
    _watch_player_quit(player)
  end
  return true
end

return leaderboard_settlement

--[[ mutate4lua-manifest
version=4
projectHash=9787ad6b85b3cfbb
scope.0.id=chunk:src/app/host_integrations/leaderboard_settlement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=130
scope.0.semanticHash=6b8488efed3186a0
scope.1.id=function:leaderboard_settlement.install
scope.1.kind=function
scope.1.startLine=23
scope.1.endLine=32
scope.1.semanticHash=a02727c0c566c0b4
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=30
scope.2.semanticHash=fb4e3bd40ff22274
scope.3.id=function:_mark_player_quit
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=39
scope.3.semanticHash=d42f3da780a8ae8a
scope.4.id=function:_skip_warn
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=44
scope.4.semanticHash=b732d4e2ecf04126
scope.5.id=function:_role_id_from_proxy
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=58
scope.5.semanticHash=d37ad65c00b290c9
scope.6.id=function:_event_role_id
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=70
scope.6.semanticHash=5bebb5604ff1baff
scope.7.id=function:_is_other_role_exit
scope.7.kind=function
scope.7.startLine=72
scope.7.endLine=82
scope.7.semanticHash=dc9e11c795fd65d9
scope.8.id=function:_warn_register_failure
scope.8.kind=function
scope.8.startLine=88
scope.8.endLine=98
scope.8.semanticHash=ce88682255a10f2d
scope.9.id=function:_watch_player_quit
scope.9.kind=function
scope.9.startLine=100
scope.9.endLine=115
scope.9.semanticHash=0859fe3456c1e782
scope.10.id=function:<anonymous>#2
scope.10.kind=function
scope.10.startLine=109
scope.10.endLine=113
scope.10.semanticHash=70c05080788d4ebe
scope.11.id=function:leaderboard_settlement.watch_game
scope.11.kind=function
scope.11.startLine=119
scope.11.endLine=127
scope.11.semanticHash=9cca6de5832070af
]]
