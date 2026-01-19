local IntentDispatcher = require("src.util.intent_dispatcher")
local Steal = require("src.gameplay.item_steal")

local function phase_move(tm, args)
  local player = args.player
  local total = args.total
  local raw_total = args.raw_total
  local movement = tm.game and tm.game.get_service and tm.game:get_service("movement")

  local move_opts = { branch_parity = raw_total }
  if args.continue_from_market or args.continue_from_steal then
    total = args.remaining_steps
    move_opts.direction = args.facing
    move_opts.branch_parity = args.branch_parity
  end

  local move_result = movement.move(tm.game, player, total, move_opts)
  tm.game.last_turn.move_result = move_result

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
      IntentDispatcher.dispatch(tm.game, res.intent)
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
    local market = tm.game and tm.game.get_service and tm.game:get_service("market")
    if market then
      local spec, intent = market.build_choice_spec(player)
      if spec then
        IntentDispatcher.dispatch(tm.game, { kind = "need_choice", choice_spec = spec })
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
      elseif intent then
        local ui_port = tm.game and tm.game.ui_port
        if ui_port and ui_port.push_popup then
          ui_port:push_popup(intent.payload)
        end
      end
    end
  end

  return "landing", { player = player, move_result = move_result }
end

return phase_move