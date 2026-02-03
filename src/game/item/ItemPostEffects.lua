local Logger = require("src.core.Logger")
local Constants = require("Config.Generated.Constants")
local BoardUtils = require("src.game.item.ItemBoardUtils")
local Inventory = require("src.game.item.ItemInventory")
local GameplayRules = require("Config.GameplayRules")
local BankruptcyManager = require("src.game.game.BankruptcyManager")

local ItemEffects = {}
local ITEM_IDS = GameplayRules.item_ids

local TARGET_ITEM_ORDER = {
  ITEM_IDS.share_wealth,
  ITEM_IDS.exile,
  ITEM_IDS.tax,
  ITEM_IDS.invite_deity,
  ITEM_IDS.send_poor,
  ITEM_IDS.poor,
}

local TARGET_EFFECTS = {
  [ITEM_IDS.share_wealth] = {
    apply = function(_, user, target, _context)
      local total = user.cash + target.cash
      local half = math.floor(total / 2)
      user:SetCash(half)
      target:SetCash(total - half)
      Logger.Event(user.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
      return true
    end,
  },
  [ITEM_IDS.exile] = {
    apply = function(game, user, target, context)
      local idx = game.board:FindFirstByType("mountain")
      if idx then
        game:UpdatePlayerPosition(target, idx)
      end
      game:SetPlayerStatus(target, "move_dir", nil)
      game:SetPlayerStatus(target, "stay_turns", Constants.mountain_stay_turns)
      Logger.Event(target.name .. " 进入深山，停留 " .. target.status.stay_turns .. " 回合")
      Logger.Event(user.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
      return true
    end,
  },
  [ITEM_IDS.tax] = {
    apply = function(game, user, target, context)
      if target:HasDeity("angel") then
        Logger.Event(target.name .. " 有天使，查税无效")
        return true
      end
      if Inventory.Consume(target, ITEM_IDS.tax_free) then
        Logger.Event(target.name .. " 使用免税卡抵消查税")
        return true
      end
      local fee = math.floor(target.cash * 0.5)
      target:DeductCash(fee)
      Logger.Event(user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. fee .. " 税金")
      if target.cash <= 0 then
        BankruptcyManager.Eliminate(game, target)
      end
      return true
    end,
  },
  [ITEM_IDS.invite_deity] = {
    filter_target = function(_, _, target)
      return target.status.deity and true or false
    end,
    apply = function(_, user, target, _context)
      local deity = assert(target.status.deity, "missing target deity")
      target:ClearDeity()
      user:SetDeity(deity.type, deity.remaining)
      Logger.Event(user.name .. " 使用请神卡，从 " .. target.name .. " 请走 " .. deity.type)
      return true
    end,
  },
  [ITEM_IDS.send_poor] = {
    require_user = function(user)
      if not user:HasDeity("poor") then
        return false
      end
      return true
    end,
    apply = function(_, user, target, _context)
      local remaining = assert(user.status.deity, "missing user deity").remaining
      target:SetDeity("poor", remaining)
      user:ClearDeity()
      Logger.Event(user.name .. " 使用送神卡，将穷神送给 " .. target.name)
      return true
    end,
  },
  [ITEM_IDS.poor] = {
    apply = function(_, user, target, _context)
      target:SetDeity("poor")
      Logger.Event(user.name .. " 使用穷神卡，" .. target.name .. " 穷神附身")
      return true
    end,
  },
}

local POST_EFFECTS = {

  [ITEM_IDS.free_rent] = { type = "set_status", key = "pending_free_rent", value = true, message = " 使用免费卡，下一次租金免除" },
  [ITEM_IDS.dice_multiplier] = { type = "set_status", key = "pending_dice_multiplier", value = 2, message = " 使用骰子加倍卡，本次步数翻倍" },
  [ITEM_IDS.tax_free] = { type = "set_status", key = "pending_tax_free", value = true, message = " 使用免税卡，本次征税免除" },


  [ITEM_IDS.mine] = { type = "place_mine_here" },
  [ITEM_IDS.clear_obstacles] = { type = "clear_obstacles_ahead", distance = 12 },


  [ITEM_IDS.steal] = { type = "log", message = " 准备偷窃（将在经过玩家时触发）" },
  [ITEM_IDS.strong] = { type = "log", message = " 准备使用强征卡（踩他人地块时触发）" },


  [ITEM_IDS.rich] = { type = "deity", deity = "rich", warn = "附身财神", log = " 使用财神卡，财神附身" },
  [ITEM_IDS.angel] = { type = "deity", deity = "angel", warn = "附身天使", log = " 使用天使卡，天使附身" },
}

local handlers = {}

local function _HandleSetStatus(game, player, cfg, _context)
  local value = assert(cfg.value, "missing status value")
  game:SetPlayerStatus(player, cfg.key, value)
  if cfg.message then
    Logger.Event(player.name .. cfg.message)
  end
  return true
end

local function _HandleDeity(game, player, cfg, context)
  player:SetDeity(cfg.deity, Constants.deity_duration_turns)
  Logger.Event(player.name .. " 获得附身：" .. cfg.deity)
  if cfg.log then
    Logger.Event(player.name .. cfg.log)
  end
  return true
end

local function _HandleLog(_, player, cfg, _context)
  assert(cfg.message ~= nil, "missing log message")
  Logger.Event(player.name .. cfg.message)
  return true
end

local function _HandlePlaceMineHere(game, player, _cfg, context)
  game.board:PlaceMine(player.position)
  Logger.Event(player.name .. " 在脚下埋设地雷")
  assert(game.ui_port ~= nil, "missing ui_port")
  if game.ui_port.wait_action_anim then
    game:QueueActionAnim({
      kind = "mine",
      player_id = player.id,
      tile_index = player.position,
    })
    return { ok = true, action_anim = true }
  end
  return true
end

local function _HandleClearObstaclesAhead(game, player, cfg, context)
  local board = game.board
  local cleared = 0
  local cleared_indices = {}
  local cleared_map = {}
  local current = player.position
  local distance = cfg.distance or 12
  assert(context ~= nil, "missing context")
  local parity = context.branch_parity or distance
  local facing = player.status.move_dir
  local map = assert(board.map, "missing board.map")
  local neighbors = assert(map.neighbors, "missing board.map.neighbors")
  local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }
  local start_tile = assert(board:GetTile(current), "missing start tile")
  local start_id = assert(start_tile.id, "missing start tile id")
  local queue = {}
  local visited = {}
  local function _Mark(tile_id, dir, depth)
    visited[tile_id] = visited[tile_id] or {}
    local key = dir or ""
    local prev = visited[tile_id][key]
    if prev and prev <= depth then
      return false
    end
    visited[tile_id][key] = depth
    return true
  end
  _Mark(start_id, facing, 0)
  table.insert(queue, { tile_id = start_id, facing = facing, depth = 0 })
  BoardUtils.QueueWalk(queue, function(node, push)
    if node.depth < distance then
      local neigh = assert(neighbors[node.tile_id], "missing neighbors: " .. tostring(node.tile_id))
      local back = OPPOSITE[node.facing]
      for dir, next_id in pairs(neigh) do
        if not back or dir ~= back then
          local next_index = assert(board:IndexOfTileId(next_id), "missing tile index: " .. tostring(next_id))
          if board:HasRoadblock(next_index) then
            board:ClearRoadblock(next_index)
            cleared = cleared + 1
            if not cleared_map[next_index] then
              cleared_map[next_index] = true
              cleared_indices[#cleared_indices + 1] = next_index
            end
          end
          if board:HasMine(next_index) then
            board:ClearMine(next_index)
            cleared = cleared + 1
            if not cleared_map[next_index] then
              cleared_map[next_index] = true
              cleared_indices[#cleared_indices + 1] = next_index
            end
          end
          if _Mark(next_id, dir, node.depth + 1) then
            push({ tile_id = next_id, facing = dir, depth = node.depth + 1 })
          end
        end
      end
    end
  end)
  Logger.Event(player.name .. " 清除前方障碍数：" .. cleared)
  assert(game.ui_port ~= nil, "missing ui_port")
  if game.ui_port.wait_action_anim then
    game:QueueActionAnim({
      kind = "clear_obstacles",
      player_id = player.id,
      cleared_indices = cleared_indices,
    })
    return { ok = true, action_anim = true }
  end
  return true
end

handlers.set_status = _HandleSetStatus
handlers.deity = _HandleDeity
handlers.log = _HandleLog
handlers.place_mine_here = _HandlePlaceMineHere
handlers.clear_obstacles_ahead = _HandleClearObstaclesAhead

function ItemEffects.GetTargetSpec(item_id)
  return TARGET_EFFECTS[item_id]
end

function ItemEffects.TargetItemIds()
  return TARGET_ITEM_ORDER
end

function ItemEffects.ApplyTarget(game, user, item_id, target, context)
  local spec = TARGET_EFFECTS[item_id]
  assert(spec ~= nil and spec.apply ~= nil, "missing target spec: " .. tostring(item_id))
  return spec.apply(game, user, target, context)
end

function ItemEffects.ApplyPost(game, player, item_id, context)
  context = context or {}
  local cfg = assert(POST_EFFECTS[item_id], "missing post effect: " .. tostring(item_id))
  local handler = assert(handlers[cfg.type], "missing post effect handler: " .. tostring(cfg.type))
  return handler(game, player, cfg, context)
end

return ItemEffects

