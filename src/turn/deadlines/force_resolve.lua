-- Force-resolve: 三级兜底链，永远不返回 nil。choice 超时的"温柔跳过"最后防线。
-- 设计约束：本模块不 require turn.actions.action_dispatcher，避免 turn 子树内部循环。
-- dispatch 入口由调用方传入 dispatcher 闭包，或经由 game:advance_turn 与 game:dispatch_action 直接驱动。
local logger = require("src.foundation.log.logger")
local runtime_state = require("src.state.runtime")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local DeadlineService = require("src.turn.deadlines.service")

local M = {}

local function _resolve_modal_ports(state)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  if type(resolved) ~= "table" then
    return nil
  end
  return resolved.modal
end

local function _resolve_output_ports(state)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local output_ports = type(resolved) == "table" and resolved.output or nil
  if type(output_ports) == "table" then
    return output_ports
  end
  return require("src.turn.output.state_adapter")
end

local function _is_action_dispatchable(action)
  if type(action) ~= "table" then
    return false
  end
  return action.type == "choice_select" or action.type == "choice_cancel"
end

local function _ensure_actor_role_id(game, choice, action)
  if action.actor_role_id ~= nil then
    return
  end
  local owner = choice and choice.owner_role_id or nil
  if owner ~= nil then
    action.actor_role_id = owner
    return
  end
  local current = game and game.turn and game.turn.current_player_index or nil
  local player = current and game.players and game.players[current] or nil
  if player then
    action.actor_role_id = player.id
  end
end

local function _dispatch_via_close_choice(game, state, action)
  -- 直接走 game:dispatch_action（reducer 会处理 choice_select/choice_cancel），
  -- 同时手动清空 pending_choice 避免 choice_wait 协程留态。
  if game and type(game.dispatch_action) == "function" then
    pcall(function() game:dispatch_action(action) end)
  end
  if game and game.turn then
    local pending = game.turn.pending_choice
    if not pending or pending.id ~= action.choice_id then
      game.turn.pending_choice = nil
    end
  end
  local modal_ports = _resolve_modal_ports(state)
  if modal_ports and type(modal_ports.close_choice_modal) == "function" then
    pcall(modal_ports.close_choice_modal, state)
  end
  if type(state) == "table" then
    local output_ports = _resolve_output_ports(state)
    if output_ports and type(output_ports.clear_pending_choice) == "function" then
      pcall(output_ports.clear_pending_choice, state)
    end
  end
end

local function _refund_preconsume(state, choice)
  -- 退还预消耗：当前 preconsume 实现把消耗记在 player.inventory 已扣，
  -- 这里通过 choice.meta 还原回去；handler 层在 cancel 时也会做一次，但
  -- force_skip 走捷径不进 handler，需就地处理。
  if type(choice) ~= "table" or type(choice.meta) ~= "table" then
    return
  end
  if choice.meta.item_preconsumed ~= true then
    return
  end
  local item_id = choice.meta.item_id
  local owner_id = choice.owner_role_id
  if item_id == nil or owner_id == nil then
    return
  end
  local game = state and state._game or nil
  -- 静默：force_skip 主路径不强求 refund 完整；后续走 cancel handler 时若仍有预消耗会被处理。
  -- 这里仅在显式存在 helper 时尝试。
  local ok, helper = pcall(require, "src.rules.choice.item_preconsume_policy")
  if ok and type(helper) == "table" and type(helper.refund) == "function" then
    pcall(helper.refund, game, choice)
  end
end

local function _emit_force_skip_event(reason, choice)
  local ok, monopoly_events = pcall(require, "src.foundation.events")
  if ok and type(monopoly_events) == "table" and type(monopoly_events.emit) == "function" then
    pcall(monopoly_events.emit, "fb.choice_force_skipped", {
      reason = reason or "tick_timeout",
      choice_id = choice and choice.id or nil,
      kind = choice and choice.kind or nil,
    })
  end
  logger.info("[Eggy]", "choice_force_skipped",
    "reason=" .. tostring(reason),
    "choice_id=" .. tostring(choice and choice.id or nil),
    "kind=" .. tostring(choice and choice.kind or nil))
end

function M.force_skip(game, state, choice, reason)
  -- 不可失败的最后防线：清空 pending、退还预消耗、复位 UI、推进 turn。
  if type(state) == "table" then
    state._choice_force_skip_pending = true
  end
  if game and game.turn then
    game.turn._choice_force_skip_pending = true
  end
  _refund_preconsume(state, choice)
  if type(state) == "table" then
    state._item_phase_ask_active = nil
    local output_ports = _resolve_output_ports(state)
    if output_ports and type(output_ports.clear_pending_choice) == "function" then
      pcall(output_ports.clear_pending_choice, state)
    end
  end
  if game and game.turn then
    game.turn.pending_choice = nil
  end
  -- 取消所有相关 deadline，避免被复用
  if type(state) == "table" then
    DeadlineService.cancel(state, "choice")
    DeadlineService.cancel(state, "market_buy")
    DeadlineService.cancel(state, "target_select")
    DeadlineService.cancel(state, "modal_popup")
  end
  _emit_force_skip_event(reason, choice)
  if game and not game.finished and type(game.advance_turn) == "function" then
    pcall(function() game:advance_turn() end)
  end
end

local function _try_choice_auto(game, state, choice)
  local elapsed = 0
  if type(state) == "table" then
    local entry = DeadlineService.peek(state, choice and choice.kind == "market_buy" and "market_buy" or "choice")
    if entry then
      elapsed = entry.elapsed_seconds or 0
    else
      elapsed = runtime_state.get_pending_choice_elapsed(state) or 0
    end
  end
  return choice_auto_policy.decide(game, state, choice, {
    mode = "tick_timeout",
    elapsed_seconds = elapsed,
    min_visible_seconds = 0,
    allow_first_option_fallback = true,
  })
end

function M.resolve_choice(game, state, choice, reason)
  if type(choice) ~= "table" or choice.id == nil then
    -- 无 choice 直接 force_skip
    M.force_skip(game, state, choice, reason or "no_choice")
    return
  end
  -- L1: 现有 choice_auto 逻辑
  local action = _try_choice_auto(game, state, choice)
  if _is_action_dispatchable(action) then
    _ensure_actor_role_id(game, choice, action)
    _dispatch_via_close_choice(game, state, action)
    return
  end
  -- L2: fallback_registry
  if action == nil or (type(action) == "table" and action.type == "choice_force_skip") then
    local kind = choice.kind
    local fb_action = fallback_registry.resolve(kind, game, choice)
    if _is_action_dispatchable(fb_action) then
      if fb_action.choice_id == nil then
        fb_action.choice_id = choice.id
      end
      _ensure_actor_role_id(game, choice, fb_action)
      _dispatch_via_close_choice(game, state, fb_action)
      return
    end
  end
  -- L3: 兜底 force_skip
  M.force_skip(game, state, choice, reason or "tick_timeout")
end

function M.resolve_target_select(game, state, target_ctx, reason)
  -- 道具目标选择超时：复位 _item_phase_ask_active 并取消 pending_choice
  -- 当前 choice 链路与 choice 同结构（都是 pending_choice），共用 force_skip 即可。
  local choice = nil
  if type(target_ctx) == "table" then
    choice = target_ctx.choice
  end
  if choice == nil and game and game.turn then
    choice = game.turn.pending_choice
  end
  M.force_skip(game, state, choice, reason or "target_select_timeout")
end

return M
