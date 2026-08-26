-- Tooling-lane tests for the turn-loop acceptance facade. They assert the driver
-- drives the REAL turn machine (src/turn/*) over game_driver's shared ctx, not a
-- parallel fixture: rotation, elimination-skip, detention and end-of-turn temporal
-- reset must all flow through real src code.
--
-- 原生 LuaUnit 迁移:9 个顶层 describe 均无 before_each/after_each 钩子,全部拍平进
-- 单一 TestTurnDriver(不拆子类);describe 内的共享 local(STANDARD、_RENT_TILE_ID、
-- _seat_for_rent 等,两处定义相同者合并)上提为文件级 local;自定义
-- _assert_eq(actual, expected, msg) 转 lu.assertIs(actual, expected, msg),语句位裸
-- assert(cond, msg) 转 lu.assertEvalToTrue;用例数与改写前一致
-- (4+3+2+1+4+5+4+2+4+4+1+1 = 35 例)。
local lu = require("luaunit")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")

local function _saw_event(ctx, kind)
  for _, event in ipairs(game_driver.events(ctx)) do
    if event.kind == kind then
      return true
    end
  end
  return false
end

local function _ctx()
  -- All-human roster so play_turn drives turns deterministically through dispatch.
  return game_driver.new_game({ players = { "P1", "P2", "P3", "P4" }, ai = {} })
end

local function _index_of(sequence, value)
  for index, observed in ipairs(sequence) do
    if observed == value then
      return index
    end
  end
  return nil
end

-- The standard turn milestones, in the order src/turn/* drives them:
-- 开始 → 等待行动 → 掷骰 → 移动 → 落地 → 结束.
local STANDARD = { "start", "wait_action", "roll", "move", "landing", "end_turn" }

-- A standard land tile on the outer ring (福州路); we re-price it and assign an
-- opponent owner, then land player 1 on it from its ring predecessor with a roll
-- of 1 — the real move+land path drives the rent-card settlement.
local _RENT_TILE_ID = 1

local function _seat_for_rent(ctx, opponent_owns)
  local p1 = ctx.game.players[1]
  if opponent_owns then
    game_driver.set_tile_owner(ctx, _RENT_TILE_ID, ctx.game.players[2].id)
    local tile = ctx.game.board:get_tile_by_id(_RENT_TILE_ID)
    tile.price = 1000
    tile.level = 0
  end
  game_driver.seat_before_tile(ctx, p1, _RENT_TILE_ID)
  game_driver.set_next_rolls(ctx, { 1 })
  return p1
end

local function _open_market_choice(ctx)
  local p1 = ctx.game.players[1]
  game_driver.set_market_sold_out(ctx)
  game_driver.seat_to_pass_through_market(ctx, p1)
  local choice = turn_driver.advance_to_choice(ctx)
  lu.assertEvalToTrue(choice ~= nil, "a market-purchase choice must be open")
  lu.assertIs(choice.kind, "market_buy", "a market-purchase choice is open")
  return p1
end

local function _open_rent_prompt(ctx)
  local p1 = ctx.game.players[1]
  game_driver.set_tile_owner(ctx, _RENT_TILE_ID, ctx.game.players[2].id)
  local tile = ctx.game.board:get_tile_by_id(_RENT_TILE_ID)
  tile.price = 1000
  tile.level = 0
  game_driver.give_item(ctx, p1, item_ids.strong)
  game_driver.seat_before_tile(ctx, p1, _RENT_TILE_ID)
  game_driver.set_next_rolls(ctx, { 1 })
  local choice = turn_driver.advance_to_choice(ctx)
  lu.assertEvalToTrue(choice ~= nil, "a rent-card prompt must be open")
  lu.assertIs(choice.kind, "rent_card_prompt", "a rent-card prompt is open")
  return p1
end

-- Player 2 is a computer player by default (new_game ai = {[2]=true,...}).
local function _ai(ctx)
  return ctx.game.players[2]
end

TestTurnDriver = {}

-- -------------------------------------------------- turn_driver reads over real ctx

function TestTurnDriver:test_reports_the_real_current_player_and_index()
  local ctx = _ctx()
  lu.assertIs(turn_driver.current_player_index(ctx), 1, "fresh game starts on player 1")
  lu.assertIs(turn_driver.current_player(ctx), ctx.game.players[1], "current_player reads real game state")
end

function TestTurnDriver:test_counts_participants_and_active_non_eliminated_participants()
  local ctx = _ctx()
  lu.assertIs(turn_driver.participant_count(ctx), 4, "four players seated")
  lu.assertIs(turn_driver.active_participant_count(ctx), 4, "all active before elimination")
  turn_driver.eliminate(ctx, ctx.game.players[2])
  lu.assertIs(turn_driver.active_participant_count(ctx), 3, "eliminating one drops the active count")
  lu.assertIs(turn_driver.is_eliminated(ctx, ctx.game.players[2]), true, "elimination reads back")
end

function TestTurnDriver:test_sets_the_current_player_as_a_seed()
  local ctx = _ctx()
  turn_driver.set_current_player(ctx, 3)
  lu.assertIs(turn_driver.current_player_index(ctx), 3, "seed sets whose turn it is")
  lu.assertIs(turn_driver.current_player(ctx), ctx.game.players[3], "current_player follows the seed")
end

function TestTurnDriver:test_resolves_a_seated_players_index_and_reports_nil_for_a_non_participant()
  local ctx = _ctx()
  lu.assertIs(turn_driver.player_index(ctx, ctx.game.players[3]), 3, "a seated player resolves to its seat index")
  lu.assertIs(turn_driver.player_index(ctx, ctx.game.players[1]), 1, "the first seat resolves to index 1")
  lu.assertIs(turn_driver.player_index(ctx, { id = "outsider" }), nil, "a player not in the roster resolves to nil")
end

-- -------------------------------------------------- rotation via the real machine

function TestTurnDriver:test_hands_off_to_the_next_player_when_a_turn_is_played()
  local ctx = _ctx()
  local next_player = turn_driver.play_turn(ctx)
  lu.assertIs(next_player, ctx.game.players[2], "after P1 plays, P2 is up")
  lu.assertIs(turn_driver.current_player_index(ctx), 2, "runtime index advanced to 2")
end

function TestTurnDriver:test_wraps_from_the_last_player_back_to_the_first()
  local ctx = _ctx()
  turn_driver.set_current_player(ctx, 4)
  local next_player = turn_driver.play_turn(ctx)
  lu.assertIs(next_player, ctx.game.players[1], "player 4's turn wraps to player 1")
end

function TestTurnDriver:test_skips_an_eliminated_player_on_handoff()
  local ctx = _ctx()
  turn_driver.eliminate(ctx, ctx.game.players[2])
  local next_player = turn_driver.play_turn(ctx)
  lu.assertIs(next_player, ctx.game.players[3], "eliminated P2 is skipped, P3 is up")
  lu.assertIs(turn_driver.current_player_index(ctx), 3, "runtime landed on player 3")
end

-- -------------------------------------------------- detention via the real machine

function TestTurnDriver:test_decrements_stay_turns_at_turn_start_and_skips_the_players_action()
  local ctx = _ctx()
  local detained = ctx.game.players[1]
  turn_driver.detain(ctx, detained, 2)
  local position_before = detained.position
  turn_driver.play_turn(ctx)
  lu.assertIs(turn_driver.stay_turns(ctx, detained), 1, "real start phase decrements stay_turns 2 -> 1")
  lu.assertIs(detained.position, position_before, "a detained player does not roll or move")
end

function TestTurnDriver:test_lets_the_player_act_normally_once_detention_expires()
  local ctx = _ctx()
  local player = ctx.game.players[1]
  turn_driver.detain(ctx, player, 1)
  turn_driver.play_turn(ctx)
  lu.assertIs(turn_driver.stay_turns(ctx, player), 0, "the single detained turn clears stay_turns")
  -- Play around the table back to player 1; their detention has expired now.
  local position_before = player.position
  turn_driver.play_turn(ctx) -- P2
  turn_driver.play_turn(ctx) -- P3
  turn_driver.play_turn(ctx) -- P4 hands back to P1
  lu.assertIs(turn_driver.current_player_index(ctx), 1, "rotation comes back to player 1")
  turn_driver.play_turn(ctx) -- P1 now acts normally
  lu.assertEvalToTrue(player.position ~= position_before, "after detention expires the player rolls and moves")
end

-- -------------------------------------------------- end-of-turn temporal reset via the real machine

function TestTurnDriver:test_clears_remote_dice_and_resets_the_dice_multiplier_when_the_turn_ends()
  local ctx = _ctx()
  local player = ctx.game.players[1]
  -- Seed temporal flags through game_driver (shared ctx); turn_driver observes
  -- that ending the turn runs the real clear_player_temporal_flags.
  game_driver.apply_remote_dice(ctx, player, 2, 6)
  game_driver.set_dice_multiplier(ctx, player, 3)
  lu.assertEvalToTrue(turn_driver.pending_remote_dice(ctx, player) ~= nil, "remote dice seeded")
  turn_driver.play_turn(ctx)
  lu.assertIs(turn_driver.pending_remote_dice(ctx, player), nil, "remote dice cleared at end of turn")
  lu.assertIs(turn_driver.dice_multiplier(ctx, player), 1, "dice multiplier reset to 1 at end of turn")
end

-- -------------------------------------------------- phase sequence via the real machine (cluster 2)

function TestTurnDriver:test_passes_through_the_standard_phases_in_order()
  local ctx = _ctx()
  local sequence = turn_driver.observe_turn_phases(ctx)
  -- Every standard milestone is observed, each strictly after the previous one,
  -- so the assertion pins the real phase ordering rather than mere presence.
  local previous = 0
  for _, phase in ipairs(STANDARD) do
    local at = _index_of(sequence, phase)
    lu.assertEvalToTrue(at ~= nil, "phase '" .. phase .. "' must appear in the turn sequence")
    lu.assertEvalToTrue(at > previous,
      "phase '" .. phase .. "' must come after the previous milestone, got index " .. tostring(at))
    previous = at
  end
end

function TestTurnDriver:test_reports_the_standard_milestone_order_holds_as_a_subsequence()
  local ctx = _ctx()
  local holds = turn_driver.turn_phase_order_holds(ctx, STANDARD)
  lu.assertIs(holds, true, "the real turn must satisfy the standard phase order")
end

function TestTurnDriver:test_rejects_an_impossible_phase_order_end_before_start()
  local ctx = _ctx()
  -- end_turn never precedes start within a turn, so the predicate must say no —
  -- proving it checks ordering, not just membership.
  local holds = turn_driver.turn_phase_order_holds(ctx, { "end_turn", "start", "roll" })
  lu.assertIs(holds, false, "a scrambled order must not hold against the real sequence")
end

function TestTurnDriver:test_skips_roll_and_move_for_a_detained_players_turn()
  local ctx = _ctx()
  -- A detained player's start phase ends the turn without rolling or moving, so
  -- the real phase sequence must omit roll/move while still starting and ending.
  turn_driver.detain(ctx, ctx.game.players[1], 1)
  local sequence = turn_driver.observe_turn_phases(ctx)
  lu.assertEvalToTrue(_index_of(sequence, "start") ~= nil, "a detained turn still runs the start phase")
  lu.assertEvalToTrue(_index_of(sequence, "roll") == nil, "a detained player must not reach the roll phase")
  lu.assertEvalToTrue(_index_of(sequence, "move") == nil, "a detained player must not reach the move phase")
end

-- ------------------------------------- landing-settlement card boundaries via the real machine (cluster 3)

function TestTurnDriver:test_auto_consumes_a_free_rent_card_on_an_opponent_tile_without_a_choice_or_rent()
  local ctx = _ctx()
  local p1 = _seat_for_rent(ctx, true)
  game_driver.give_item(ctx, p1, item_ids.free_rent)
  local cash_before = game_driver.player_cash(ctx, p1)
  local opponent_cash_before = game_driver.player_cash(ctx, ctx.game.players[2])

  local choice = turn_driver.advance_to_choice(ctx)
  lu.assertIs(choice, nil, "a lone free-rent card is auto-used — no manual choice is raised")
  lu.assertIs(game_driver.has_item(ctx, p1, item_ids.free_rent), false, "the free-rent card is consumed")
  lu.assertIs(game_driver.player_cash(ctx, p1), cash_before, "no rent is paid when免租 applies")
  lu.assertIs(game_driver.player_cash(ctx, ctx.game.players[2]), opponent_cash_before,
    "the owner receives no rent")
  lu.assertEvalToTrue(_saw_event(ctx, event_kinds.item_used), "the free-rent card use is published as an item-used event")
  lu.assertEvalToTrue(not _saw_event(ctx, event_kinds.rent_paid), "no rent-paid event is published")
end

TestTurnDriver["test_prompts_for_the_seizure_card_first_declining_auto_uses免租_and_skips_rent"] = function()
  local ctx = _ctx()
  local p1 = _seat_for_rent(ctx, true)
  game_driver.give_item(ctx, p1, item_ids.strong)
  game_driver.give_item(ctx, p1, item_ids.free_rent)
  local cash_before = game_driver.player_cash(ctx, p1)
  local opponent_cash_before = game_driver.player_cash(ctx, ctx.game.players[2])

  local choice = turn_driver.advance_to_choice(ctx)
  lu.assertEvalToTrue(choice ~= nil, "holding a seizure card raises a prompt before rent settles")
  lu.assertIs(choice.kind, "rent_card_prompt", "the prompt is the rent-card choice")
  lu.assertIs(choice.meta.card_kind, "strong", "the prompt offers the seizure (strong) card")

  turn_driver.resolve_choice(ctx, "skip")
  lu.assertIs(game_driver.has_item(ctx, p1, item_ids.strong), true,
    "declining the seizure keeps the strong card")
  lu.assertIs(game_driver.has_item(ctx, p1, item_ids.free_rent), false,
    "declining the seizure auto-consumes the free-rent card")
  lu.assertIs(game_driver.player_cash(ctx, p1), cash_before, "no rent is paid after the free-rent fallback")
  lu.assertIs(game_driver.player_cash(ctx, ctx.game.players[2]), opponent_cash_before,
    "the owner receives no rent")
end

function TestTurnDriver:test_seizes_the_tile_when_the_seizure_prompt_is_accepted()
  local ctx = _ctx()
  local p1 = _seat_for_rent(ctx, true)
  game_driver.give_item(ctx, p1, item_ids.strong)
  local cash_before = game_driver.player_cash(ctx, p1)

  local choice = turn_driver.advance_to_choice(ctx)
  lu.assertEvalToTrue(choice ~= nil, "the seizure prompt must be raised")
  lu.assertIs(choice.meta.card_kind, "strong", "the seizure prompt is raised")
  turn_driver.resolve_choice(ctx, "use")
  lu.assertIs(game_driver.has_item(ctx, p1, item_ids.strong), false, "accepting consumes the strong card")
  lu.assertIs(ctx.game.board:get_tile_by_id(_RENT_TILE_ID).owner_id, p1.id,
    "the tile ownership transfers to the seizer")
  lu.assertEvalToTrue(game_driver.player_cash(ctx, p1) < cash_before, "seizing pays the tile's total invested value")
end

-- The black market is off the outer ring; the player is routed onto the inner path
-- and onto the market tile through real movement (seat + even roll), and the sold-out
-- state is the real zeroed global limits — no fixture flag.
function TestTurnDriver:test_raises_no_purchase_choice_when_landing_on_a_sold_out_black_market()
  local ctx = _ctx()
  local p1 = ctx.game.players[1]
  game_driver.set_market_sold_out(ctx)
  local market_id = game_driver.seat_to_land_on_market(ctx, p1)

  local choice = turn_driver.advance_to_choice(ctx)
  lu.assertIs(choice, nil, "a sold-out market offers nothing to buy — no purchase choice is raised")
  lu.assertIs(ctx.game.board:get_tile(p1.position).id, market_id,
    "the player really moved onto the market tile via the inner path")
end

function TestTurnDriver:test_still_opens_the_market_when_passing_through_it_sold_out_the_visit_is_reached()
  -- Reverse-proof for the landing case: with the SAME sold-out state, passing
  -- through the market (interrupt path) still opens it, so the no-choice above is
  -- the landing settlement's sold-out gate — not a failure to reach the market.
  local ctx = _ctx()
  local p1 = ctx.game.players[1]
  game_driver.set_market_sold_out(ctx)
  game_driver.seat_to_pass_through_market(ctx, p1)

  local choice = turn_driver.advance_to_choice(ctx)
  lu.assertEvalToTrue(choice ~= nil, "passing through the market opens it even when sold out")
  lu.assertIs(choice.kind, "market_buy", "the opened choice is the black-market purchase prompt")
end

-- ------------------------------------- choice deadlines / timeouts via the real machine (cluster 4)

-- Raise a real market-purchase choice (sold-out so the timeout default of 不买 is a
-- pure no-op on cash), and a real rent-card prompt (a 普通 choice), then drive the
-- real DeadlineService + choice-timeout subsystem over the same ctx.
function TestTurnDriver:test_reads_each_choice_types_real_configured_deadline_market_60_and_normal_15()
  local ctx = _ctx()
  _open_market_choice(ctx)
  lu.assertIs(turn_driver.choice_timeout_seconds(ctx), 60, "market_buy uses the 60s scope timeout")
end

TestTurnDriver["test_reads_the_15s_deadline_for_a普通_choice"] = function()
  local ctx = _ctx()
  _open_rent_prompt(ctx)
  lu.assertIs(turn_driver.choice_timeout_seconds(ctx), 15, "a普通 choice uses the 15s scope timeout")
end

function TestTurnDriver:test_counts_the_deadline_down_through_warning_levels_without_pausing()
  -- Black-market browsing must NOT pause the action timer: as real time elapses the
  -- deadline crosses each warning threshold once (normal -> warn_5s -> warn_3s).
  local ctx = _ctx()
  _open_market_choice(ctx)
  turn_driver.arm_choice_deadline(ctx)
  lu.assertIs(turn_driver.choice_deadline_level(ctx), "normal", "a fresh deadline starts normal")

  turn_driver.elapse_choice_deadline(ctx, 54.0) -- remaining ~6
  lu.assertIs(turn_driver.choice_deadline_level(ctx), "normal", "still normal above the 5s threshold")
  turn_driver.elapse_choice_deadline(ctx, 1.0) -- remaining ~5
  lu.assertIs(turn_driver.choice_deadline_level(ctx), "warn_5s", "crossing 5s raises the warning level")
  turn_driver.elapse_choice_deadline(ctx, 2.0) -- remaining ~3
  lu.assertIs(turn_driver.choice_deadline_level(ctx), "warn_3s", "crossing 3s raises the urgent level")
end

TestTurnDriver["test_auto_resolves_a_sold_out_market_on_timeout_as_不买_no_cash_spent_choice_cleared"] = function()
  local ctx = _ctx()
  local p1 = _open_market_choice(ctx)
  local cash_before = game_driver.player_cash(ctx, p1)
  turn_driver.arm_choice_deadline(ctx)

  turn_driver.elapse_choice_deadline(ctx, 61.0) -- past the 60s market deadline
  lu.assertIs(game_driver.player_cash(ctx, p1), cash_before,
    "timing out the market is a gentle 不买 — no cash is deducted")
  lu.assertEvalToTrue(turn_driver.pending_choice(ctx) == nil
    or turn_driver.pending_choice(ctx).kind ~= "market_buy",
    "the timed-out market choice is cleared")
end

-- -------------------------------------------------- inter-turn wait via the real machine (cluster 4)

function TestTurnDriver:test_waits_the_inter_turn_interval_before_the_next_players_turn_starts()
  local ctx = _ctx()
  lu.assertEvalToTrue(turn_driver.advance_to_inter_turn_wait(ctx),
    "the turn opens an inter-turn wait at end of turn")
  lu.assertIs(turn_driver.current_player_index(ctx), 1, "the first player's turn has ended but not handed off")
  lu.assertEvalToTrue((turn_driver.inter_turn_wait_seconds(ctx) or 0) > 0, "a positive inter-turn interval is configured")

  turn_driver.elapse_inter_turn_wait(ctx, turn_driver.inter_turn_wait_seconds(ctx))
  lu.assertIs(turn_driver.current_player_index(ctx), 2,
    "elapsing the interval hands the turn to the next player")
end

function TestTurnDriver:test_holds_the_inter_turn_wait_until_a_blocking_prompt_finishes()
  local ctx = _ctx()
  turn_driver.reset_tips(ctx)
  turn_driver.advance_to_inter_turn_wait(ctx)
  turn_driver.hold_inter_turn_with_blocking_tip(ctx)

  turn_driver.elapse_inter_turn_wait(ctx, 5.0) -- well past the interval
  lu.assertIs(turn_driver.current_player_index(ctx), 1,
    "a blocking prompt holds the gate — the next player does not start")
  lu.assertEvalToTrue(turn_driver.inter_turn_wait_active(ctx), "the inter-turn wait stays active while blocked")

  turn_driver.reset_tips(ctx)
  turn_driver.elapse_inter_turn_wait(ctx, 5.0)
  lu.assertIs(turn_driver.current_player_index(ctx), 2,
    "once the blocking prompt clears, the wait completes and hands off")
end

-- -------------------------------------------------- AI item-use phase via the real strategy (cluster 5)

-- These drive src's real AI item-use strategy and assert its real priority/trigger
-- decisions — the driver reproduces none of turn_flow.lua's AI constant copies.
function TestTurnDriver:test_recognises_the_computer_player_through_the_real_auto_play_port()
  local ctx = _ctx() -- all human
  lu.assertIs(turn_driver.is_computer_controlled(ctx, ctx.game.players[1]), false, "a human player is not auto")
  local ai_ctx = game_driver.new_game() -- default AI on seats 2..4
  lu.assertIs(turn_driver.is_computer_controlled(ai_ctx, ai_ctx.game.players[2]), true, "seat 2 is a computer player")
end

function TestTurnDriver:test_uses_the_obstacle_clearing_card_only_when_the_real_trigger_finds_an_obstacle_ahead()
  local ctx = game_driver.new_game()
  local ai = _ai(ctx)
  ctx.game.turn.current_player_index = 2
  game_driver.give_item(ctx, ai, item_ids.clear_obstacles)
  game_driver.seat_with_obstacle_ahead(ctx, ai)

  turn_driver.run_ai_item_phase(ctx, ai, "pre_action")
  lu.assertIs(game_driver.has_item(ctx, ai, item_ids.clear_obstacles), false,
    "an obstacle ahead triggers the real clear-obstacles use")
end

function TestTurnDriver:test_keeps_the_obstacle_clearing_card_when_the_real_trigger_finds_no_obstacle()
  local ctx = game_driver.new_game()
  local ai = _ai(ctx)
  ctx.game.turn.current_player_index = 2
  game_driver.give_item(ctx, ai, item_ids.clear_obstacles)
  game_driver.seat_on_ring(ctx, ai) -- clear path

  turn_driver.run_ai_item_phase(ctx, ai, "pre_action")
  lu.assertIs(game_driver.has_item(ctx, ai, item_ids.clear_obstacles), true,
    "with no obstacle ahead the real trigger declines to use the card")
end

function TestTurnDriver:test_does_not_run_the_item_phase_for_a_human_player()
  local ctx = _ctx() -- all human
  local human = ctx.game.players[1]
  game_driver.give_item(ctx, human, item_ids.clear_obstacles)
  game_driver.seat_with_obstacle_ahead(ctx, human)

  lu.assertIs(turn_driver.run_ai_item_phase(ctx, human, "pre_action"), nil,
    "the AI item phase is a no-op for a human player")
  lu.assertIs(game_driver.has_item(ctx, human, item_ids.clear_obstacles), true,
    "the human keeps the card — only manual use applies")
end

-- -------------------------------------------------- AI landing settlement via the real seam (cluster 6)

-- 买地 / 升级 / 对手地免租 are decided at landing settlement, not the item phase: src's
-- land phase raises the real landing_optional_effect choice and choice_auto (the AI
-- actor decision entry) resolves it. These drive that real settlement + decision over
-- the shared ctx — no coroutine, no host stub, no decision-table copy.
function TestTurnDriver:test_auto_buys_an_unowned_affordable_land_it_lands_on()
  local ctx = game_driver.new_game()
  local ai = _ai(ctx)
  local idx = game_driver.first_land_tile(ctx)
  game_driver.set_player_position(ctx, ai, idx)
  local cash_before = game_driver.player_cash(ctx, ai)

  local choice = turn_driver.settle_landing(ctx, ai)
  lu.assertIs(choice and choice.kind, "landing_optional_effect",
    "an unowned land opens the real optional-buy choice")
  lu.assertIs(turn_driver.auto_resolve_landing_choice(ctx), "buy_land",
    "the real AI decision buys the land")
  lu.assertIs(game_driver.tile_owner(ctx, idx), ai.id, "the tile is now owned by the AI")
  lu.assertEvalToTrue(game_driver.player_cash(ctx, ai) < cash_before, "the purchase deducted cash")
end

function TestTurnDriver:test_auto_upgrades_its_own_land_it_lands_on()
  local ctx = game_driver.new_game()
  local ai = _ai(ctx)
  local idx, tile_id = game_driver.first_land_tile(ctx)
  game_driver.set_tile_owner(ctx, tile_id, ai.id)
  game_driver.set_player_position(ctx, ai, idx)
  local level_before = game_driver.tile_level(ctx, idx)
  local cash_before = game_driver.player_cash(ctx, ai)

  local choice = turn_driver.settle_landing(ctx, ai)
  lu.assertIs(choice and choice.kind, "landing_optional_effect",
    "own land opens the real optional-upgrade choice")
  lu.assertIs(turn_driver.auto_resolve_landing_choice(ctx), "upgrade_land",
    "the real AI decision upgrades the land")
  lu.assertEvalToTrue(game_driver.tile_level(ctx, idx) > level_before, "the upgrade raised the tile level")
  lu.assertEvalToTrue(game_driver.player_cash(ctx, ai) < cash_before, "the upgrade deducted cash")
end

TestTurnDriver["test_auto_uses_a_held_免租_card_on_an_opponents_land_paying_no_rent"] = function()
  local ctx = game_driver.new_game()
  local ai = _ai(ctx)
  local opp = ctx.game.players[1]
  local idx, tile_id = game_driver.first_land_tile(ctx)
  game_driver.set_tile_owner(ctx, tile_id, opp.id)
  game_driver.set_player_position(ctx, ai, idx)
  game_driver.give_item(ctx, ai, item_ids.free_rent)
  local cash_before = game_driver.player_cash(ctx, ai)

  local choice = turn_driver.settle_landing(ctx, ai)
  lu.assertIs(choice, nil, "免租 auto-resolves as a mandatory effect — no manual choice")
  lu.assertIs(game_driver.player_cash(ctx, ai), cash_before, "no rent was paid (免租)")
  lu.assertIs(game_driver.has_item(ctx, ai, item_ids.free_rent), false,
    "the 免租 card was consumed")
  lu.assertIs(game_driver.tile_owner(ctx, idx), opp.id, "the tile stays the opponent's")
end

function TestTurnDriver:test_leaves_a_humans_landing_choice_pending_the_ai_seam_never_auto_decides_for_a_human()
  local ctx = _ctx() -- all human
  local human = ctx.game.players[1]
  local idx = game_driver.first_land_tile(ctx)
  game_driver.set_player_position(ctx, human, idx)

  local choice = turn_driver.settle_landing(ctx, human)
  lu.assertIs(choice and choice.kind, "landing_optional_effect",
    "a human also opens the real optional-buy choice")
  lu.assertIs(turn_driver.auto_resolve_landing_choice(ctx), nil,
    "the real auto-play port yields no auto action for a human owner")
  lu.assertIs(turn_driver.pending_choice(ctx) and turn_driver.pending_choice(ctx).kind,
    "landing_optional_effect", "the human's choice is left pending for a manual decision")
end

-- -------------------------------------------------- settle_landing move_result passthrough

-- #199:settle_landing 接受可选 move_result 并透传真实落地结算;不传时行为与现状一致。
function TestTurnDriver:test_forwards_a_supplied_move_result_to_the_real_land_phase_and_defaults_to_nil()
  local ctx = _ctx()
  local land_phase = require("src.turn.phases.land")
  local captured = {}
  local original_run = land_phase.run
  land_phase.run = function(turn_mgr, args)
    captured[#captured + 1] = args
    return original_run(turn_mgr, args)
  end
  local ok, err = pcall(function()
    local p1 = ctx.game.players[1]
    turn_driver.settle_landing(ctx, p1, { encountered_players = { ctx.game.players[2].id } })
    turn_driver.settle_landing(ctx, p1)
  end)
  land_phase.run = original_run

  lu.assertEvalToTrue(ok, err)
  lu.assertIs(#captured, 2, "both settle calls reach the real land phase")
  lu.assertIs(captured[1].move_result and captured[1].move_result.encountered_players[1],
    ctx.game.players[2].id, "a supplied move_result is passed through")
  lu.assertIs(captured[2].move_result, nil, "an omitted move_result keeps the old nil default")
end

-- -------------------------------------------------- resolve_pending_choice

-- #201:runtime 未停桩时安全解析 pending choice——经真实 choice resolver 就地解析,
-- 不向回合机 dispatch,不异常推进。
function TestTurnDriver:test_resolves_an_un_parked_pending_choice_without_advancing_the_turn_machine()
  local ctx = _ctx() -- all human
  local p1 = ctx.game.players[1]
  game_driver.set_player_position(ctx, p1, ctx.game.board:find_first_by_type("tax"))
  game_driver.give_item(ctx, p1, item_ids.tax_free)
  local cash_before = game_driver.player_cash(ctx, p1)

  local choice = turn_driver.settle_landing(ctx, p1)
  lu.assertEvalToTrue(choice ~= nil and choice.kind == "tax_card_prompt",
    "settle opens the tax-free prompt, got " .. tostring(choice and choice.kind))
  local index_before = turn_driver.current_player_index(ctx)

  turn_driver.resolve_pending_choice(ctx, "use")

  lu.assertIs(game_driver.has_item(ctx, p1, item_ids.tax_free), false,
    "confirming consumes the tax-free card")
  lu.assertIs(game_driver.player_cash(ctx, p1), cash_before, "the tax-free card waives the tax")
  lu.assertIs(turn_driver.current_player_index(ctx), index_before,
    "the turn machine is not advanced")
end


return TestTurnDriver
