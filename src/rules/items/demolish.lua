local logger = require("src.foundation.log")
local demolish_apply = require("src.rules.items.demolish_apply")
local demolish_choice = require("src.rules.items.demolish_choice")

local demolish = {}

demolish.find_target = demolish_choice.find_target
demolish.apply = demolish_apply.apply

local function _human_demolish_choice(game, player, distance, best_idx, opts)
  if opts.by_ai then
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
version=2
projectHash=c82cdc758fb11811
scope.0.id=chunk:src/rules/items/demolish.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=286
scope.0.semanticHash=13d6637d28f1130b
scope.0.lastMutatedAt=2026-06-01T12:34:35Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=53
scope.0.lastMutationKilled=52
scope.1.id=function:_try_destroy_building:20
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=34
scope.1.semanticHash=8df120f3a9e1cd85
scope.1.lastMutatedAt=2026-06-01T12:34:35Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=17
scope.1.lastMutationKilled=16
scope.2.id=function:_patch:80
scope.2.kind=function
scope.2.startLine=80
scope.2.endLine=84
scope.2.semanticHash=31f27cff06de3443
scope.2.lastMutatedAt=2026-06-01T12:34:35Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:anonymous@111:111
scope.3.kind=function
scope.3.startLine=111
scope.3.endLine=120
scope.3.semanticHash=ae21837dfbe18ed0
scope.4.id=function:demolish.find_target:109
scope.4.kind=function
scope.4.startLine=109
scope.4.endLine=126
scope.4.semanticHash=f0fa86808f6f4058
scope.4.lastMutatedAt=2026-06-01T12:34:35Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=survived
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=1
scope.5.id=function:_build_demolish_msg:128
scope.5.kind=function
scope.5.startLine=128
scope.5.endLine=143
scope.5.semanticHash=c6b02ed1d605950e
scope.5.lastMutatedAt=2026-06-01T12:34:35Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=17
scope.5.lastMutationKilled=17
scope.6.id=function:_apply_demolish_effects:145
scope.6.kind=function
scope.6.startLine=145
scope.6.endLine=159
scope.6.semanticHash=0593f5ba94d28982
scope.6.lastMutatedAt=2026-06-01T12:34:35Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=8
scope.6.lastMutationKilled=7
scope.7.id=function:_queue_demolish_anim:161
scope.7.kind=function
scope.7.startLine=161
scope.7.endLine=170
scope.7.semanticHash=d6a3b6fa35a1548e
scope.7.lastMutatedAt=2026-06-01T12:34:35Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:_handle_injure_result:172
scope.8.kind=function
scope.8.startLine=172
scope.8.endLine=185
scope.8.semanticHash=833ddf7d95d5034f
scope.8.lastMutatedAt=2026-06-01T12:34:35Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=7
scope.8.lastMutationKilled=7
scope.9.id=function:demolish.apply:187
scope.9.kind=function
scope.9.startLine=187
scope.9.endLine=201
scope.9.semanticHash=88e9666c8ee8c54a
scope.9.lastMutatedAt=2026-06-01T12:34:35Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=survived
scope.9.lastMutationSites=17
scope.9.lastMutationKilled=16
scope.10.id=function:_is_demolishable_tile:203
scope.10.kind=function
scope.10.startLine=203
scope.10.endLine=212
scope.10.semanticHash=ad48a3f725565c80
scope.10.lastMutatedAt=2026-06-01T12:34:35Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=survived
scope.10.lastMutationSites=13
scope.10.lastMutationKilled=12
scope.11.id=function:_push_option:219
scope.11.kind=function
scope.11.startLine=219
scope.11.endLine=224
scope.11.semanticHash=f4c3dd34eb25242f
scope.11.lastMutatedAt=2026-06-01T12:34:35Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=4
scope.11.lastMutationKilled=4
scope.12.id=function:demolish.use:263
scope.12.kind=function
scope.12.startLine=263
scope.12.endLine=283
scope.12.semanticHash=13d80163ce903b87
scope.12.lastMutatedAt=2026-06-01T12:34:35Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=12
scope.12.lastMutationKilled=12
]]
