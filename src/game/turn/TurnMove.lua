local steal = require("src.game.item.ItemSteal")
local monopoly_event = require("src.game.game.MonopolyEvents")
local movement_manager = require("src.game.movement.MovementManager")
local market_manager = require("src.game.market.MarketManager")

local function _dispatch_intent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game ~= nil and game.store ~= nil, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:get({ "turn", "choice_seq" }) or 0
    seq = seq + 1
    game.store:set({ "turn", "choice_seq" }, seq)
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
    game.store:set({ "turn", "pending_choice" }, entry)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = monopoly_event.resolve_intent("need_choice")
    TriggerCustomEvent(event_name, { choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = monopoly_event.resolve_intent("push_popup")
    TriggerCustomEvent(event_name, { payload = intent.payload })
  end
end

local function _phase_move(tm, args)
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
    move_result = movement_manager.move(tm.game, player, total, move_opts)
    tm.game.last_turn.move_result = move_result

    local game = tm.game
    local store = assert(game.store, "missing game.store")
    local ui_port = assert(game.ui_port, "missing game.ui_port")
    if ui_port.wait_move_anim == true then
      local seq = (store:get({ "turn", "move_anim_seq" }) or 0) + 1
      store:set({ "turn", "move_anim_seq" }, seq)
      store:set({ "turn", "move_anim" }, {
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
    local res = steal.handle_pass_players(tm.game, player, interrupt.encountered_ids or {})
    if res and res.intent then
      _dispatch_intent(tm.game, res.intent)
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
    local spec, intent = market_manager.build_choice_spec(player, tm.game)
    if spec then
      _dispatch_intent(tm.game, { kind = "need_choice", choice_spec = spec })
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

return _phase_move
