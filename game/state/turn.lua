local flow = require("core.flow")
local logger = require("core.logger")
local landing_defs = require("cfg.LandingEffects")
local effect_pipeline = require("game.effect.pipeline")
local effect_runner = require("game.effect.runner")
local movement = require("game.move")
local market = require("game.shop")
local steal = require("game.item.handler.steal")
local intent_dispatcher = require("turn.intent")
local vehicle_feature = require("game.vehicle")
local state_player = require("game.state.player")

local turn = {}

local max_landing_depth = 10

---检查是否有动作动画
local function _has_action_anim(game)
  if not game or not game.turn then
    return false
  end
  if game.turn.action_anim then
    return true
  end
  local queue = game.turn.action_anim_queue
  return type(queue) == "table" and #queue > 0
end

---投骰子
local function _roll_dice(count, override_values, rng)
  local results = {}
  local total = 0
  if override_values and #override_values > 0 then
    for i = 1, count do
      local v = override_values[i] or override_values[#override_values]
      table.insert(results, v)
      total = total + v
    end
    return results, total
  end
  assert(rng and rng.next_int, "Dice.Roll requires rng")
  for _ = 1, count do
    local v = rng:next_int(1, 6)
    table.insert(results, v)
    total = total + v
  end
  return results, total
end

---解析着陆效果
local function _resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local game_ctx = effect_runner.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })

  local function handle_need_landing(out)
    if depth >= max_landing_depth then
      return out
    end
    local target_player = player
    if out.player_id then
      target_player = state_player.find_player_by_id(game, out.player_id)
    end
    local next_tile = nil
    if target_player then
      local idx = out.board_index or target_player.position
      if idx then
        next_tile = game.board:get_tile(idx)
      end
    end
    if next_tile then
      return _resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
  end

  return effect_pipeline.run(landing_defs, player, tile, game_ctx, {
    resume_state = "post_action",
    resume_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    on_need_landing = handle_need_landing,
  })
end

-- ========== 原有功能保留 ==========

local function _mark_turn(game)
  game.dirty.any = true
  game.dirty.turn = true
end

function turn.queue_action_anim(game, payload)
  assert(payload ~= nil, "missing action anim payload")
  local seq = (game.turn.action_anim_seq or 0) + 1
  payload.seq = seq
  game.turn.action_anim_seq = seq
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    queue = {}
    game.turn.action_anim_queue = queue
  end
  queue[#queue + 1] = payload
  if not game.turn.action_anim then
    game.turn.action_anim = table.remove(queue, 1)
  end
  _mark_turn(game)
  return payload
end

function turn.pending_choice(game)
  return game.turn.pending_choice
end

-- ========== Flow 状态函数 ==========

---回合开始状态
function turn.start(args)
  local game = require("game.init")
  local player = game:current_player()
  local turn_data = game.turn

  if not player then
    logger.error("[Eggy] 无法获取当前玩家")
    return flow.state.end_turn, { player = nil }
  end

  logger.info("[Eggy] 回合开始:", "player_id", tostring(player.id))

  game.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }

  -- 已出局玩家跳过
  if player.eliminated then
    game.last_turn.note = "已出局，跳过"
    game.last_turn.skipped = true
    return flow.state.end_turn, { player = player }
  end

  -- 更新回合数
  turn_data.turn_count = turn_data.turn_count + 1
  game.dirty.turn = true
  game.dirty.any = true

  -- 检查是否被扣留
  if player.status.stay_turns and player.status.stay_turns > 0 then
    state_player.set_player_status(game, player, "stay_turns", player.status.stay_turns - 1)
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    game.last_turn.note = "被扣留"
    game.last_turn.skipped = true
    game.last_turn.stay_turns = player.status.stay_turns
    turn_data.detained_wait_active = true
    turn_data.detained_wait_elapsed = 0
    turn_data.detained_wait_seconds = 5
    return flow.state.detained_wait, { player = player }
  end

  return flow.state.roll, { player = player }
