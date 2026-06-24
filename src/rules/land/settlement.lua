local effect_pipeline = require("src.rules.effects.pipeline")
local effect_runner = require("src.rules.effects.runner")
local intent_output_port = require("src.rules.ports.intent_output")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local land_actions = require("src.rules.land.actions")
local landing_defs = require("src.rules.land.landing_defs")
local pricing = require("src.rules.land.pricing")
local tables = require("src.foundation.tables")

local settlement = {}

local max_landing_depth = 10

local function _is_relocation_action_anim(entry)
  return entry and (entry.kind == "move_effect" or entry.kind == "teleport_effect" or entry.kind == "forced_relocation")
end

local function _has_pending_relocation_action_anim(game)
  if not (game and game.turn) then
    return false
  end
  local current = game.turn.action_anim
  if _is_relocation_action_anim(current) then
    return true
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if _is_relocation_action_anim(entry) then
      return true
    end
  end
  return false
end

local function _resolve_actor(game, actor_id)
  if not (game and type(game.find_player_by_id) == "function") then
    return nil
  end
  return game:find_player_by_id(actor_id)
end

local function _resolve_tile(game, actor, context)
  context = context or {}
  if context.tile ~= nil then
    return context.tile
  end
  local board = game and game.board or nil
  if board == nil then
    return nil
  end
  if context.tile_id ~= nil and type(board.get_tile_by_id) == "function" then
    return board:get_tile_by_id(context.tile_id)
  end
  local index = context.board_index or (actor and actor.position)
  if index ~= nil and type(board.get_tile) == "function" then
    return board:get_tile(index)
  end
  return nil
end

local function _build_game_ctx(game, move_result, phase_default)
  return effect_runner.build_game_ctx(game, move_result, {
    phase_default = phase_default or "landing",
    on_landing = true,
  })
end

local function _landing_optional_cost(effect_id, tile, game)
  if effect_id ~= "upgrade_land" or tile == nil or game == nil then
    return nil
  end
  local st = land_actions.safe_tile_state(game, tile)
  return pricing.upgrade_cost(tile, (st and st.level) or 0)
end

local function _settled()
  return {
    ok = true,
    status = "settled",
    settled = true,
  }
end

local function _reject(reason)
  return {
    ok = false,
    status = "rejected",
    reason = reason,
  }
end

local function _with_ok(result)
  if type(result) == "table" and result.ok == nil then
    result.ok = true
  end
  return result
end

local function _find_effect_by_id(effect_id)
  for _, effect_definition in ipairs(landing_defs) do
    if effect_definition.id == effect_id then
      return effect_definition
    end
  end
  return nil
end

local function _option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

local function _option_is_offered(choice, option_id)
  if choice == nil or option_id == nil then
    return false
  end
  for _, option in ipairs(choice.options or {}) do
    local current = _option_id(option)
    if current == option_id or tostring(current) == tostring(option_id) then
      return true
    end
  end
  return false
end

local function _build_move_followup_result(target_player, out, wait_key)
  return {
    ok = true,
    waiting = true,
    reason = "followup_landing_wait",
    [wait_key] = true,
    next_state = "move_followup",
    next_args = {
      mode = "resolve_landing",
      player_id = target_player.id,
      move_result = out.move_result,
    },
  }
end

local _begin_resolved_landing

local function _resolve_target_player(game, fallback_player, out)
  if out.player_id == nil then
    return fallback_player
  end
  return _resolve_actor(game, out.player_id)
end

local function _resolve_next_tile(game, target_player, out)
  if target_player == nil then
    return nil
  end
  local board_index = out.board_index or target_player.position
  if board_index == nil or not (game and game.board) then
    return nil
  end
  return game.board:get_tile(board_index)
end

local function _resolve_followup_landing(game, player, out, depth)
  if depth >= max_landing_depth then
    local rejected = _reject("landing_depth_exceeded")
    rejected.followup = out
    return rejected
  end

  local target_player = _resolve_target_player(game, player, out)
  local next_tile = _resolve_next_tile(game, target_player, out)
  if next_tile == nil then
    return out
  end
  if out.wait_move_anim == true then
    return _build_move_followup_result(target_player, out, "wait_move_anim")
  end
  if _has_pending_relocation_action_anim(game) then
    return _build_move_followup_result(target_player, out, "wait_action_anim")
  end
  return _begin_resolved_landing(game, target_player, next_tile, {
    move_result = out.move_result,
  }, depth + 1)
end

local function _should_stop_landing_result(out)
  return type(out) == "table" and (out.ok == false or out.status == "rejected" or out.kind == "need_landing")
end

