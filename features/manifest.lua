-- 验收套件注册表（消费仓数据面，测试极简化决策 / #193）：feature → 生成 spec 的
-- 权威映射，由验收引擎 tools/packages/acceptance/acceptance_features.lua 按
-- 约定加载。命名刻意显式而非派生：naive transform 会在个别历史命名上漂移。
-- 新 feature 要进验收套件就在这里加一行。

local entries = {
  { feature = "features/game/bankruptcy.feature",                  generated = "test_bankruptcy_acceptance.lua" },
  { feature = "features/game/chance.feature",                      generated = "test_chance_acceptance.lua" },
  { feature = "features/game/deities.feature",                     generated = "test_deities_acceptance.lua" },
  { feature = "features/game/dice.feature",                        generated = "test_dice_acceptance.lua" },
  { feature = "features/game/dice_roll.feature",                   generated = "test_dice_roll_acceptance.lua" },
  { feature = "features/game/economy.feature",                     generated = "test_economy_acceptance.lua" },
  { feature = "features/game/endgame.feature",                     generated = "test_endgame_acceptance.lua" },
  { feature = "features/game/item_slot_highlight_replay.feature", generated = "test_item_slot_highlight_replay_acceptance.lua" },
  { feature = "features/game/items.feature",                       generated = "test_items_acceptance.lua" },
  { feature = "features/game/main_turn_buttons.feature",           generated = "test_main_turn_buttons_acceptance.lua" },
  { feature = "features/game/market.feature",                      generated = "test_market_acceptance.lua" },
  { feature = "features/game/movement.feature",                    generated = "test_movement_acceptance.lua" },
  { feature = "features/game/paid_currency.feature",               generated = "test_paid_currency_acceptance.lua" },
  { feature = "features/game/setup.feature",                       generated = "test_setup_acceptance.lua" },
  { feature = "features/game/turn_flow.feature",                   generated = "test_turn_flow_acceptance.lua" },
  { feature = "features/swarmforge/acceptance_mutator_status.feature", generated = "test_acceptance_mutator_status_acceptance.lua" },
  { feature = "features/swarmforge/chinese_gherkin_acceptance.feature", generated = "test_chinese_gherkin_acceptance.lua" },
  { feature = "features/swarmforge/swarm_launch.feature",              generated = "test_swarm_launch_acceptance.lua" },
  { feature = "features/v102/achievement_progress.feature",        generated = "test_achievement_progress_acceptance.lua" },
  { feature = "features/v102/action_log_toggle.feature",           generated = "test_action_log_toggle_acceptance.lua" },
  { feature = "features/v102/base_screen.feature",                 generated = "test_base_screen_acceptance.lua" },
  { feature = "features/v102/item_atlas.feature",                  generated = "test_item_atlas_acceptance.lua" },
  { feature = "features/v102/leaderboard.feature",                 generated = "test_leaderboard_acceptance.lua" },
  { feature = "features/v102/market_cash.feature",                 generated = "test_market_cash_acceptance.lua" },
  { feature = "features/v102/panel_interrupt.feature",             generated = "test_panel_interrupt_acceptance.lua" },
  { feature = "features/v102/role_attribute_coins.feature",        generated = "test_role_attribute_coins_acceptance.lua" },
  { feature = "features/v102/share_task.feature",                  generated = "test_share_task_acceptance.lua" },
  { feature = "features/v102/sign_in.feature",                     generated = "test_sign_in_acceptance.lua" },
  { feature = "features/v102/skin_persistence.feature",            generated = "test_skin_persistence_acceptance.lua" },
  { feature = "features/v102/skin_shop.feature",                   generated = "test_skin_shop_acceptance.lua" },
  { feature = "features/v103/auto_button_share.feature",           generated = "test_auto_button_share_acceptance.lua" },
  { feature = "features/v103/card_reveal_broadcast.feature",       generated = "test_card_reveal_broadcast_acceptance.lua" },
  { feature = "features/v103/unusable_card_tip.feature",           generated = "test_unusable_card_tip_acceptance.lua" },
  { feature = "features/v104/share_button.feature",                generated = "test_share_button_acceptance.lua" },
  { feature = "features/v104/like_collect_subscribe.feature",      generated = "test_like_collect_subscribe_acceptance.lua" },
}

return { entries = entries }
