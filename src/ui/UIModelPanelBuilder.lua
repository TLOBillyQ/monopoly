local panel_view = require("src.ui.UIPanel")

local panel_builder = {}

function panel_builder.build_auto_label_by_player(players, enabled_by_player)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = panel_view.build_auto_label(enabled_by_player and enabled_by_player[player_id] == true)
    end
  end
  return out
end

function panel_builder.build(game, env, turn, current_player_id, auto_enabled_by_player)
  local auto_label_by_player = panel_builder.build_auto_label_by_player(game.players, auto_enabled_by_player)
  return {
    turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0,
      turn.countdown_active == true
    ),
    player_rows = panel_view.build_player_statuses(game, env.game, 4),
    auto_label_by_player = auto_label_by_player,
    auto_label = auto_label_by_player[current_player_id] or panel_view.build_auto_label(false),
  }
end

function panel_builder.update(panel, game, env, turn, current_player_id, auto_enabled_by_player, flags)
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
    panel.auto_label_by_player = panel_builder.build_auto_label_by_player(game.players, auto_enabled_by_player)
    panel.auto_label = panel.auto_label_by_player[current_player_id] or panel_view.build_auto_label(false)
  end
  return panel
end

return panel_builder
