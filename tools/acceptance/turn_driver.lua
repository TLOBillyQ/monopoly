-- Acceptance facade for the turn loop, parallel to game_driver (ADR 0017 D1.1,
-- decision B). It shares game_driver's ctx and never recomposes the game: the ctx
-- already carries the real turn machine (ctx.game.turn_runtime over src/turn/*),
-- so this facade only drives and observes it. Spatial verbs stay in game_driver;
-- this module owns the turn lifecycle (rotation / elimination / detention / phase
-- timing). The two drivers never require each other — step handlers hold the same
-- ctx and route each op to the right facade.
--
-- Cluster 1 coverage: rotation, elimination-skip, detention, end-of-turn temporal
-- reset. Each behaviour flows through real src/turn code, not a parallel fixture.

local runtime_state = require("src.state.runtime")
local deadline_service = require("src.turn.deadlines")
local tick_timeout = require("src.turn.waits.timeout")
local turn_timer_policy = require("src.turn.policies.timer")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local tip_queue = require("src.foundation.tips")
local item_strategy = require("src.rules.items.strategy")
local auto_play_port = require("src.rules.ports.auto_play")
local land_phase = require("src.turn.phases.land")
local choice_auto = require("src.turn.policies.choice_auto")
local choice_resolver = require("src.rules.choice.resolver")
local item_executor = require("src.rules.items.executor")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local target_select_timer = require("src.turn.waits.target_select_timer")

local turn_driver = {}

local function _runtime(ctx)
  local rt = ctx.game.turn_runtime
  assert(rt ~= nil, "ctx.game has no turn_runtime")
  return rt
end

-- ── reads ────────────────────────────────────────────────────────────────────

function turn_driver.current_player(ctx)
  return ctx.game:current_player()
end

function turn_driver.current_player_index(ctx)
  return ctx.game.turn.current_player_index
end

function turn_driver.participant_count(ctx)
  return #ctx.game.players
end

function turn_driver.active_participant_count(ctx)
  local active = 0
  for _, player in ipairs(ctx.game.players) do
    if not player.eliminated then
      active = active + 1
    end
  end
  return active
end

function turn_driver.player_index(ctx, player)
  for index, candidate in ipairs(ctx.game.players) do
    if candidate == player then
      return index
    end
  end
  return nil
end

function turn_driver.is_eliminated(_, player)
  return player.eliminated == true
end

function turn_driver.stay_turns(_, player)
  return player.status and player.status.stay_turns or 0
end

function turn_driver.pending_remote_dice(_, player)
  return player.status and player.status.pending_remote_dice or nil
end

function turn_driver.dice_multiplier(_, player)
  return player.status and player.status.pending_dice_multiplier or 1
end

-- ── seeds ────────────────────────────────────────────────────────────────────

function turn_driver.set_current_player(ctx, index)
  ctx.game.turn.current_player_index = index
end

function turn_driver.eliminate(ctx, player)
  ctx.game:set_player_eliminated(player, true)
end

function turn_driver.detain(ctx, player, turns)
  ctx.game:set_player_status(player, "stay_turns", turns)
end

-- ── turn execution ───────────────────────────────────────────────────────────

-- A turn can stall on time/gate-driven waits (inter-turn delay, detention hold)
-- that production advances via the tick clock. play_turn elapses those delays so
-- the turn proceeds; the delay durations themselves are cluster 4's concern. The
-- rotation, elimination-skip, detention decrement and temporal reset all still run
-- through real src/turn phases.
local _STEP_BUDGET = 600

local function _resolve_wait(ctx, rt, wait_state)
  local turn = ctx.game.turn
  turn.inter_turn_wait_active = false
  turn.detained_wait_active = false
  if wait_state == "wait_action" then
    rt:dispatch({ type = "advance" })
  elseif wait_state == "wait_choice" then
    rt:dispatch({ type = "choice_force_skip" })
  elseif wait_state == "wait_move_anim" then
    rt:dispatch({ type = "move_anim_done" })
  elseif wait_state == "wait_action_anim" then
    rt:dispatch({ type = "action_anim_done" })
  elseif wait_state == "wait_landing_visual" then
    rt:dispatch({ type = "landing_visual_done" })
  end
end

-- Drive run_turn until the runtime hands the turn to the NEXT player (parked at
-- wait_action) or on_wait_state requests an early stop. on_wait_state, when given, is
-- called with each yielded wait_state before the handoff check; returning a truthy
-- value stops driving there, leaving that wait pending. Eliminated players are skipped
-- by the real start phase. Returns true if it stopped early, false if it drove all the
-- way to handoff. Errors if the step budget is exhausted first.
local function _drive_turn(ctx, rt, on_wait_state)
  local start_index = ctx.game.turn.current_player_index
  for _ = 1, _STEP_BUDGET do
    local wait_state = rt:run_turn()
    if on_wait_state and on_wait_state(wait_state) then
      return true
    end
    if ctx.game.turn.current_player_index ~= start_index and wait_state == "wait_action" then
      return false
    end
    _resolve_wait(ctx, rt, wait_state)
  end
  error("turn_driver: turn exceeded step budget without handoff")
end

-- Drive the current player's whole turn through the real phase machine until the
-- runtime hands off to the next player and parks them at wait_action. Returns that
-- next current player (always the next active one, since elimination is skipped).
function turn_driver.play_turn(ctx)
  local rt = _runtime(ctx)
  _drive_turn(ctx, rt)
  return ctx.game:current_player()
end

-- ── phase observation (cluster 2) ─────────────────────────────────────────────

-- Drive one player's turn and return the ordered phase/wait sequence the REAL turn
-- machine passes through. Phases are captured through src's own observation seam:
-- timing's `session:mark_phase` fires for every executed phase, so we attach a
-- recorder to `session._mark_phase` (preserving the production default of writing
-- game.turn.phase) and interleave the wait states yielded by run_turn. The result
-- is the real progression, e.g. start → wait_action → roll → pre_move → move →
-- ... → landing → post_action → end_turn — not a fixture script. The recorder is
-- always detached afterwards, even if a step errors, so sibling turns are unaffected.
function turn_driver.observe_turn_phases(ctx)
  local rt = _runtime(ctx)
  local session = assert(rt.session, "turn_runtime has no timing session")
  local sequence = {}
  local previous_mark = session._mark_phase
  session._mark_phase = function(phase)
    sequence[#sequence + 1] = phase
    -- Preserve the production default's observable write so nothing downstream
    -- of mark_phase (snapshot sync, dirty tracking) loses the current phase.
    if ctx.game.turn then
      ctx.game.turn.phase = phase
    end
  end
  local ok, err = pcall(_drive_turn, ctx, rt, function(wait_state)
    if wait_state ~= nil then
      sequence[#sequence + 1] = wait_state
    end
  end)
  session._mark_phase = previous_mark
  assert(ok, err)
  return sequence
end

-- Convenience predicate over observe_turn_phases: do the given milestone phases
-- appear, in order, as a subsequence of the real turn's phase progression?
function turn_driver.turn_phase_order_holds(ctx, milestones)
  local sequence = turn_driver.observe_turn_phases(ctx)
  local cursor = 1
  for _, observed in ipairs(sequence) do
    if observed == milestones[cursor] then
      cursor = cursor + 1
      if cursor > #milestones then
        return true, sequence
      end
    end
  end
  return false, sequence
end

-- ── landing-settlement choices (cluster 3) ────────────────────────────────────

-- Read the choice the real machine is currently parked on (nil when none).
function turn_driver.pending_choice(ctx)
  return ctx.game.turn.pending_choice
end

-- Drive the current player's turn until the real machine parks on a choice
-- (returns that pending choice) or completes without one (returns nil). Unlike
-- play_turn, non-choice waits are advanced but a wait_choice is left pending so the
-- caller can inspect and resolve it. Set up the landing (seat_before_tile + a roll
-- of 1, opponent ownership, card holdings) on game_driver first; this only drives.
function turn_driver.advance_to_choice(ctx)
  local rt = _runtime(ctx)
  local stopped = _drive_turn(ctx, rt, function(wait_state)
    return wait_state == "wait_choice"
  end)
  if stopped then
    return ctx.game.turn.pending_choice
  end
  return nil
end

-- Resolve the pending choice by selecting an option (e.g. "use" / "skip") through
-- the real choice_select dispatch, then drive the rest of the turn to handoff
-- (force-skipping any later choices). actor_role_id auto-resolves from the choice
-- owner / current player in src, so it is not supplied here.
function turn_driver.resolve_choice(ctx, option_id)
  local rt = _runtime(ctx)
  local choice = assert(ctx.game.turn.pending_choice, "no pending choice to resolve")
  rt:dispatch({ type = "choice_select", choice_id = choice.id, option_id = option_id })
  _drive_turn(ctx, rt)
end

-- ── choice deadlines / timeouts (cluster 4) ───────────────────────────────────

-- The choice-deadline / timeout subsystem runs in production's per-frame loop
-- (gameplay_loop.tick -> tick_steps.step_tick_timeouts), a layer distinct from the
-- coroutine phase machine driven above: DeadlineService counts each pending choice's
-- deadline down and exposes its warning level, while the choice-timeout step
-- auto-resolves the choice with its default once the deadline expires. We drive that
-- real subsystem over the SAME ctx.game by composing src's own per-frame timeout
-- sub-steps through its default (non-UI) policy seam (tick_timeout.step_default_choice)
-- — real DeadlineService, real scope_timeouts, real choice_auto resolution, no fixture
-- timer. The deadline clock is held on a runtime_state cached on the ctx so repeated
-- elapse calls accumulate, exactly as successive production frames would.

local function _deadline_state(ctx)
  local state = ctx._deadline_state
  if state == nil then
    state = {}
    runtime_state.ensure_all(state)
    state._game = ctx.game
    ctx._deadline_state = state
  end
  return state
end

local function _choice_scope(choice)
  if choice and choice.kind == "market_buy" then
    return "market_buy"
  end
  return "choice"
end

-- The real DeadlineService entry for the current pending choice's scope (nil when no
-- deadline is armed). Shared by the level / remaining readers below so the state +
-- scope resolution lives in one place.
local function _pending_deadline_entry(ctx)
  return deadline_service.peek(_deadline_state(ctx), _choice_scope(ctx.game.turn.pending_choice))
end

-- The configured deadline (seconds) for the current pending choice, read from src's
-- real scope_timeouts (普通 choice 15 / market_buy 60 / target_select 15).
function turn_driver.choice_timeout_seconds(ctx)
  return tick_timeout.resolve_choice_timeout_seconds(ctx.game, _deadline_state(ctx))
end

-- Arm the pending choice's deadline by running one zero-time frame of the real
-- choice-timeout step, so its countdown and warning level become observable without
-- yet advancing the clock.
function turn_driver.arm_choice_deadline(ctx)
  tick_timeout.step_default_choice(ctx.game, _deadline_state(ctx), 0.0)
end

-- Advance a deadline-governed subsystem's clock by `seconds` over the shared
-- DeadlineService state: count the service down (driving the warning level), then run
-- the subsystem's own per-frame step. The tick-before-step order mirrors production's
-- per-frame loop and is the invariant every timed subsystem here shares; `step_subsystem`
-- is that subsystem's real per-frame stepper (signature game, state, dt).
local function _elapse_deadline(ctx, seconds, step_subsystem)
  local state = _deadline_state(ctx)
  deadline_service.tick(state, seconds)
  step_subsystem(ctx.game, state, seconds)
end

-- Advance the choice-deadline clock by `seconds` of real time through the same
-- per-frame steps production runs: DeadlineService counts down (driving the warning
-- level) and the default choice-timeout resolver auto-resolves on expiry (market ->
-- 不买 cancel, others -> skip / first option). Call arm_choice_deadline first so the
-- two clocks start aligned.
function turn_driver.elapse_choice_deadline(ctx, seconds)
  _elapse_deadline(ctx, seconds, tick_timeout.step_default_choice)
end

-- The current warning level of the pending choice's deadline: "normal" -> "warn_5s"
-- -> "warn_3s" -> "expired", each threshold latched once by src. nil when no deadline
-- is armed for the current choice scope.
function turn_driver.choice_deadline_level(ctx)
  local entry = _pending_deadline_entry(ctx)
  return entry and entry.level or nil
end

-- Seconds remaining on the pending choice's deadline (nil when none is armed).
function turn_driver.choice_deadline_remaining(ctx)
  local entry = _pending_deadline_entry(ctx)
  return entry and entry.remaining_seconds or nil
end

-- ── inter-turn wait (cluster 4) ───────────────────────────────────────────────

-- After end_turn the real machine opens an inter-turn wait (the end_turn registry sets
-- turn.inter_turn_wait_active + inter_turn_wait_seconds) before the next player starts.
-- Production elapses that interval on the frame clock via turn_timer_policy, and a
-- blocking inter-turn tip holds the gate until the prompt finishes. We drive that real
-- timer and the real tip_queue gate over the same ctx.game.

-- Drive the current turn until the real machine parks in its end-of-turn inter-turn
-- wait, stopping with the gate still set — before any resolution clears it, so the
-- next player has NOT started. Returns whether the wait gate is active.
function turn_driver.advance_to_inter_turn_wait(ctx)
  local rt = _runtime(ctx)
  _drive_turn(ctx, rt, function(wait_state)
    return wait_state == "inter_turn_wait"
  end)
  return ctx.game.turn.inter_turn_wait_active == true
end

-- The configured inter-turn wait interval (seconds) the real end_turn registry set.
function turn_driver.inter_turn_wait_seconds(ctx)
  return ctx.game.turn.inter_turn_wait_seconds
end

-- True while the turn is parked in its end-of-turn inter-turn wait gate.
function turn_driver.inter_turn_wait_active(ctx)
  return ctx.game.turn.inter_turn_wait_active == true
end

-- Advance the real inter-turn wait timer by `seconds`. Once the configured interval
-- elapses, src's real step_turn advances to the next player — unless a blocking
-- inter-turn tip still holds the gate.
function turn_driver.elapse_inter_turn_wait(ctx, seconds)
  turn_timer_policy.update_inter_turn_wait_timer(
    ctx.game, _deadline_state(ctx), seconds, turn_dispatch.step_turn)
end

-- Saved ambient tip_queue test_mode across a held blocking prompt (restored by reset_tips).
local _held_tip_prior_test_mode = nil

-- Enqueue a real blocking inter-turn tip so the inter-turn gate is held until tips are
-- reset — mirrors a blocking prompt shown at end of turn. A prompt genuinely on screen
-- schedules its release on the frame clock and is RETAINED until dismissed; the tip
-- runtime only retains a deferred (scheduler-returns-true) tip while test_mode is off —
-- under test_mode it short-circuits to a synchronous auto-release. The harness boots the
-- tip runtime in test_mode (spec/env_runtime), so we drop test_mode for the duration of
-- the held prompt (restored in reset_tips); otherwise the gate would release at once and
-- the hold would silently depend on whatever ambient test_mode a sibling spec last left.
function turn_driver.hold_inter_turn_with_blocking_tip(_)
  _held_tip_prior_test_mode = tip_queue.snapshot().test_mode
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function() return true end,
    test_mode = false,
  })
  tip_queue.enqueue({ text = "blocking prompt", duration = 5.0, blocks_inter_turn = true })
end

-- Reset the process-global tip queue so a blocking tip does not leak across turns, and
-- restore the ambient test_mode a held prompt dropped (if any) so the runtime is handed
-- back exactly as the harness configured it.
function turn_driver.reset_tips(_)
  tip_queue.clear()
  tip_queue.configure_runtime({ clear_presenter = true, clear_scheduler = true })
  if _held_tip_prior_test_mode ~= nil then
    tip_queue.configure_runtime({ test_mode = _held_tip_prior_test_mode })
    _held_tip_prior_test_mode = nil
  end
end

-- ── AI item-use phase (cluster 5) ─────────────────────────────────────────────

-- The computer player's item-use phase tries the player's cards in a fixed priority
-- order, using each whose trigger condition holds, until one needs a player choice.
-- BOTH the priority ordering AND the per-card trigger predicates live solely in
-- src/rules/items/strategy.lua (the _run_auto_pre_action_probes chain + its inline
-- conditions). This driver runs that real chain and observes the real outcome, so it
-- never reproduces turn_flow.lua's AI_ITEM_PRIORITY / AI_TRIGGER_KNOWN copies (D3
-- single source).

-- Whether the game treats `player` as a computer player (real auto_play port).
function turn_driver.is_ai(ctx, player)
  return auto_play_port.is_auto_player(ctx.game, player) == true
end

-- Run the real AI item-use phase for `player` in `phase`: src's strategy probe chain
-- consumes each triggering card in its own priority order and stops at the first that
-- needs follow-up. Returns the strategy result (a waiting/intent table when a card
-- needs a choice, else nil). A non-AI player is a no-op (src returns nil).
function turn_driver.run_ai_item_phase(ctx, player, phase)
  return item_strategy.auto_pre_action(ctx.game, player, phase)
end

-- ── AI landing settlement (cluster 6) ─────────────────────────────────────────

-- A computer player's买地/升级/对手地免租 are decided at landing settlement, not in
-- the item-use phase: src's land phase opens an optional buy/upgrade as a real
-- landing_optional_effect choice, and choice_auto (the AI actor decision entry) picks
-- the action for the auto owner. Driving the FULL turn coroutine through that path
-- reaches host LuaAPI gaps, so this seam drives the settlement + decision functions
-- directly over the same ctx.game (ADR 0017 D1.1 decision-B / cluster-6 seam (a)): no
-- coroutine, no host stub, no decision-table copy — the priority and the buy/upgrade/
-- 免租 outcome come entirely from src.turn.phases.land + src.turn.policies.choice_auto
-- + src.computer.agent.

-- Run the real landing settlement for `player` on the tile they currently occupy, over
-- the same ctx.game. src's land phase runs the mandatory effects (e.g. pay_rent, which
-- auto-uses a held 免租 card with no manual choice) and, for an ownable buy/upgrade,
-- opens the real landing_optional_effect choice into pending_choice. Returns that
-- pending choice (nil when the landing settled without one). Seat the player and set
-- tile ownership / card holdings on game_driver first; this drives only the settlement.
function turn_driver.settle_landing(ctx, player)
  land_phase.run({ game = ctx.game }, { player = player, move_result = nil })
  return ctx.game.turn.pending_choice
end

-- Resolve the pending landing choice through the real AI decision seam: choice_auto
-- decides the action for the choice owner — and only produces one when src's auto_play
-- port treats that owner as a computer player (a human owner yields no auto action, so
-- the choice is left pending and nil is returned) — then the real choice resolver
-- applies it (buy_land / upgrade_land), landing genuine game state (tile owner, cash,
-- level). Returns the option_id the AI chose. The decision lives solely in
-- src.turn.policies.choice_auto + src.computer.agent; no AI constant is copied here.
function turn_driver.auto_resolve_landing_choice(ctx)
  local choice = ctx.game.turn.pending_choice
  if not choice then return nil end
  local action = choice_auto.decide(ctx.game, nil, choice, { mode = "wait_choice" })
  if not action then return nil end
  choice_resolver.resolve(ctx.game, choice, action)
  return action.option_id
end

-- ── item-target-select deadline (cluster 4 sibling) ───────────────────────────

-- Using a target item (steal / missile / …) raises a real item_target_player choice,
-- and src governs its timeout through a SEPARATE subsystem from the choice deadline
-- above: target_select_timer borrows the DeadlineService `target_select` scope, but
-- only arms once `_item_phase_ask_active` is set (production sets it when the target
-- modal opens — src/ui/coord/modal.lua). We drive that real timer over the same ctx by
-- raising the real choice (executor.use_item -> intent_dispatcher) and setting the same
-- ask flag the modal would, then ticking the real DeadlineService. The item is consumed
-- only when a target is APPLIED, so a timeout never consumes it (the「留存」semantics).

-- Raise the real item-target-select choice for `player` using `item_id`: src's executor
-- produces the target-pick intent, the real intent dispatcher opens it into pending_choice
-- (kind item_target_player), and we set the ask flag the target modal would so the real
-- target_select timer will arm. Returns the pending choice. Give the item + a valid target
-- on game_driver first. The card is NOT pre-consumed here — src consumes it only on apply.
function turn_driver.open_target_item_choice(ctx, player, item_id)
  local res = item_executor.use_item(ctx.game, player, item_id, {})
  intent_dispatcher.dispatch(ctx.game, res)
  _deadline_state(ctx)._item_phase_ask_active = true
  return ctx.game.turn.pending_choice
end

-- The configured target-select deadline (seconds) from src's real scope_timeouts
-- (target_select = 15).
function turn_driver.target_select_timeout_seconds(_)
  return require("src.config.gameplay.timing").scope_timeouts.target_select
end

-- Arm the target-select deadline by running one zero-time frame of the real
-- target_select timer (it registers the DeadlineService `target_select` entry because
-- the ask flag is set), so its countdown and warning level become observable.
function turn_driver.arm_target_select_deadline(ctx)
  target_select_timer.step(ctx.game, _deadline_state(ctx), 0.0)
end

-- Advance the target-select deadline clock by `seconds` through the same real per-frame
-- steps production runs: DeadlineService counts down (driving the warning level) and the
-- target_select timer auto-cancels on timeout (resolve_target_select). Arm first.
function turn_driver.elapse_target_select_deadline(ctx, seconds)
  _elapse_deadline(ctx, seconds, target_select_timer.step)
end

-- The current warning level of the target-select deadline (nil when none armed):
-- "normal" -> "warn_5s" -> "warn_3s" -> "expired", each latched once by src.
function turn_driver.target_select_deadline_level(ctx)
  local entry = deadline_service.peek(_deadline_state(ctx), "target_select")
  return entry and entry.level or nil
end

return turn_driver
