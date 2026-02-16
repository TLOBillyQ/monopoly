local panel_view = require("visual.widget.panel")

local panel = {}

function panel.build_auto_label_by_player(players, enabled_by_player)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = panel_view.build_auto_label(enabled_by_player and enabled_by_player[player_id] == true)
    end
  end
  return out
end

function panel.build(game, env, turn, current_player_id, auto_enabled_by_player)
  local auto_label_by_player = panel.build_auto_label_by_player(game.players, auto_enabled_by_player)
  return {
    turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0,
      turn.countdown_active == true
    ),
    player_rows = panel_view.build_player_statuses(game, env.game, 4),
    auto_label_by_player = auto_label_by_player,
    auto_label = auto_label_by_player[current_player_id] or panel_view.build_auto_label(false),
    no_action_visible = turn.detained_wait_active == true,
    no_action_text = "本回合无法行动",
  }
end

function panel.update(panel_obj, game, env, turn, current_player_id, auto_enabled_by_player, flags)
  panel_obj = panel_obj or {}
  flags = flags or {}
  if flags.turn_label then
    panel_obj.turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0,
      turn.countdown_active == true
    )
  end
  if flags.player_rows then
    panel_obj.player_rows = panel_view.build_player_statuses(game, env.game, 4)
  end
  if flags.auto_label then
    panel_obj.auto_label_by_player = panel.build_auto_label_by_player(game.players, auto_enabled_by_player)
    panel_obj.auto_label = panel_obj.auto_label_by_player[current_player_id] or panel_view.build_auto_label(false)
  end
  if flags.turn_label or flags.turn then
    panel_obj.no_action_visible = turn.detained_wait_active == true
    panel_obj.no_action_text = "本回合无法行动"
  end
  return panel_obj
end

return panel
