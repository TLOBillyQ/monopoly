local IntentDispatcher = require("src.util.intent_dispatcher")

local function phase_move(tm, args)
  local player = args.player
  local total = args.total
  local raw_total = args.raw_total
  local movement = tm.game and tm.game.services and tm.game.services.movement
  assert(movement and movement.move, "Missing MovementService (game.services.movement)")

  local move_opts = { branch_parity = raw_total }
  -- 支持从黑市中断后继续移动
  if args.continue_from_market then
    total = args.remaining_steps
    move_opts.direction = args.facing
    move_opts.branch_parity = args.branch_parity
  end

  local move_result = movement.move(tm.game, player, total, move_opts)
  tm.game.last_turn.move_result = move_result

  -- 经过黑市时中断，弹出购买选择
  if move_result.market_interrupt then
    local market = tm.game.services and tm.game.services.market
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
