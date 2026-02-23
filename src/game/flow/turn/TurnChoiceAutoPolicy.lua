local agent = require("src.game.core.runtime.Agent")
local number_utils = require("src.core.NumberUtils")

local choice_auto_policy = {}

local function _resolve_choice_owner(game, choice)
  local meta = choice and choice.meta or {}
  if meta.player_id and game and game.find_player_by_id then
    local player = game:find_player_by_id(meta.player_id)
    if player then
      return player
    end
  end
  if game and game.current_player then
    return game:current_player()
  end
  return nil
end

local function _pick_first_choice_option(choice)
  local options = choice and choice.options or nil
  if type(options) ~= "table" then
    return nil
  end
  local first = options[1]
  if first == nil then
    return nil
  end
  return first.id or first
end

local function _build_auto_or_fallback_action(game, choice, allow_first_option_fallback)
  local auto_action = agent.auto_action_for_choice(game, choice)
  if auto_action then
    return auto_action
  end
  if not allow_first_option_fallback then
    return nil
  end
  local option_id = _pick_first_choice_option(choice)
  if option_id == nil then
    return nil
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
  }
end

function choice_auto_policy.resolve_choice_owner(game, choice)
  return _resolve_choice_owner(game, choice)
end

function choice_auto_policy.decide(game, state, choice, ctx)
  if not (choice and choice.id) then
    return nil
  end
  ctx = ctx or {}
  if ctx.pending_action then
    return ctx.pending_action
  end

  local mode = ctx.mode or "wait_choice"
  local actor = _resolve_choice_owner(game, choice)
  local is_auto_actor = actor and agent.is_auto_player(actor) or false
  local min_visible = ctx.min_visible_seconds
  if not number_utils.is_numeric(min_visible) or min_visible < 0 then
    min_visible = 0
  end
  local elapsed = ctx.elapsed_seconds
  if not number_utils.is_numeric(elapsed) or elapsed < 0 then
    elapsed = 0
  end

  if mode == "wait_choice" then
    if not is_auto_actor then
      return nil
    end
    if min_visible > 0 and elapsed < min_visible then
      return nil
    end
    return _build_auto_or_fallback_action(game, choice, false)
  end

  if mode == "tick_min_visible" then
    if not is_auto_actor then
      return nil
    end
    if min_visible > 0 and elapsed < min_visible then
      return nil
    end
    return _build_auto_or_fallback_action(game, choice, true)
  end

  if mode == "tick_timeout" then
    return _build_auto_or_fallback_action(game, choice, true)
  end

  return _build_auto_or_fallback_action(game, choice, ctx.allow_first_option_fallback == true)
end

return choice_auto_policy
