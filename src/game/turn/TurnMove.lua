local Steal = require("src.game.item.ItemSteal")
local MonopolyEvent = require("src.game.MonopolyEvents")
local MovementManager = require("src.game.movement.MovementManager")
local MarketManager = require("src.game.market.MarketManager")

local function _ResolveEventName(kind)
  assert(MonopolyEvent ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(MonopolyEvent.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function _DispatchIntent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game ~= nil and game.store ~= nil, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:Get({ "turn", "choice_seq" }) or 0
    seq = seq + 1
    game.store:Set({ "turn", "choice_seq" }, seq)
    local entry = {
      id = seq,
      kind = spec.kind,
      title = spec.title or "请选择",
      body_lines = spec.body_lines or {},
      options = spec.options or {},
      allow_cancel = spec.allow_cancel ~= false,
      cancel_label = spec.cancel_label or "取消",
      meta = spec.meta,
    }
    game.store:Set({ "turn", "pending_choice" }, entry)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _ResolveEventName("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _ResolveEventName("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

local function _PhaseMove(tm, args)
  local player = args.player
  local total = args.total
  local raw_total = args.raw_total
  assert(tm.game ~= nil, "missing game")
  local move_result = args.move_result

  local move_opts = { branch_parity = raw_total }
  if args.continue_from_market or args.continue_from_steal then
    total = args.remaining_steps
    move_opts.direction = args.facing
    move_opts.branch_parity = args.branch_parity
  end

  if not move_result then
    local start_index = player.position
    move_result = MovementManager.Move(tm.game, player, total, move_opts)
    tm.game.last_turn.move_result = move_result

    local game = tm.game
    local store = assert(game.store, "missing game.store")
    local ui_port = assert(game.ui_port, "missing game.ui_port")
    if ui_port.wait_move_anim == true then
      local seq = (store:Get({ "turn", "move_anim_seq" }) or 0) + 1
      store:Set({ "turn", "move_anim_seq" }, seq)
      store:Set({ "turn", "move_anim" }, {
        seq = seq,
        player_id = player.id,
        from_index = start_index,
        to_index = player.position,
        visited = move_result.visited,
        steps = move_result.steps,
        stopped_on_roadblock = move_result.stopped_on_roadblock == true,
        market_interrupt = move_result.market_interrupt and true or false,
        steal_interrupt = move_result.steal_interrupt and true or false,
      })
      return "wait_move_anim", {
        resume_state = "move",
        resume_args = {
          player = player,
          total = total,
          raw_total = raw_total,
          move_result = move_result,
        },
      }
    end
  else
    tm.game.last_turn.move_result = move_result
  end

  if move_result.stopped_on_roadblock then
    local stay = player.status.stay_turns or 0
    if stay < 1 then
      tm.game:set_player_status(player, "stay_turns", 1)
    end
  end

  if move_result.steal_interrupt then
    local interrupt = move_result.steal_interrupt
    local res = Steal.handle_pass_players(tm.game, player, interrupt.encountered_ids or {})
    if res and res.intent then
      _DispatchIntent(tm.game, res.intent)
    end
    if res and res.waiting then
      return "wait_choice", {
        resume_state = "move",
        resume_args = {
          player = player,
          continue_from_steal = true,
          remaining_steps = interrupt.remaining_steps,
          facing = interrupt.facing,
          branch_parity = interrupt.branch_parity,
          raw_total = raw_total,
        },
      }
    end
    if interrupt.remaining_steps and interrupt.remaining_steps > 0 then
      return "move", {
        player = player,
        continue_from_steal = true,
        remaining_steps = interrupt.remaining_steps,
        facing = interrupt.facing,
        branch_parity = interrupt.branch_parity,
        raw_total = raw_total,
      }
    end
    move_result.encountered_players = {}
  end

  if move_result.market_interrupt then
    local spec, intent = MarketManager.BuildChoiceSpec(player, tm.game)
    if spec then
      _DispatchIntent(tm.game, { kind = "need_choice", choice_spec = spec })
      return "wait_choice", {
        resume_state = "move",
        resume_args = {
          player = player,
          continue_from_market = true,
          remaining_steps = move_result.market_interrupt.remaining_steps,
          facing = move_result.market_interrupt.facing,
          branch_parity = move_result.market_interrupt.branch_parity,
          raw_total = raw_total,
        },
      }
    end
    if intent then
      local ui_port = assert(tm.game.ui_port, "missing game.ui_port")
      assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
      ui_port:push_popup(intent.payload)
    end
  end

  return "landing", { player = player, move_result = move_result }
end

return _PhaseMove
