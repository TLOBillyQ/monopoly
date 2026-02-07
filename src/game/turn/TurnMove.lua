local steal = require("src.game.item.ItemSteal")
local movement_manager = require("src.game.movement.MovementManager")
local market_manager = require("src.game.market.MarketManager")
local intent_dispatcher = require("src.game.intent.IntentDispatcher")

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
      intent_dispatcher.dispatch(tm.game, res.intent)
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
      intent_dispatcher.dispatch(tm.game, { kind = "need_choice", choice_spec = spec })
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
