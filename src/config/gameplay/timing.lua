local timing = {
  auto_decision_delay_seconds = 2.0,
  popup_auto_close_seconds = 2.0,
  action_anim_default_seconds = 2.0,
  event_tip_default_seconds = 2.0,
  event_tip_fast_seconds = 0.5,
  event_tip_fast_backlog_threshold = 2,
  detained_turn_wait_seconds = 2.0,
  inter_turn_wait_seconds = 1.0,
  panel_cash_delta_visible_seconds = 3.0,
  landing_visual_hold_seconds = 0.1,
  item_slot_highlight_anim_delay_seconds = 0.35,
  mine_trigger_snap_delay_seconds = 0.6,
  turn_limit = 1000,
  item_phase_queue = { "pre_action", "pre_move", "post_action" },
}

return timing
