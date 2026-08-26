local logger = require("src.foundation.log")
local demolish_apply = require("src.rules.items.demolish_apply")
local demolish_choice = require("src.rules.items.demolish_choice")

local demolish = {}

demolish.find_target = demolish_choice.find_target
demolish.apply = demolish_apply.apply

local function _human_demolish_choice(game, player, distance, best_idx, opts)
  if opts.is_computer_controlled then
    return nil
  end
  return demolish_choice.build_human_choice(game, player, distance, best_idx, opts)
end

local function _consume_demolish_item(player, consume_fn, item_id)
  if consume_fn and not consume_fn(player, item_id) then
    return false
  end
  return true
end

local function _resolve_demolish_target(game, player, distance, opts)
  local best_idx = demolish.find_target(game, player, distance)
  if best_idx ~= nil then
    return best_idx
  end
  -- migrated as DEV: internal target-selection failure, not player-facing game fact
  logger.info((opts.title or "拆除类道具") .. " 无可用目标")
  return nil
end

local function _apply_demolish_target(game, player, distance, consume_fn, opts, best_idx)
  local choice = _human_demolish_choice(game, player, distance, best_idx, opts)
  if choice then
    return choice
  end

  if not _consume_demolish_item(player, consume_fn, opts.item_id) then
    return false
  end
  return demolish.apply(game, player, best_idx, opts)
end

function demolish.use(game, player, distance, consume_fn, opts)
  opts = opts or {}
  local best_idx = _resolve_demolish_target(game, player, distance, opts)
  if best_idx == nil then
    return false
  end
  return _apply_demolish_target(game, player, distance, consume_fn, opts, best_idx)
end

return demolish

--[[ mutate4lua-manifest
version=4
projectHash=a1c04671d71c7c34
scope.0.id=chunk:src/rules/items/demolish.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=f84e76b38e90c1e4
scope.1.id=function:_human_demolish_choice
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=15
scope.1.semanticHash=dacb63b1c7bde03d
scope.2.id=function:_consume_demolish_item
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=22
scope.2.semanticHash=cef2a4ce688ac3a7
scope.3.id=function:_resolve_demolish_target
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=32
scope.3.semanticHash=967fb2f5888de7c3
scope.4.id=function:_apply_demolish_target
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=44
scope.4.semanticHash=6920e0968d35e52c
scope.5.id=function:demolish.use
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=53
scope.5.semanticHash=796634d4f47ecfbe
]]
