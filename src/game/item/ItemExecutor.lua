local item_effects = require("src.game.item.ItemPostEffects")
local item_registry = require("src.game.item.ItemRegistry")
local agent = require("src.game.game.Agent")
local inventory = require("src.game.item.ItemInventory")

local executor = {}

local function _is_success_result(res)
  if type(res) == "table" then
    if res.waiting then
      return false
    end
    if type(res.ok) == "boolean" then
      return res.ok
    end
    return true
  end
  return res == true
end

local function _with_fallback_item_anim(game, player, item_id, item_name, before_seq, res)
  if not _is_success_result(res) then
    return res
  end
  local ui_port = game and game.ui_port
  if not (ui_port and ui_port.wait_action_anim) then
    return res
  end
  if type(res) == "table" and res.action_anim then
    return res
  end
  local current_seq = game.turn and game.turn.action_anim_seq or 0
  if current_seq > before_seq then
    return res
  end
  game:queue_action_anim({
    kind = "item_use",
    player_id = player.id,
    item_id = item_id,
    item_name = item_name,
    focus_target_player_id = player.id,
  })
  if type(res) == "table" then
    res.action_anim = true
    return res
  end
  return { ok = true, action_anim = true }
end

function executor.use_item(game, player, item_id, context)
  context = context or {}
  if type(context.by_ai) == "nil" then
    context.by_ai = agent.is_auto_player(player)
  end
  local cfg = inventory.cfg(item_id)
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))
  local before_anim_seq = game.turn and game.turn.action_anim_seq or 0

  local handler = item_registry.handlers[item_id]
  if handler then
    local res = handler(game, player, item_id, context)
    return _with_fallback_item_anim(game, player, item_id, cfg.name, before_anim_seq, res)
  end

  local consumed = inventory.consume(player, item_id)
  assert(consumed == true, "item consume failed: " .. tostring(item_id))

  local res = item_effects.apply_post(game, player, item_id, context)
  assert(res ~= nil, "missing item post effect result: " .. tostring(item_id))
  return _with_fallback_item_anim(game, player, item_id, cfg.name, before_anim_seq, res)
end

return executor