end

---投骰子状态
function turn.roll(args)
  local game = require("game.init")
  local player = args and args.player or game:current_player()

  if not player then
    return flow.state.end_turn, {}
  end

  -- 检查是否有待处理的骰子值（遥控骰子）
  local override = nil
  if player.status.pending_remote_dice then
    override = player.status.pending_remote_dice.values
  end

  local dice_count = state_player.player_dice_count(game, player)
  local rolls, raw_total = _roll_dice(dice_count, override, game.rng)

  local total = raw_total
  if player.status.pending_dice_multiplier and player.status.pending_dice_multiplier > 1 then
    total = total * player.status.pending_dice_multiplier
  end

  logger.event(player.name .. " 投骰: [" .. table.concat(rolls, ",") .. "] => " .. total)
  game.last_turn.rolls = rolls
  game.last_turn.total = total
  game.last_turn.raw_total = raw_total

  -- 清除遥控骰子
  if player.status.pending_remote_dice then
    player.status.pending_remote_dice = nil
  end

  game.turn.phase = "roll"
  game.dirty.turn = true
  game.dirty.any = true

  return flow.state.move, { player = player, total = total, raw_total = raw_total }
end

---移动状态
function turn.move(args)
  local game = require("game.init")
  local player = args.player
  local total = args.total
  local raw_total = args.raw_total

  if not player then
    return flow.state.end_turn, {}
  end

  -- 处理倍数效果
  local pending_multiplier = player.status.pending_dice_multiplier
  if pending_multiplier and pending_multiplier > 1 then
    if raw_total ~= nil and total == raw_total then
      total = raw_total * pending_multiplier
    end
    state_player.set_player_status(game, player, "pending_dice_multiplier", 1)
    if game.last_turn then
      game.last_turn.total = total
    end
  end

  -- 执行移动
  local move_opts = { branch_parity = raw_total }
  if args.continue_from_market or args.continue_from_steal then
    total = args.remaining_steps
    move_opts.direction = args.facing
    move_opts.branch_parity = args.branch_parity
  end

  local start_index = player.position
  local move_result = movement.move(game, player, total, move_opts)
  game.last_turn.move_result = move_result

  -- 处理路障停留
  if move_result.stopped_on_roadblock then
    local stay = player.status.stay_turns or 0
    if stay < 1 then
      state_player.set_player_status(game, player, "stay_turns", 1)
    end
  end

  -- 处理偷窃中断
  if move_result.steal_interrupt then
    local interrupt = move_result.steal_interrupt
    local res = steal.handle_pass_players(game, player, interrupt.encountered_ids or {})
    if res and res.intent then
      intent_dispatcher.dispatch(game, res.intent)
    end
    if res and res.waiting then
      -- 存储恢复状态，等待玩家选择
      game._resume_state = flow.state.move
      game._resume_args = {
        player = player,
        continue_from_steal = true,
        remaining_steps = interrupt.remaining_steps,
        facing = interrupt.facing,
        branch_parity = interrupt.branch_parity,
        raw_total = raw_total,
      }
      return flow.state.wait_choice, { player = player }
    end
    if interrupt.remaining_steps and interrupt.remaining_steps > 0 then
      return flow.state.move, {
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

  -- 处理黑市中断
  if move_result.market_interrupt then
    local spec, intent = market.build_choice_spec(player, game)
    if spec then
      intent_dispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
      game._resume_state = flow.state.move
      game._resume_args = {
        player = player,
        continue_from_market = true,
        remaining_steps = move_result.market_interrupt.remaining_steps,
        facing = move_result.market_interrupt.facing,
        branch_parity = move_result.market_interrupt.branch_parity,
        raw_total = raw_total,
      }
      return flow.state.wait_choice, { player = player }
    end
    if intent then
      intent_dispatcher.dispatch(game, intent)
    end
  end

  return flow.state.landing, { player = player, move_result = move_result }
end

---着陆状态
function turn.landing(args)
  local game = require("game.init")
  local player = args.player
  local move_result = args.move_result

  if not player then
    return flow.state.end_turn, {}
  end

  local tile = game.board:get_tile(player.position)
  local res = _resolve_landing(game, player, tile, move_result)

  if res and res.waiting then
    game._resume_state = res.resume_state or flow.state.landing
    game._resume_args = res.resume_args or { player = player, move_result = move_result }
    if _has_action_anim(game) then
      return flow.state.wait_action_anim, { player = player }
    end
    return flow.state.wait_choice, { player = player }
  end

  if _has_action_anim(game) then
    return flow.state.wait_action_anim, { resume_state = flow.state.post_action, resume_args = { player = player } }
  end

  return flow.state.post_action, { player = player }
end

---行动后状态
function turn.post_action(args)
  local game = require("game.init")
  local player = args.player

  if not player then
    return flow.state.end_turn, {}
  end

  -- 清除临时状态标记
  state_player.clear_player_temporal_flags(game, player)

  return flow.state.end_turn, { player = player }
end

---回合结束状态
function turn.end_turn(args)
  local game = require("game.init")
  local player = args.player

  if player then
    logger.info("[Eggy] 回合结束:", tostring(player.name))
  end

  -- 停止所有玩家移动动画
  state_player.stop_all_players_movement(game)

  -- 切换到下一个玩家
  local current_idx = game.turn.current_player_index
  local count = #game.players
  local next_idx = current_idx % count + 1
  game.turn.current_player_index = next_idx
  game.dirty.turn = true
  game.dirty.any = true

  logger.info("[Eggy] 切换玩家:", "current", tostring(current_idx), "next", tostring(next_idx))

  return flow.state.start, {}
end

---等待选择状态
function turn.wait_choice(args)
  local game = require("game.init")

  -- 检查是否有 pending_action（玩家已提交选择）
  if game.pending_action then
    local action = game.pending_action
    game.pending_action = nil

    -- 处理选择结果
    if action.kind == "choice_made" then
      -- 恢复之前的状态
      local resume_state = game._resume_state or flow.state.start
      local resume_args = game._resume_args or {}
      game._resume_state = nil
      game._resume_args = nil
      return resume_state, resume_args
    end
  end

  -- 继续等待
  return flow.state.wait_choice, args
end

---等待移动动画状态
function turn.wait_move_anim(args)
  local game = require("game.init")

  -- 检查动画是否完成
  if not game.turn.move_anim then
    local resume_state = args and args.resume_state or flow.state.move
    local resume_args = args and args.resume_args or {}
    return resume_state, resume_args
  end

  return flow.state.wait_move_anim, args
end

---等待动作动画状态
function turn.wait_action_anim(args)
  local game = require("game.init")

  -- 检查动画队列
  if not _has_action_anim(game) then
    local resume_state = args and args.resume_state or flow.state.post_action
    local resume_args = args and args.resume_args or {}
    return resume_state, resume_args
  end

  return flow.state.wait_action_anim, args
end

---扣留等待状态（医院/监狱）
function turn.detained_wait(args)
  local game = require("game.init")
  local turn_data = game.turn

  if not turn_data.detained_wait_active then
    return flow.state.end_turn, args
  end

  -- 更新等待时间
  turn_data.detained_wait_elapsed = turn_data.detained_wait_elapsed + 1
  if turn_data.detained_wait_elapsed >= turn_data.detained_wait_seconds then
    turn_data.detained_wait_active = false
    return flow.state.end_turn, args
  end

  return flow.state.detained_wait, args
end

---加载所有状态到 flow
function turn.load_states()
  local states = {}
  for name, fn in pairs(turn) do
    if type(fn) == "function" and name ~= "load_states" and name ~= "queue_action_anim" and name ~= "pending_choice" then
      states[name] = fn
    end
  end
  flow.load(states)
end

return turn
