local effects = require("src.rules.items.post_effects")
local auto_play_port = require("src.rules.ports.auto_play")
local inventory = require("src.rules.items.inventory")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.foundation.ports.action_anim")
local use_broadcast = require("src.rules.items.use_broadcast")

local executor = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

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
  if not action_anim_port.is_enabled(game) then
    return res
  end
  if type(res) == "table" and res.action_anim then
    return res
  end
  local current_seq = game.turn and game.turn.action_anim_seq or 0
  if current_seq > before_seq then
    return res
  end
  action_anim_port.queue(game, {
    kind = "item_use",
    player_id = player.id,
    item_id = item_id,
    item_name = item_name,
    duration = action_anim_duration,
  })
  if type(res) == "table" then
    res.action_anim = true
    return res
  end
  return { ok = true, action_anim = true }
end

local function _finalize_use_item(game, player, item_id, item_name, before_seq, res)
  local final_res = _with_fallback_item_anim(game, player, item_id, item_name, before_seq, res)
  if _is_success_result(final_res) then
    use_broadcast.dispatch(game, player, item_id)
  end
  return final_res
end

function executor.use_item(game, player, item_id, context)
  context = context or {}
  if type(context.by_ai) == "nil" then
    context.by_ai = auto_play_port.is_auto_player(game, player)
  end
  local cfg = inventory.cfg(item_id)
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))
  local before_anim_seq = game.turn and game.turn.action_anim_seq or 0

  local registries = assert(game.registries, "missing game.registries")
  local registry = assert(registries.items, "missing item registry")
  local handler = registry.handlers[item_id]
  if handler then
    local res = handler(game, player, item_id, context)
    return _finalize_use_item(game, player, item_id, cfg.name, before_anim_seq, res)
  end

  local consumed = inventory.consume(player, item_id)
  assert(consumed == true, "item consume failed: " .. tostring(item_id))

  local res = effects.apply_post(game, player, item_id, context)
  assert(res ~= nil, "missing item post effect result: " .. tostring(item_id))
  return _finalize_use_item(game, player, item_id, cfg.name, before_anim_seq, res)
end

return executor

--[[ mutate4lua-manifest
version=2
projectHash=b833cf0ad68e5c11
scope.0.id=chunk:src/rules/items/executor.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=86
scope.0.semanticHash=9ebde87fe6ca3fe6
scope.1.id=function:_is_success_result:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=22
scope.1.semanticHash=4abb5dd81c48327d
scope.2.id=function:_with_fallback_item_anim:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=50
scope.2.semanticHash=7d5a39e3577d43fc
scope.3.id=function:_finalize_use_item:52
scope.3.kind=function
scope.3.startLine=52
scope.3.endLine=58
scope.3.semanticHash=df392092232d6173
scope.4.id=function:executor.use_item:60
scope.4.kind=function
scope.4.startLine=60
scope.4.endLine=83
scope.4.semanticHash=bdda0f783ff3fed7
]]
