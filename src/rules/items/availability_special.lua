-- 特殊道具可用性判定(自 availability 拆出):目标类/租金响应类道具的候选解析
-- 与拒绝原因谓词。全部为纯查询,无状态;供 availability.can_offer_in_phase 组门。
local auto_play_port = require("src.rules.ports.auto_play")
local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local demolish = require("src.rules.items.demolish")
local roadblock = require("src.rules.items.roadblock")
local property_query = require("src.rules.board.property_query")
local property_value = require("src.rules.commerce.property_value")

local special = {}

local target_item_set = {}
for _, target_item_id in ipairs(effects.target_item_ids()) do
  target_item_set[target_item_id] = true
end

-- 租金响应类道具(强征/免费):无道具阶段窗口,可用性由租金上下文判定。
local RENT_RESPONSE_ITEM = {
  [item_ids.strong] = true,
  [item_ids.free_rent] = true,
}

local function _resolve_roadblock_candidates(game, player)
  if auto_play_port.is_computer_controlled(game, player) then
    return roadblock.auto_candidates(game, player, 3)
  end
  return roadblock.manual_candidates(game, player, 3)
end

local function _item_registry(game)
  local registries = game and game.registries or nil
  return registries and registries.items or nil
end

local function _has_target_candidates(registry)
  return type(registry) == "table" and type(registry.target_candidates) == "function"
end

local function _can_offer_target_item(game, player, item_id)
  local registry = _item_registry(game)
  if not _has_target_candidates(registry) then
    return false
  end
  local candidates = registry:target_candidates(game, player, item_id)
  return type(candidates) == "table" and #candidates > 0
end

local function _board_of(game)
  return game and game.board or nil
end

local function _player_position(player)
  return player and player.position or nil
end

local function _land_tile(board, player_position)
  local tile_ref = board and board:get_tile(player_position) or nil
  if tile_ref and tile_ref.type == "land" then
    return tile_ref
  end
  return nil
end

local function _resolve_rent_response_tile(game, player)
  return _land_tile(_board_of(game), _player_position(player))
end

local function _rent_total_invested(tile_ref, state)
  return property_value.total_invested(tile_ref, state and state.level or 0)
end

local function _resolve_rent_response_context(game, player)
  local tile_ref = _resolve_rent_response_tile(game, player)
  if tile_ref == nil then
    return nil
  end
  local owner, state = property_query.resolve_rent_owner(game, tile_ref)
  return {
    tile_ref = tile_ref,
    player_id = player and player.id or nil,
    owner = owner,
    state = state,
    total_value = _rent_total_invested(tile_ref, state),
  }
end

local function _is_rent_response_available(ctx)
  local owner = ctx and ctx.owner or nil
  return owner ~= nil and owner.id ~= ctx.player_id
end

local function _can_afford_strong_card(game, player, ctx)
  local total_value = assert(ctx and ctx.total_value, "missing rent response total value")
  return game:player_cash(player) >= total_value
end

local function _can_offer_rent_response(game, player, item_id)
  local ctx = _resolve_rent_response_context(game, player)
  if not _is_rent_response_available(ctx) then
    return false
  end
  if item_id ~= item_ids.strong then
    return true
  end
  -- #205:现金不足是独立拒绝原因,与「不站在对手地上」的无目标区分开。
  if not _can_afford_strong_card(game, player, ctx) then
    return false, "insufficient_funds"
  end
  return true
end

local function _can_offer_roadblock(game, player)
  local candidates = _resolve_roadblock_candidates(game, player)
  return type(candidates) == "table" and #candidates > 0
end

local function _can_offer_demolish(game, player)
  return demolish.find_target(game, player, 3) ~= nil
end

