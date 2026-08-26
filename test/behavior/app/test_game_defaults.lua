local lu = require("luaunit")
local game_defaults = require("src.app.game_defaults")

TestGameDefaults = {}

function TestGameDefaults:test_identifies_class_like_tables()
  lu.assertFalse(game_defaults.is_class_like(nil))
  lu.assertFalse(game_defaults.is_class_like(42))
  lu.assertFalse(game_defaults.is_class_like("string"))
  lu.assertFalse(game_defaults.is_class_like({}))
  lu.assertFalse(game_defaults.is_class_like({ __name = "Foo" }))
  lu.assertTrue(game_defaults.is_class_like({
    __name = "MyClass",
    new = function() end,
  }))

  local instance = setmetatable({
    __name = "Instance",
    new = function() end,
  }, {
    __newindex = function() end,
  })
  lu.assertFalse(game_defaults.is_class_like(instance))
end

function TestGameDefaults:test_build_player_by_id_handles_missing_players_and_ids()
  lu.assertNil(next(game_defaults.build_player_by_id(nil)))
  local indexed = game_defaults.build_player_by_id({
    { id = 1, name = "A" },
    { name = "NoId" },
    { id = 2, name = "B" },
  })
  lu.assertEquals(indexed[1].name, "A")
  lu.assertEquals(indexed[2].name, "B")
  local count = 0
  for _ in pairs(indexed) do
    count = count + 1
  end
  lu.assertEquals(count, 2)
end

function TestGameDefaults:test_build_initial_turn_returns_expected_defaults()
  local turn = game_defaults.build_initial_turn()
  lu.assertEquals(turn.current_player_index, 1)
  lu.assertEquals(turn.turn_count, 0)
  lu.assertEquals(turn.phase, "start")
  lu.assertFalse(turn.countdown_active)
  lu.assertEquals(turn.countdown_seconds, 0)
  lu.assertNil(turn.pending_choice)
  lu.assertEquals(turn.choice_seq, 0)
  lu.assertEquals(turn.move_anim_seq, 0)
  lu.assertNil(turn.move_anim)
  lu.assertEquals(turn.action_anim_seq, 0)
  lu.assertNil(turn.action_anim)
  lu.assertEquals(turn.action_anim_queue, {})
  lu.assertFalse(turn.landing_visual_hold_active)
  lu.assertFalse(turn.landing_visual_release_pending)
  lu.assertFalse(turn.move_followup_pending)
  lu.assertFalse(turn.detained_wait_active)
  lu.assertEquals(turn.detained_wait_seconds, 0)
  lu.assertEquals(turn.detained_wait_elapsed, 0)
  lu.assertFalse(turn.inter_turn_wait_active)
  lu.assertEquals(turn.inter_turn_wait_seconds, 0)
  lu.assertEquals(turn.inter_turn_wait_elapsed, 0)
  lu.assertFalse(turn.no_action_notice_active)
  lu.assertNil(turn.no_action_notice_player_id)
  lu.assertNil(turn.no_action_notice_text)
  lu.assertEquals(turn.item_phase, {})
  lu.assertEquals(turn.used_effect_groups, {})
  lu.assertEquals(turn.item_phase_active, "")
  lu.assertNil(turn.market_prompt)
  lu.assertNil(turn.post_action)
end

function TestGameDefaults:test_init_tile_state_resets_only_land_tiles()
  local board = {
    path = {
      { type = "land", owner_id = 7, level = 3 },
      { type = "special", owner_id = 9, level = 2 },
    },
  }
  game_defaults.init_tile_state(board)
  lu.assertNil(board.path[1].owner_id)
  lu.assertEquals(board.path[1].level, 0)
  lu.assertEquals(board.path[2].owner_id, 9)
  lu.assertEquals(board.path[2].level, 2)
end

function TestGameDefaults:test_build_market_limits_filters_non_positive_and_missing_limits()
  local market_cfg = require("src.config.content.market")
  local saved = {}
  for index = 1, #market_cfg do
    saved[index] = market_cfg[index]
    market_cfg[index] = nil
  end
  market_cfg[1] = { product_id = "keep", limit = 1 }
  market_cfg[2] = { product_id = "zero", limit = 0 }
  market_cfg[3] = { product_id = "nil-limit" }

  local ok, limits = pcall(game_defaults.build_market_limits)
  for index = 1, #saved do
    market_cfg[index] = saved[index]
  end

  lu.assertTrue(ok, "market limits build must not raise")
  lu.assertEquals(limits.keep, 1)
  lu.assertNil(limits.zero)
  lu.assertNil(limits["nil-limit"])
end

return TestGameDefaults
