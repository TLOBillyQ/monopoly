local panel_view = require("src.presentation.widgets.UIPanel")
local role_id_utils = require("src.core.utils.RoleId")

local panel_slice = {}

local function _resolve_no_action_notice(turn)
  if not turn then
    return false, "本回合无法行动"
  end
  local visible = turn.no_action_notice_active == true or turn.detained_wait_active == true
  local text = turn.no_action_notice_text or "本回合无法行动"
  return visible, text
end

local function _build_auto_label_by_player(players, enabled_by_player)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = role_id_utils.normalize(player and player.id or nil)
    if player_id then
      local enabled = role_id_utils.read(enabled_by_player, player_id) == true
      role_id_utils.write(out, player_id, panel_view.build_auto_label(enabled))
    end
  end
  return out
end

function panel_slice.build(game, env, turn, current_player_id, auto_enabled_by_player)
  local auto_label_by_player = _build_auto_label_by_player(game.players, auto_enabled_by_player)
  local normalized_current_player_id = role_id_utils.normalize(current_player_id)
  local no_action_visible, no_action_text = _resolve_no_action_notice(turn)
  return {
    turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0,
      turn.countdown_active == true
    ),
    player_rows = panel_view.build_player_statuses(game, env.game, 4),
    auto_label_by_player = auto_label_by_player,
    auto_label = role_id_utils.read(auto_label_by_player, normalized_current_player_id) or panel_view.build_auto_label(false),
    no_action_visible = no_action_visible,
    no_action_text = no_action_text,
  }
end

function panel_slice.update(panel, game, env, turn, current_player_id, auto_enabled_by_player, flags)
  local normalized_current_player_id = role_id_utils.normalize(current_player_id)
  panel = panel or {}
  flags = flags or {}
  if flags.turn_label then
    panel.turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0,
      turn.countdown_active == true
    )
  end
  if flags.player_rows then
    panel.player_rows = panel_view.build_player_statuses(game, env.game, 4)
  end
  if flags.auto_label then
    panel.auto_label_by_player = _build_auto_label_by_player(game.players, auto_enabled_by_player)
    panel.auto_label = role_id_utils.read(panel.auto_label_by_player, normalized_current_player_id)
      or panel_view.build_auto_label(false)
  end
  if flags.turn_label then
    local no_action_visible, no_action_text = _resolve_no_action_notice(turn)
    panel.no_action_visible = no_action_visible
    panel.no_action_text = no_action_text
  end
  return panel
end

return panel_slice
