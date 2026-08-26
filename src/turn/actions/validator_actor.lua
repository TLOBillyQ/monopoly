local logger = require("src.foundation.log")
local role_id_utils = require("src.foundation.identity")

local validator_actor = {}

-- 只有 next 是回合绑定的 ui_button。道具槽点击已不是 ui_button——它的行动者是
-- 「点击者」而非「当前回合玩家」,拿这条规则去卡它会把他人回合的点击静默拒掉。
local function _is_turn_bound_ui_button(action_id)
  return action_id == "next"
end

local function _current_turn_player(game)
  local current_index = game.turn.current_player_index
  return current_index and game.players and game.players[current_index] or nil
end

local function _resolve_current_turn_role_id(game)
  local current_player = _current_turn_player(game)
  return role_id_utils.normalize(current_player and current_player.id or nil)
end

local function _validate_actor_matches_current(action, actor_role_id, current_role_id)
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action.id))
    return false
  end
  if current_role_id == nil then
    logger.warn("ui_button missing current_role_id:", tostring(action.id))
    return false
  end
  if not role_id_utils.equals(actor_role_id, current_role_id) then
    logger.warn(
      "ui_button blocked by actor check:",
      tostring(action.id),
      "actor_role_id=" .. tostring(actor_role_id),
      "current_role_id=" .. tostring(current_role_id)
    )
    return false
  end
  return true
end

function validator_actor.validate_actor_role(game, action)
  if not _is_turn_bound_ui_button(action and action.id) then
    return true
  end
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local current_role_id = _resolve_current_turn_role_id(game)
  local actor_role_id = role_id_utils.normalize(action.actor_role_id)
  return _validate_actor_matches_current(action, actor_role_id, current_role_id)
end

return validator_actor

--[[ mutate4lua-manifest
version=4
projectHash=733ebcc9dbe4e24b
scope.0.id=chunk:src/turn/actions/validator_actor.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=54
scope.0.semanticHash=ae654a50405317ea
scope.1.id=function:_is_turn_bound_ui_button
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=df7a871d489ab136
scope.2.id=function:_current_turn_player
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=15
scope.2.semanticHash=34a4ab2ade92c639
scope.3.id=function:_resolve_current_turn_role_id
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=20
scope.3.semanticHash=de9a31a38aa6519d
scope.4.id=function:_validate_actor_matches_current
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=41
scope.4.semanticHash=98b001d1f3e3eef6
scope.5.id=function:validator_actor.validate_actor_role
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=51
scope.5.semanticHash=ae95b2c041925fc4
]]
