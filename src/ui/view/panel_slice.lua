local panel_view = require("src.ui.view.panel_builder")
local role_id_utils = require("src.foundation.identity")

local panel_slice = {}

local function _resolve_no_action_notice(turn)
  if not turn then
    return false, "本回合无法行动"
  end
  local visible = turn.no_action_notice_active == true or turn.detained_wait_active == true
  local text = turn.no_action_notice_text or "本回合无法行动"
  return visible, text
end

local _auto_labels = {}

local function _build_auto_label_by_player(players, enabled_by_player)
  for k in pairs(_auto_labels) do
    _auto_labels[k] = nil
  end
  for _, player in ipairs(players or {}) do
    local player_id = role_id_utils.normalize(player and player.id or nil)
    if player_id then
      local enabled = role_id_utils.read(enabled_by_player, player_id) == true
      role_id_utils.write(_auto_labels, player_id, panel_view.build_auto_label(enabled))
    end
  end
  return _auto_labels
end

local function _resolve_countdown_visible(turn)
  return turn and turn.countdown_active == true or false
end

function panel_slice.build(game, env, turn, current_player_id, auto_enabled_by_player)
  local auto_label_by_player = _build_auto_label_by_player(game.players, auto_enabled_by_player)
  local normalized_current_player_id = role_id_utils.normalize(current_player_id)
  local no_action_visible, no_action_text = _resolve_no_action_notice(turn)
  return {
    turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0
    ),
    player_rows = panel_view.build_player_statuses(game, env.game, 4),
    auto_label_by_player = auto_label_by_player,
    auto_label = role_id_utils.read(auto_label_by_player, normalized_current_player_id) or panel_view.build_auto_label(false),
    countdown_visible = _resolve_countdown_visible(turn),
    no_action_visible = no_action_visible,
    no_action_text = no_action_text,
  }
end

local function _update_turn_label(panel, turn)
  panel.turn_label = panel_view.build_turn_label(
    turn.turn_count,
    turn.countdown_seconds or 0
  )
  panel.countdown_visible = _resolve_countdown_visible(turn)
end

local function _update_player_rows(panel, game, env)
  panel.player_rows = panel_view.build_player_statuses(game, env.game, 4)
end

local function _update_auto_labels(panel, game, current_player_id, auto_enabled_by_player)
  local normalized_current_player_id = role_id_utils.normalize(current_player_id)
  panel.auto_label_by_player = _build_auto_label_by_player(game.players, auto_enabled_by_player)
  panel.auto_label = role_id_utils.read(panel.auto_label_by_player, normalized_current_player_id)
    or panel_view.build_auto_label(false)
end

local function _update_no_action_notice(panel, turn)
  local no_action_visible, no_action_text = _resolve_no_action_notice(turn)
  panel.no_action_visible = no_action_visible
  panel.no_action_text = no_action_text
end

function panel_slice.update(panel, game, env, turn, current_player_id, auto_enabled_by_player, flags)
  panel = panel or {}
  flags = flags or {}
  if flags.turn_label then
    _update_turn_label(panel, turn)
  end
  if flags.player_rows then
    _update_player_rows(panel, game, env)
  end
  if flags.auto_label then
    _update_auto_labels(panel, game, current_player_id, auto_enabled_by_player)
  end
  if flags.turn_label then
    _update_no_action_notice(panel, turn)
  end
  return panel
end

return panel_slice

--[[ mutate4lua-manifest
version=2
projectHash=07740847a1bccd73
scope.0.id=chunk:src/ui/view/panel_slice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=97
scope.0.semanticHash=85b7c6d719311744
scope.1.id=function:_resolve_no_action_notice:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=3b67ad8263e75526
scope.2.id=function:_resolve_countdown_visible:31
scope.2.kind=function
scope.2.startLine=31
scope.2.endLine=33
scope.2.semanticHash=608e2ce58a4378eb
scope.3.id=function:panel_slice.build:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=51
scope.3.semanticHash=6bc7a5615dbb7716
scope.4.id=function:_update_turn_label:53
scope.4.kind=function
scope.4.startLine=53
scope.4.endLine=59
scope.4.semanticHash=3fe44ab0e9ce3e54
scope.5.id=function:_update_player_rows:61
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=63
scope.5.semanticHash=155f5822f6b6cc6f
scope.6.id=function:_update_auto_labels:65
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=70
scope.6.semanticHash=5d5b32c85d52c73d
scope.7.id=function:_update_no_action_notice:72
scope.7.kind=function
scope.7.startLine=72
scope.7.endLine=76
scope.7.semanticHash=81560091caf569d2
scope.8.id=function:panel_slice.update:78
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=94
scope.8.semanticHash=b79ecef708b06e8b
]]
