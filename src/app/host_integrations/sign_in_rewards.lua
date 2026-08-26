-- 签到奖励 UI 刷新接线(自 host_install.lua 拆分,>100 mutation sites 行为保持):
-- 宿主 RewardDay1..7 事件→金币发放→奖励 UI 脏刷新。game/app state 只存在
-- bootstrap 之后,由装配侧注入惰性访问器,事件触发时解析。
local sign_in = require("src.app.host_integrations.sign_in")
local host_runtime = require("src.host.init")
-- #332:身份解析走契约接缝(实现由装配侧 host_install 配置)。
local resolver_seam = require("src.ui.seams.local_actor_resolver")

local sign_in_rewards = {}

local function _loop_ports(state)
  return state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
end

local function _ui_sync_of(ports)
  return type(ports) == "table" and ports.ui_sync or nil
end

local function _refreshable(ui_sync)
  return type(ui_sync) == "table" and type(ui_sync.refresh_from_dirty) == "function"
end

local function _resolve_ui_sync_ports(state)
  local ui_sync = _ui_sync_of(_loop_ports(state))
  if not _refreshable(ui_sync) then
    return nil
  end
  return ui_sync
end

local function _refresh_sign_in_reward_ui(game, state)
  if game == nil or state == nil or type(game.consume_dirty) ~= "function" then
    return false
  end
  local ui_sync = _resolve_ui_sync_ports(state)
  if ui_sync == nil then
    return false
  end
  local dirty = game:consume_dirty()
  return ui_sync.refresh_from_dirty(game, state, dirty)
end

-- Subscribe the host's RewardDay1..7 sign-in events to coin grants. The game and
-- app state only exist after bootstrap, so app/init injects lazy accessors that
-- resolve at event-fire time; without them (e.g. context-only test installs) the
-- wiring is skipped. The claiming player is resolved from the event payload via
-- the shared local-actor resolver (payload.role, then client/local fallback).
function sign_in_rewards.install(opts)
  local get_current_game = opts.get_current_game
  local get_app_state = opts.get_app_state
  if type(get_current_game) ~= "function" or type(get_app_state) ~= "function" then
    return
  end
  sign_in.install({
    register_event = host_runtime.register_custom_event,
    get_game = get_current_game,
    resolve_role_id = function(data)
      return resolver_seam.resolve_from_event(get_app_state(), data)
    end,
    after_grant = function(game)
      return _refresh_sign_in_reward_ui(game, get_app_state())
    end,
  })
end

return sign_in_rewards

--[[ mutate4lua-manifest
version=4
projectHash=e180a83dbe8182da
scope.0.id=chunk:src/app/host_integrations/sign_in_rewards.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=67
scope.0.semanticHash=06a55c4ffa24412e
scope.1.id=function:_loop_ports
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=d692619e49063104
scope.2.id=function:_ui_sync_of
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=e22cfd8b0295d986
scope.3.id=function:_refreshable
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=21
scope.3.semanticHash=f44edaea74747a0d
scope.4.id=function:_resolve_ui_sync_ports
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=29
scope.4.semanticHash=079a59b9ef8c1cb8
scope.5.id=function:_refresh_sign_in_reward_ui
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=41
scope.5.semanticHash=a3c6da218e132665
scope.6.id=function:sign_in_rewards.install
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=64
scope.6.semanticHash=2fdde4d4cce5a643
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=57
scope.7.endLine=59
scope.7.semanticHash=81d0632fec657c19
scope.8.id=function:<anonymous>#2
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=62
scope.8.semanticHash=00ecaa76f3f25b69
]]
