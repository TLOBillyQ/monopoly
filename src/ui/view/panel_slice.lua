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

local function _clear(map)
  for k in pairs(map) do
    map[k] = nil
  end
end

local function _normalized_player_id(player)
  return role_id_utils.normalize(player and player.id or nil)
end

local function _build_auto_label_by_player(players, enabled_by_player)
  _clear(_auto_labels)
  for _, player in ipairs(players or {}) do
    local player_id = _normalized_player_id(player)
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

function panel_slice.build(game, env, turn, current_player_id, delegated_by_player)
  local auto_label_by_player = _build_auto_label_by_player(game.players, delegated_by_player)
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

local function _update_auto_labels(panel, game, current_player_id, delegated_by_player)
  local normalized_current_player_id = role_id_utils.normalize(current_player_id)
  panel.auto_label_by_player = _build_auto_label_by_player(game.players, delegated_by_player)
  panel.auto_label = role_id_utils.read(panel.auto_label_by_player, normalized_current_player_id)
    or panel_view.build_auto_label(false)
end

local function _update_no_action_notice(panel, turn)
  local no_action_visible, no_action_text = _resolve_no_action_notice(turn)
  panel.no_action_visible = no_action_visible
  panel.no_action_text = no_action_text
end

local function _update_flagged_rows(panel, game, env, current_player_id, delegated_by_player, flags)
  if flags.player_rows then
    _update_player_rows(panel, game, env)
  end
  if flags.auto_label then
    _update_auto_labels(panel, game, current_player_id, delegated_by_player)
  end
end

-- turn_label 这个 flag 同时驱动回合标签与「无法行动」提示两段更新，中间隔着
-- player_rows / auto_label，顺序按原样保留。
function panel_slice.update(panel, game, env, turn, current_player_id, delegated_by_player, flags)
  panel = panel or {}
  flags = flags or {}
  if flags.turn_label then
    _update_turn_label(panel, turn)
  end
  _update_flagged_rows(panel, game, env, current_player_id, delegated_by_player, flags)
  if flags.turn_label then
    _update_no_action_notice(panel, turn)
  end
  return panel
end

return panel_slice

--[[ mutate4lua-manifest
version=4
projectHash=0f1c8d400501fab3
scope.0.id=chunk:src/ui/view/panel_slice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=111
scope.0.semanticHash=f9ed08581c7335a8
scope.1.id=function:_resolve_no_action_notice
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=084cb139e74e7670
scope.2.id=function:_clear
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=21
scope.2.semanticHash=b6c04f8e080b736d
scope.3.id=function:_normalized_player_id
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=25
scope.3.semanticHash=6e8a930f39c3fdd1
scope.4.id=function:_build_auto_label_by_player
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=37
scope.4.semanticHash=4dc2b7b501917bed
scope.5.id=function:_resolve_countdown_visible
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=41
scope.5.semanticHash=c413fe61392c6aca
scope.6.id=function:panel_slice.build
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=59
scope.6.semanticHash=860d93c23ab5452b
scope.7.id=function:_update_turn_label
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=67
scope.7.semanticHash=3321917e600ba253
scope.8.id=function:_update_player_rows
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=71
scope.8.semanticHash=80ae3dfdb1de4e85
scope.9.id=function:_update_auto_labels
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=78
scope.9.semanticHash=28c73098169b06ed
scope.10.id=function:_update_no_action_notice
scope.10.kind=function
scope.10.startLine=80
scope.10.endLine=84
scope.10.semanticHash=27c5df66c95adc0f
scope.11.id=function:_update_flagged_rows
scope.11.kind=function
scope.11.startLine=86
scope.11.endLine=93
scope.11.semanticHash=303289f5721de4a1
scope.12.id=function:panel_slice.update
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=108
scope.12.semanticHash=34c58cc9e85fa087
]]