local function _can_offer_special_item(game, player, item_id)
  if item_id == item_ids.roadblock then
    return _can_offer_roadblock(game, player)
  end

  if item_id == item_ids.monster then
    return _can_offer_demolish(game, player)
  end

  if target_item_set[item_id] then
    return _can_offer_target_item(game, player, item_id)
  end

  -- 租金响应类道具(strong/free_rent)不在此处分支:rent_denial_reason 是唯一的
  -- 租金上下文门禁(#205 分类顺序),经条件门会让 rent 门禁的集合成员判定变成
  -- 可观测不到效用的冗余(变异幸存实锤)。
  return nil
end

-- 租金响应门禁:租金响应类道具先看租金上下文(无上下文=无目标;现金不足=独立
-- 原因,#205),非租金响应道具或上下文成立时返回 nil(放行)。
function special.rent_denial_reason(game, player, item_id)
  if not RENT_RESPONSE_ITEM[item_id] then
    return nil
  end
  local rent_offer, rent_reason = _can_offer_rent_response(game, player, item_id)
  if rent_offer then
    return nil
  end
  return rent_reason or "special_condition_failed"
end

-- 特殊条件门禁:特殊道具条件不成立时返回拒绝原因,否则 nil(放行)。
function special.condition_denial_reason(game, player, item_id)
  local special_offer, special_reason = _can_offer_special_item(game, player, item_id)
  if special_offer == nil or special_offer then
    return nil
  end
  return special_reason or "special_condition_failed"
end

return special

--[[ mutate4lua-manifest
version=4
projectHash=648abcda11f22df9
scope.0.id=chunk:src/rules/items/availability_special.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=164
scope.0.semanticHash=855035c9150b31d8
scope.1.id=function:_resolve_roadblock_candidates
scope.1.kind=function
scope.1.startLine=24
scope.1.endLine=29
scope.1.semanticHash=fa9c47844a77a2a9
scope.2.id=function:_item_registry
scope.2.kind=function
scope.2.startLine=31
scope.2.endLine=34
scope.2.semanticHash=93c839897afe61e5
scope.3.id=function:_has_target_candidates
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=38
scope.3.semanticHash=f44edaea74747a0d
scope.4.id=function:_can_offer_target_item
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=47
scope.4.semanticHash=41d99ab617875a81
scope.5.id=function:_board_of
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=51
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:_player_position
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=55
scope.6.semanticHash=616a2ca60599c94f
scope.7.id=function:_land_tile
scope.7.kind=function
scope.7.startLine=57
scope.7.endLine=63
scope.7.semanticHash=b505afe8bf6719d9
scope.8.id=function:_resolve_rent_response_tile
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=67
scope.8.semanticHash=9733108c88c00d07
scope.9.id=function:_rent_total_invested
scope.9.kind=function
scope.9.startLine=69
scope.9.endLine=71
scope.9.semanticHash=c72ae5c5c9cc0521
scope.10.id=function:_resolve_rent_response_context
scope.10.kind=function
scope.10.startLine=73
scope.10.endLine=86
scope.10.semanticHash=7e2271728378d47c
scope.11.id=function:_is_rent_response_available
scope.11.kind=function
scope.11.startLine=88
scope.11.endLine=91
scope.11.semanticHash=2a4493e2bef27675
scope.12.id=function:_can_afford_strong_card
scope.12.kind=function
scope.12.startLine=93
scope.12.endLine=96
scope.12.semanticHash=2ac392812d59eaf9
scope.13.id=function:_can_offer_rent_response
scope.13.kind=function
scope.13.startLine=98
scope.13.endLine=111
scope.13.semanticHash=b09f4af993c1b90c
scope.14.id=function:_can_offer_roadblock
scope.14.kind=function
scope.14.startLine=113
scope.14.endLine=116
scope.14.semanticHash=efde41f84de15c1d
scope.15.id=function:_can_offer_demolish
scope.15.kind=function
scope.15.startLine=118
scope.15.endLine=120
scope.15.semanticHash=fa6fbca96f362a29
scope.16.id=function:_can_offer_special_item
scope.16.kind=function
scope.16.startLine=122
scope.16.endLine=139
scope.16.semanticHash=26dbbdf15feda2e0
scope.17.id=function:special.rent_denial_reason
scope.17.kind=function
scope.17.startLine=143
scope.17.endLine=152
scope.17.semanticHash=6f408c4979355432
scope.18.id=function:special.condition_denial_reason
scope.18.kind=function
scope.18.startLine=155
scope.18.endLine=161
scope.18.semanticHash=9dc2dd7a5ae0f1b7
]]
