-- Acceptance suite registry: the canonical feature -> generated-spec mapping.
--
-- This is the source of truth for *which* features compose the `busted --run
-- acceptance` suite and what each one's generated spec is named. Before ADR
-- 0015 this set was implicit in the committed files under
-- `tools/acceptance/generated/`; those are now gitignored and regenerated from
-- the features at the acceptance entrypoint (see tools/acceptance/regenerate.lua
-- and the `make acceptance` target).
--
-- Naming is intentionally explicit rather than derived: most specs are
-- `<feature_basename>_acceptance_spec.lua`, but `chinese_gherkin_acceptance.feature`
-- maps to `chinese_gherkin_acceptance_spec.lua`, so a naive transform would drift.
-- Add a row here when a feature should join the acceptance suite.

local GENERATED_DIR = "tools/acceptance/generated"

local entries = {
  { feature = "features/game/bankruptcy.feature",                  generated = "bankruptcy_acceptance_spec.lua" },
  { feature = "features/game/chance.feature",                      generated = "chance_acceptance_spec.lua" },
  { feature = "features/game/deities.feature",                     generated = "deities_acceptance_spec.lua" },
  { feature = "features/game/dice.feature",                        generated = "dice_acceptance_spec.lua" },
  { feature = "features/game/dice_roll.feature",                   generated = "dice_roll_acceptance_spec.lua" },
  { feature = "features/game/economy.feature",                     generated = "economy_acceptance_spec.lua" },
  { feature = "features/game/endgame.feature",                     generated = "endgame_acceptance_spec.lua" },
  { feature = "features/game/items.feature",                       generated = "items_acceptance_spec.lua" },
  { feature = "features/game/market.feature",                      generated = "market_acceptance_spec.lua" },
  { feature = "features/game/movement.feature",                    generated = "movement_acceptance_spec.lua" },
  { feature = "features/game/paid_currency.feature",               generated = "paid_currency_acceptance_spec.lua" },
  { feature = "features/game/setup.feature",                       generated = "setup_acceptance_spec.lua" },
  { feature = "features/game/turn_flow.feature",                   generated = "turn_flow_acceptance_spec.lua" },
  { feature = "features/swarmforge/acceptance_mutator_status.feature", generated = "acceptance_mutator_status_acceptance_spec.lua" },
  { feature = "features/swarmforge/chinese_gherkin_acceptance.feature", generated = "chinese_gherkin_acceptance_spec.lua" },
  { feature = "features/swarmforge/upstream_terminal_backend.feature", generated = "upstream_terminal_backend_acceptance_spec.lua" },
  { feature = "features/swarmforge/upstream_topology.feature", generated = "upstream_topology_acceptance_spec.lua" },
  { feature = "features/v102/achievements.feature",                  generated = "achievements_acceptance_spec.lua" },
  { feature = "features/v102/achievement_progress.feature",           generated = "achievement_progress_acceptance_spec.lua" },
  { feature = "features/v102/base_screen.feature",                 generated = "base_screen_acceptance_spec.lua" },
  { feature = "features/v102/item_atlas.feature",                  generated = "item_atlas_acceptance_spec.lua" },
  { feature = "features/v102/leaderboard.feature",                 generated = "leaderboard_acceptance_spec.lua" },
  { feature = "features/v102/market_cash.feature",                 generated = "market_cash_acceptance_spec.lua" },
  { feature = "features/v102/optional_action_end_button.feature",   generated = "optional_action_end_button_acceptance_spec.lua" },
  { feature = "features/v102/panel_interrupt.feature",             generated = "panel_interrupt_acceptance_spec.lua" },
  { feature = "features/v102/share_task.feature",                  generated = "share_task_acceptance_spec.lua" },
  { feature = "features/v102/sign_in.feature",                     generated = "sign_in_acceptance_spec.lua" },
  { feature = "features/v102/skin_persistence.feature",            generated = "skin_persistence_acceptance_spec.lua" },
  { feature = "features/v102/skin_shop.feature",                   generated = "skin_shop_acceptance_spec.lua" },
}

return {
  generated_dir = GENERATED_DIR,
  entries = entries,
}