function _begin_resolved_landing(game, player, tile, context, depth)
  context = context or {}
  depth = depth or context.depth or 0

  local game_ctx = _build_game_ctx(game, context.move_result, "landing")
  local function handle_need_landing(out)
    return _resolve_followup_landing(game, player, out, depth)
  end

  local result = effect_pipeline.run(landing_defs, player, tile, game_ctx, {
    next_state = "post_action",
    next_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    optional_cost_resolver = _landing_optional_cost,
    on_need_landing = handle_need_landing,
    stop_if = _should_stop_landing_result,
  })
  return _with_ok(result) or _settled()
end

function settlement.begin_landing_settlement(game, actor_id, context)
  if game == nil then
    return _reject("missing_game")
  end
  local actor = _resolve_actor(game, actor_id)
  if actor == nil then
    return _reject("missing_actor")
  end
  local tile = _resolve_tile(game, actor, context)
  if tile == nil then
    return _reject("missing_tile")
  end
  return _begin_resolved_landing(game, actor, tile, context or {}, (context or {}).depth or 0)
end

local function _resolve_landing_optional_effect(game, choice, action)
  local effect_id = action and action.option_id or nil
  if effect_id == nil or effect_id == "" then
    return _reject("missing_landing_option")
  end
  local meta = choice and choice.meta or nil
  if type(meta) ~= "table" then
    return _reject("missing_landing_choice_meta")
  end
  if meta.effect_ids and not tables.contains(meta.effect_ids, effect_id) then
    return _reject("landing_option_not_offered")
  end
  if not _option_is_offered(choice, effect_id) then
    return _reject("landing_option_not_offered")
  end

  local target_effect = _find_effect_by_id(effect_id)
  if target_effect == nil then
    return _reject("landing_effect_not_found")
  end

  local player = _resolve_actor(game, meta.player_id)
  if player == nil then
    return _reject("missing_actor")
  end
  local tile = _resolve_tile(game, player, { tile_id = meta.tile_id })
  if tile == nil then
    return _reject("missing_tile")
  end

  local result = effect_runner.execute(target_effect, player, tile, _build_game_ctx(game, meta.move_result, "wait_choice"))
  intent_output_port.dispatch(game, result.result or result)
  if result.ok ~= true then
    return _reject(result.reason or "landing_effect_blocked")
  end
  return {
    ok = true,
    status = "resolved",
    effect_id = effect_id,
    result = result.result,
  }
end

local function _resolve_rent_card_prompt(game, choice, action)
  local meta = choice and choice.meta or nil
  if type(meta) ~= "table" then
    return _reject("missing_landing_choice_meta")
  end
  local player_id = meta.player_id
  local tile_id = meta.tile_id
  local card_kind = meta.card_kind
  local use_card = action and action.option_id == "use"

  if use_card and card_kind == "strong" then
    land_actions.execute_strong_card(game, player_id, tile_id)
  elseif use_card and card_kind == "free" then
    land_actions.execute_free_card(game, player_id, tile_id)
  else
    if card_kind == "strong" then
      local player = _resolve_actor(game, player_id)
      if player == nil then
        return _reject("missing_actor")
      end
      if inventory.find_index(player, item_ids.free_rent) then
        land_actions.execute_free_card(game, player_id, tile_id)
        return { ok = true, status = "resolved", effect_id = "free_rent" }
      end
    end
    land_actions.execute_pay_rent(game, player_id, tile_id)
  end

  return { ok = true, status = "resolved", effect_id = "pay_rent" }
end

local function _resolve_tax_card_prompt(game, choice, action)
  local meta = choice and choice.meta or nil
  if type(meta) ~= "table" then
    return _reject("missing_landing_choice_meta")
  end
  local player_id = meta.player_id
  local use_card = action and action.option_id == "use"

  if use_card then
    land_actions.execute_tax_free_card(game, player_id)
    return { ok = true, status = "resolved", effect_id = "tax_free" }
  end

  land_actions.execute_pay_tax(game, player_id)
  return { ok = true, status = "resolved", effect_id = "pay_tax" }
end

function settlement.resolve_landing_settlement_choice(game, choice, action)
  local kind = choice and choice.kind or nil
  if kind == "landing_optional_effect" then
    return _resolve_landing_optional_effect(game, choice, action)
  end
  if kind == "rent_card_prompt" then
    return _resolve_rent_card_prompt(game, choice, action)
  end
  if kind == "tax_card_prompt" then
    return _resolve_tax_card_prompt(game, choice, action)
  end
  return _reject("not_landing_choice")
end

settlement._M_test = {
  _has_pending_relocation_action_anim = _has_pending_relocation_action_anim,
  _option_is_offered = _option_is_offered,
}

return settlement
