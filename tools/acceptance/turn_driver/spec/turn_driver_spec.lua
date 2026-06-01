-- Tooling-lane tests for the turn-loop acceptance facade. They assert the driver
-- drives the REAL turn machine (src/turn/*) over game_driver's shared ctx, not a
-- parallel fixture: rotation, elimination-skip, detention and end-of-turn temporal
-- reset must all flow through real src code (ADR 0017 D1.1, decision B).
local game_driver = require("tools.acceptance.game_driver")
local turn_driver = require("tools.acceptance.turn_driver")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")

local function _assert_eq(actual, expected, message)
  assert(actual == expected,
    (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

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

describe("turn_driver reads over real ctx", function()
  it("reports the real current player and index", function()
    local ctx = _ctx()
    _assert_eq(turn_driver.current_player_index(ctx), 1, "fresh game starts on player 1")
    _assert_eq(turn_driver.current_player(ctx), ctx.game.players[1], "current_player reads real game state")
  end)

  it("counts participants and active (non-eliminated) participants", function()
    local ctx = _ctx()
    _assert_eq(turn_driver.participant_count(ctx), 4, "four players seated")
    _assert_eq(turn_driver.active_participant_count(ctx), 4, "all active before elimination")
    turn_driver.eliminate(ctx, ctx.game.players[2])
    _assert_eq(turn_driver.active_participant_count(ctx), 3, "eliminating one drops the active count")
    _assert_eq(turn_driver.is_eliminated(ctx, ctx.game.players[2]), true, "elimination reads back")
  end)

  it("sets the current player as a seed", function()
    local ctx = _ctx()
    turn_driver.set_current_player(ctx, 3)
    _assert_eq(turn_driver.current_player_index(ctx), 3, "seed sets whose turn it is")
    _assert_eq(turn_driver.current_player(ctx), ctx.game.players[3], "current_player follows the seed")
  end)

  it("resolves a seated player's index and reports nil for a non-participant", function()
    local ctx = _ctx()
    _assert_eq(turn_driver.player_index(ctx, ctx.game.players[3]), 3, "a seated player resolves to its seat index")
    _assert_eq(turn_driver.player_index(ctx, ctx.game.players[1]), 1, "the first seat resolves to index 1")
    _assert_eq(turn_driver.player_index(ctx, { id = "outsider" }), nil, "a player not in the roster resolves to nil")
  end)
end)

describe("turn_driver rotation via the real machine", function()
  it("hands off to the next player when a turn is played", function()
    local ctx = _ctx()
    local next_player = turn_driver.play_turn(ctx)
    _assert_eq(next_player, ctx.game.players[2], "after P1 plays, P2 is up")
    _assert_eq(turn_driver.current_player_index(ctx), 2, "runtime index advanced to 2")
  end)

  it("wraps from the last player back to the first", function()
    local ctx = _ctx()
    turn_driver.set_current_player(ctx, 4)
    local next_player = turn_driver.play_turn(ctx)
    _assert_eq(next_player, ctx.game.players[1], "player 4's turn wraps to player 1")
  end)

  it("skips an eliminated player on handoff", function()
    local ctx = _ctx()
    turn_driver.eliminate(ctx, ctx.game.players[2])
    local next_player = turn_driver.play_turn(ctx)
    _assert_eq(next_player, ctx.game.players[3], "eliminated P2 is skipped, P3 is up")
    _assert_eq(turn_driver.current_player_index(ctx), 3, "runtime landed on player 3")
  end)
end)

describe("turn_driver detention via the real machine", function()
  it("decrements stay_turns at turn start and skips the player's action", function()
    local ctx = _ctx()
    local detained = ctx.game.players[1]
    turn_driver.detain(ctx, detained, 2)
    local position_before = detained.position
    turn_driver.play_turn(ctx)
    _assert_eq(turn_driver.stay_turns(ctx, detained), 1, "real start phase decrements stay_turns 2 -> 1")
    _assert_eq(detained.position, position_before, "a detained player does not roll or move")
  end)

  it("lets the player act normally once detention expires", function()
    local ctx = _ctx()
    local player = ctx.game.players[1]
    turn_driver.detain(ctx, player, 1)
    turn_driver.play_turn(ctx)
    _assert_eq(turn_driver.stay_turns(ctx, player), 0, "the single detained turn clears stay_turns")
    -- Play around the table back to player 1; their detention has expired now.
    local position_before = player.position
    turn_driver.play_turn(ctx) -- P2
    turn_driver.play_turn(ctx) -- P3
    turn_driver.play_turn(ctx) -- P4 hands back to P1
    _assert_eq(turn_driver.current_player_index(ctx), 1, "rotation comes back to player 1")
    turn_driver.play_turn(ctx) -- P1 now acts normally
    assert(player.position ~= position_before, "after detention expires the player rolls and moves")
  end)
end)

describe("turn_driver end-of-turn temporal reset via the real machine", function()
  it("clears remote dice and resets the dice multiplier when the turn ends", function()
    local ctx = _ctx()
    local player = ctx.game.players[1]
    -- Seed temporal flags through game_driver (shared ctx); turn_driver observes
    -- that ending the turn runs the real clear_player_temporal_flags.
    game_driver.apply_remote_dice(ctx, player, 2, 6)
    game_driver.set_dice_multiplier(ctx, player, 3)
    assert(turn_driver.pending_remote_dice(ctx, player) ~= nil, "remote dice seeded")
    turn_driver.play_turn(ctx)
    _assert_eq(turn_driver.pending_remote_dice(ctx, player), nil, "remote dice cleared at end of turn")
    _assert_eq(turn_driver.dice_multiplier(ctx, player), 1, "dice multiplier reset to 1 at end of turn")
  end)
end)

local function _index_of(sequence, value)
  for index, observed in ipairs(sequence) do
    if observed == value then
      return index
    end
  end
  return nil
end

describe("turn_driver phase sequence via the real machine (cluster 2)", function()
  -- The standard turn milestones, in the order src/turn/* drives them:
  -- 开始 → 等待行动 → 掷骰 → 移动 → 落地 → 结束.
  local STANDARD = { "start", "wait_action", "roll", "move", "landing", "end_turn" }

  it("passes through the standard phases in order", function()
    local ctx = _ctx()
    local sequence = turn_driver.observe_turn_phases(ctx)
    -- Every standard milestone is observed, each strictly after the previous one,
    -- so the assertion pins the real phase ordering rather than mere presence.
    local previous = 0
    for _, phase in ipairs(STANDARD) do
      local at = _index_of(sequence, phase)
      assert(at ~= nil, "phase '" .. phase .. "' must appear in the turn sequence")
      assert(at > previous,
        "phase '" .. phase .. "' must come after the previous milestone, got index " .. tostring(at))
      previous = at
    end
  end)

  it("reports the standard milestone order holds as a subsequence", function()
    local ctx = _ctx()
    local holds = turn_driver.turn_phase_order_holds(ctx, STANDARD)
    _assert_eq(holds, true, "the real turn must satisfy the standard phase order")
  end)

  it("rejects an impossible phase order (end before start)", function()
    local ctx = _ctx()
    -- end_turn never precedes start within a turn, so the predicate must say no —
    -- proving it checks ordering, not just membership.
    local holds = turn_driver.turn_phase_order_holds(ctx, { "end_turn", "start", "roll" })
    _assert_eq(holds, false, "a scrambled order must not hold against the real sequence")
  end)

  it("skips roll and move for a detained player's turn", function()
    local ctx = _ctx()
    -- A detained player's start phase ends the turn without rolling or moving, so
    -- the real phase sequence must omit roll/move while still starting and ending.
    turn_driver.detain(ctx, ctx.game.players[1], 1)
    local sequence = turn_driver.observe_turn_phases(ctx)
    assert(_index_of(sequence, "start") ~= nil, "a detained turn still runs the start phase")
    assert(_index_of(sequence, "roll") == nil, "a detained player must not reach the roll phase")
    assert(_index_of(sequence, "move") == nil, "a detained player must not reach the move phase")
  end)
end)

describe("turn_driver landing-settlement card boundaries via the real machine (cluster 3)", function()
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

  it("auto-consumes a free-rent card on an opponent tile without a choice or rent", function()
    local ctx = _ctx()
    local p1 = _seat_for_rent(ctx, true)
    game_driver.give_item(ctx, p1, item_ids.free_rent)
    local cash_before = game_driver.player_cash(ctx, p1)
    local opponent_cash_before = game_driver.player_cash(ctx, ctx.game.players[2])

    local choice = turn_driver.advance_to_choice(ctx)
    _assert_eq(choice, nil, "a lone free-rent card is auto-used — no manual choice is raised")
    _assert_eq(game_driver.has_item(ctx, p1, item_ids.free_rent), false, "the free-rent card is consumed")
    _assert_eq(game_driver.player_cash(ctx, p1), cash_before, "no rent is paid when免租 applies")
    _assert_eq(game_driver.player_cash(ctx, ctx.game.players[2]), opponent_cash_before,
      "the owner receives no rent")
    assert(_saw_event(ctx, event_kinds.item_used), "the free-rent card use is published as an item-used event")
    assert(not _saw_event(ctx, event_kinds.rent_paid), "no rent-paid event is published")
  end)

  it("prompts for the seizure card first; declining auto-uses免租 and skips rent", function()
    local ctx = _ctx()
    local p1 = _seat_for_rent(ctx, true)
    game_driver.give_item(ctx, p1, item_ids.strong)
    game_driver.give_item(ctx, p1, item_ids.free_rent)
    local cash_before = game_driver.player_cash(ctx, p1)
    local opponent_cash_before = game_driver.player_cash(ctx, ctx.game.players[2])

    local choice = turn_driver.advance_to_choice(ctx)
    assert(choice ~= nil, "holding a seizure card raises a prompt before rent settles")
    _assert_eq(choice.kind, "rent_card_prompt", "the prompt is the rent-card choice")
    _assert_eq(choice.meta.card_kind, "strong", "the prompt offers the seizure (strong) card")

    turn_driver.resolve_choice(ctx, "skip")
    _assert_eq(game_driver.has_item(ctx, p1, item_ids.strong), true,
      "declining the seizure keeps the strong card")
    _assert_eq(game_driver.has_item(ctx, p1, item_ids.free_rent), false,
      "declining the seizure auto-consumes the free-rent card")
    _assert_eq(game_driver.player_cash(ctx, p1), cash_before, "no rent is paid after the free-rent fallback")
    _assert_eq(game_driver.player_cash(ctx, ctx.game.players[2]), opponent_cash_before,
      "the owner receives no rent")
  end)

  it("seizes the tile when the seizure prompt is accepted", function()
    local ctx = _ctx()
    local p1 = _seat_for_rent(ctx, true)
    game_driver.give_item(ctx, p1, item_ids.strong)
    local cash_before = game_driver.player_cash(ctx, p1)

    local choice = turn_driver.advance_to_choice(ctx)
    assert(choice ~= nil, "the seizure prompt must be raised")
    _assert_eq(choice.meta.card_kind, "strong", "the seizure prompt is raised")
    turn_driver.resolve_choice(ctx, "use")
    _assert_eq(game_driver.has_item(ctx, p1, item_ids.strong), false, "accepting consumes the strong card")
    _assert_eq(ctx.game.board:get_tile_by_id(_RENT_TILE_ID).owner_id, p1.id,
      "the tile ownership transfers to the seizer")
    assert(game_driver.player_cash(ctx, p1) < cash_before, "seizing pays the tile's total invested value")
  end)

  -- The black market is off the outer ring; the player is routed onto the inner path
  -- and onto the market tile through real movement (seat + even roll), and the sold-out
  -- state is the real zeroed global limits — no fixture flag.
  it("raises no purchase choice when landing on a sold-out black market", function()
    local ctx = _ctx()
    local p1 = ctx.game.players[1]
    game_driver.set_market_sold_out(ctx)
    local market_id = game_driver.seat_to_land_on_market(ctx, p1)

    local choice = turn_driver.advance_to_choice(ctx)
    _assert_eq(choice, nil, "a sold-out market offers nothing to buy — no purchase choice is raised")
    _assert_eq(ctx.game.board:get_tile(p1.position).id, market_id,
      "the player really moved onto the market tile via the inner path")
  end)

  it("still opens the market when passing through it sold-out (the visit is reached)", function()
    -- Reverse-proof for the landing case: with the SAME sold-out state, passing
    -- through the market (interrupt path) still opens it, so the no-choice above is
    -- the landing settlement's sold-out gate — not a failure to reach the market.
    local ctx = _ctx()
    local p1 = ctx.game.players[1]
    game_driver.set_market_sold_out(ctx)
    game_driver.seat_to_pass_through_market(ctx, p1)

    local choice = turn_driver.advance_to_choice(ctx)
    assert(choice ~= nil, "passing through the market opens it even when sold out")
    _assert_eq(choice.kind, "market_buy", "the opened choice is the black-market purchase prompt")
  end)
end)

describe("turn_driver choice deadlines / timeouts via the real machine (cluster 4)", function()
  -- Raise a real market-purchase choice (sold-out so the timeout default of 不买 is a
  -- pure no-op on cash), and a real rent-card prompt (a 普通 choice), then drive the
  -- real DeadlineService + choice-timeout subsystem over the same ctx.
  local _RENT_TILE_ID = 1

  local function _open_market_choice(ctx)
    local p1 = ctx.game.players[1]
    game_driver.set_market_sold_out(ctx)
    game_driver.seat_to_pass_through_market(ctx, p1)
    local choice = turn_driver.advance_to_choice(ctx)
    assert(choice ~= nil, "a market-purchase choice must be open")
    _assert_eq(choice.kind, "market_buy", "a market-purchase choice is open")
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
    assert(choice ~= nil, "a rent-card prompt must be open")
    _assert_eq(choice.kind, "rent_card_prompt", "a rent-card prompt is open")
    return p1
  end

  it("reads each choice type's real configured deadline (market 60 / 普通 15)", function()
    local ctx = _ctx()
    _open_market_choice(ctx)
    _assert_eq(turn_driver.choice_timeout_seconds(ctx), 60, "market_buy uses the 60s scope timeout")
  end)

  it("reads the 15s deadline for a普通 choice", function()
    local ctx = _ctx()
    _open_rent_prompt(ctx)
    _assert_eq(turn_driver.choice_timeout_seconds(ctx), 15, "a普通 choice uses the 15s scope timeout")
  end)

  it("counts the deadline down through warning levels without pausing", function()
    -- Black-market browsing must NOT pause the action timer: as real time elapses the
    -- deadline crosses each warning threshold once (normal -> warn_5s -> warn_3s).
    local ctx = _ctx()
    _open_market_choice(ctx)
    turn_driver.arm_choice_deadline(ctx)
    _assert_eq(turn_driver.choice_deadline_level(ctx), "normal", "a fresh deadline starts normal")

    turn_driver.elapse_choice_deadline(ctx, 54.0) -- remaining ~6
    _assert_eq(turn_driver.choice_deadline_level(ctx), "normal", "still normal above the 5s threshold")
    turn_driver.elapse_choice_deadline(ctx, 1.0) -- remaining ~5
    _assert_eq(turn_driver.choice_deadline_level(ctx), "warn_5s", "crossing 5s raises the warning level")
    turn_driver.elapse_choice_deadline(ctx, 2.0) -- remaining ~3
    _assert_eq(turn_driver.choice_deadline_level(ctx), "warn_3s", "crossing 3s raises the urgent level")
  end)

  it("auto-resolves a sold-out market on timeout as 不买 — no cash spent, choice cleared", function()
    local ctx = _ctx()
    local p1 = _open_market_choice(ctx)
    local cash_before = game_driver.player_cash(ctx, p1)
    turn_driver.arm_choice_deadline(ctx)

    turn_driver.elapse_choice_deadline(ctx, 61.0) -- past the 60s market deadline
    _assert_eq(game_driver.player_cash(ctx, p1), cash_before,
      "timing out the market is a gentle 不买 — no cash is deducted")
    assert(turn_driver.pending_choice(ctx) == nil
      or turn_driver.pending_choice(ctx).kind ~= "market_buy",
      "the timed-out market choice is cleared")
  end)
end)

describe("turn_driver inter-turn wait via the real machine (cluster 4)", function()
  it("waits the inter-turn interval before the next player's turn starts", function()
    local ctx = _ctx()
    assert(turn_driver.advance_to_inter_turn_wait(ctx),
      "the turn opens an inter-turn wait at end of turn")
    _assert_eq(turn_driver.current_player_index(ctx), 1, "the first player's turn has ended but not handed off")
    assert((turn_driver.inter_turn_wait_seconds(ctx) or 0) > 0, "a positive inter-turn interval is configured")

    turn_driver.elapse_inter_turn_wait(ctx, turn_driver.inter_turn_wait_seconds(ctx))
    _assert_eq(turn_driver.current_player_index(ctx), 2,
      "elapsing the interval hands the turn to the next player")
  end)

  it("holds the inter-turn wait until a blocking prompt finishes", function()
    local ctx = _ctx()
    turn_driver.reset_tips(ctx)
    turn_driver.advance_to_inter_turn_wait(ctx)
    turn_driver.hold_inter_turn_with_blocking_tip(ctx)

    turn_driver.elapse_inter_turn_wait(ctx, 5.0) -- well past the interval
    _assert_eq(turn_driver.current_player_index(ctx), 1,
      "a blocking prompt holds the gate — the next player does not start")
    assert(turn_driver.inter_turn_wait_active(ctx), "the inter-turn wait stays active while blocked")

    turn_driver.reset_tips(ctx)
    turn_driver.elapse_inter_turn_wait(ctx, 5.0)
    _assert_eq(turn_driver.current_player_index(ctx), 2,
      "once the blocking prompt clears, the wait completes and hands off")
  end)
end)

describe("turn_driver AI item-use phase via the real strategy (cluster 5)", function()
  -- Player 2 is a computer player by default (new_game ai = {[2]=true,...}). These
  -- drive src's real AI item-use strategy and assert its real priority/trigger
  -- decisions — the driver reproduces none of turn_flow.lua's AI constant copies.
  local function _ai(ctx)
    return ctx.game.players[2]
  end

  it("recognises the computer player through the real auto-play port", function()
    local ctx = _ctx() -- all human
    _assert_eq(turn_driver.is_ai(ctx, ctx.game.players[1]), false, "a human player is not auto")
    local ai_ctx = game_driver.new_game() -- default AI on seats 2..4
    _assert_eq(turn_driver.is_ai(ai_ctx, ai_ctx.game.players[2]), true, "seat 2 is a computer player")
  end)

  it("uses the obstacle-clearing card only when the real trigger finds an obstacle ahead", function()
    local ctx = game_driver.new_game()
    local ai = _ai(ctx)
    ctx.game.turn.current_player_index = 2
    game_driver.give_item(ctx, ai, item_ids.clear_obstacles)
    game_driver.seat_with_obstacle_ahead(ctx, ai)

    turn_driver.run_ai_item_phase(ctx, ai, "pre_action")
    _assert_eq(game_driver.has_item(ctx, ai, item_ids.clear_obstacles), false,
      "an obstacle ahead triggers the real clear-obstacles use")
  end)

  it("keeps the obstacle-clearing card when the real trigger finds no obstacle", function()
    local ctx = game_driver.new_game()
    local ai = _ai(ctx)
    ctx.game.turn.current_player_index = 2
    game_driver.give_item(ctx, ai, item_ids.clear_obstacles)
    game_driver.seat_on_ring(ctx, ai) -- clear path

    turn_driver.run_ai_item_phase(ctx, ai, "pre_action")
    _assert_eq(game_driver.has_item(ctx, ai, item_ids.clear_obstacles), true,
      "with no obstacle ahead the real trigger declines to use the card")
  end)

  it("does not run the item phase for a human player", function()
    local ctx = _ctx() -- all human
    local human = ctx.game.players[1]
    game_driver.give_item(ctx, human, item_ids.clear_obstacles)
    game_driver.seat_with_obstacle_ahead(ctx, human)

    _assert_eq(turn_driver.run_ai_item_phase(ctx, human, "pre_action"), nil,
      "the AI item phase is a no-op for a human player")
    _assert_eq(game_driver.has_item(ctx, human, item_ids.clear_obstacles), true,
      "the human keeps the card — only manual use applies")
  end)
end)

describe("turn_driver AI landing settlement via the real seam (cluster 6)", function()
  -- 买地 / 升级 / 对手地免租 are decided at landing settlement, not the item phase: src's
  -- land phase raises the real landing_optional_effect choice and choice_auto (the AI
  -- actor decision entry) resolves it. These drive that real settlement + decision over
  -- the shared ctx — no coroutine, no host stub, no decision-table copy.
  local function _ai(ctx)
    return ctx.game.players[2]
  end

  it("auto-buys an unowned affordable land it lands on", function()
    local ctx = game_driver.new_game()
    local ai = _ai(ctx)
    local idx = game_driver.first_land_tile(ctx)
    game_driver.set_player_position(ctx, ai, idx)
    local cash_before = game_driver.player_cash(ctx, ai)

    local choice = turn_driver.settle_landing(ctx, ai)
    _assert_eq(choice and choice.kind, "landing_optional_effect",
      "an unowned land opens the real optional-buy choice")
    _assert_eq(turn_driver.auto_resolve_landing_choice(ctx), "buy_land",
      "the real AI decision buys the land")
    _assert_eq(game_driver.tile_owner(ctx, idx), ai.id, "the tile is now owned by the AI")
    assert(game_driver.player_cash(ctx, ai) < cash_before, "the purchase deducted cash")
  end)

  it("auto-upgrades its own land it lands on", function()
    local ctx = game_driver.new_game()
    local ai = _ai(ctx)
    local idx, tile_id = game_driver.first_land_tile(ctx)
    game_driver.set_tile_owner(ctx, tile_id, ai.id)
    game_driver.set_player_position(ctx, ai, idx)
    local level_before = game_driver.tile_level(ctx, idx)
    local cash_before = game_driver.player_cash(ctx, ai)

    local choice = turn_driver.settle_landing(ctx, ai)
    _assert_eq(choice and choice.kind, "landing_optional_effect",
      "own land opens the real optional-upgrade choice")
    _assert_eq(turn_driver.auto_resolve_landing_choice(ctx), "upgrade_land",
      "the real AI decision upgrades the land")
    assert(game_driver.tile_level(ctx, idx) > level_before, "the upgrade raised the tile level")
    assert(game_driver.player_cash(ctx, ai) < cash_before, "the upgrade deducted cash")
  end)

  it("auto-uses a held 免租 card on an opponent's land, paying no rent", function()
    local ctx = game_driver.new_game()
    local ai = _ai(ctx)
    local opp = ctx.game.players[1]
    local idx, tile_id = game_driver.first_land_tile(ctx)
    game_driver.set_tile_owner(ctx, tile_id, opp.id)
    game_driver.set_player_position(ctx, ai, idx)
    game_driver.give_item(ctx, ai, item_ids.free_rent)
    local cash_before = game_driver.player_cash(ctx, ai)

    local choice = turn_driver.settle_landing(ctx, ai)
    _assert_eq(choice, nil, "免租 auto-resolves as a mandatory effect — no manual choice")
    _assert_eq(game_driver.player_cash(ctx, ai), cash_before, "no rent was paid (免租)")
    _assert_eq(game_driver.has_item(ctx, ai, item_ids.free_rent), false,
      "the 免租 card was consumed")
    _assert_eq(game_driver.tile_owner(ctx, idx), opp.id, "the tile stays the opponent's")
  end)

  it("leaves a human's landing choice pending — the AI seam never auto-decides for a human", function()
    local ctx = _ctx() -- all human
    local human = ctx.game.players[1]
    local idx = game_driver.first_land_tile(ctx)
    game_driver.set_player_position(ctx, human, idx)

    local choice = turn_driver.settle_landing(ctx, human)
    _assert_eq(choice and choice.kind, "landing_optional_effect",
      "a human also opens the real optional-buy choice")
    _assert_eq(turn_driver.auto_resolve_landing_choice(ctx), nil,
      "the real auto-play port yields no auto action for a human owner")
    _assert_eq(turn_driver.pending_choice(ctx) and turn_driver.pending_choice(ctx).kind,
      "landing_optional_effect", "the human's choice is left pending for a manual decision")
  end)
end)
