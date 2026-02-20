local gameplay_rules = {
  debug_log_enabled = true,
  debug_log_max_lines = 50,
  info_log_per_turn_limit = 1,
  vehicle_enabled = false,
  role_control_lock_enabled = true,

  auto_choice_min_visible_seconds = 3.0,
  auto_popup_min_visible_seconds = 3.0,
  popup_auto_close_seconds = 1.0,
  action_anim_default_seconds = 1.0,
  ai_auto_turn_interval_seconds = 0.4,
  -- 临时测试开关：开启后将非1号玩家视作AI，便于后续整体清理。
  test_force_non_p1_ai = true,
  -- 编辑器快速测试档位：default/ui_quick_all/ui_quick_choice/ui_quick_bankruptcy
  test_profile = "default",

  turn_limit = 1000,

  item_phase_queue = { "pre_action", "pre_move", "post_action" },

  reconnect = {
    freeze_on_disconnect = true,
    grace_seconds = 20,
    offline_auto_host_seconds = 90,
    snapshot_interval_events = 20,
    replay_max_events = 400,
  },

  item_ids = {
    free_rent = 2001,
    remote_dice = 2002,
    dice_multiplier = 2003,
    roadblock = 2004,
    mine = 2005,
    clear_obstacles = 2006,
    steal = 2007,
    monster = 2008,
    strong = 2009,
    tax_free = 2010,
    share_wealth = 2011,
    exile = 2012,
    missile = 2013,
    tax = 2014,
    invite_deity = 2015,
    send_poor = 2016,
    rich = 2017,
    poor = 2018,
    angel = 2019,
  },
}

return gameplay_rules
