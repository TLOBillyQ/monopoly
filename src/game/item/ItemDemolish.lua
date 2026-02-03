local Logger = require("src.core.Logger")
local Tile = require("src.game.board.Tile")
local BoardUtils = require("src.game.item.ItemBoardUtils")
local Constants = require("Config.Generated.Constants")

local Demolish = {}

local list_unpack = table.unpack or unpack

local function _ClearOverlays(game, idx)
  assert(game ~= nil, "missing game")
  assert(game.board ~= nil and game.board.ClearAll ~= nil, "missing board.ClearAll")
  game.board:ClearAll(idx)
end

local function _DestroyBuilding(game, tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for demolish")
  game:SetTileLevel(tile, 0)
end

local tile_state = Tile.GetState

local function _SendPlayersToHospital(game, idx)
  local occupants = assert(game.occupants[idx], "missing occupants: " .. tostring(idx))

  local hospital_index = assert(game.board:FindFirstByType("hospital"), "missing hospital")

  local count = 0
  local snapshot = { list_unpack(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = assert(game.players[pid], "missing target player: " .. tostring(pid))
    if target:IsVehicleIndestructible() then
      Logger.Event(target.name .. " 座驾免疫导弹效果")
    else
      game:SetPlayerSeat(target, nil)
      game:UpdatePlayerPosition(target, hospital_index)
      game:SetPlayerStatus(target, "move_dir", nil)
      game:SetPlayerStatus(target, "stay_turns", Constants.hospital_stay_turns)
      Logger.Event(target.name .. " 被炸伤送往医院，需停留 " .. Constants.hospital_stay_turns .. " 回合")
      count = count + 1
    end
  end
  return count
end

function Demolish.FindTarget(game, player, distance)
  local idx, value = BoardUtils.FindBestTile(game, player, distance, {
    score_fn = function(tile)
      if tile.type ~= "land" then
        return -1
      end
      local st = tile_state(game, tile)
      if not st.owner_id or st.owner_id == player.id or (st.level or 0) <= 0 then
        return -1
      end
      return BoardUtils.TotalInvested(tile, st.level)
    end,
  })
  if value < 0 then
    return nil
  end
  return idx
end

function Demolish.Apply(game, player, idx, opts)
  opts = opts or {}
  _ClearOverlays(game, idx)
  local tile = assert(game.board:GetTile(idx), "missing tile: " .. tostring(idx))

  _DestroyBuilding(game, tile)

  local hit = 0
  if opts.injure then
    hit = _SendPlayersToHospital(game, idx)
  end

  local msg
  if opts.injure then
    msg = player.name .. " 发射导弹轰炸 " .. tile.name
    if tile.type == "land" then
       msg = msg .. "，建筑被摧毁"
    end
    if hit > 0 then
      msg = msg .. "，" .. hit .. " 名玩家送医"
    end
  else
    msg = player.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑"
  end

  Logger.Event(msg)

  local kind = "monster"
  if opts.injure then
    kind = "missile"
  end
  local queued = false
  assert(game.ui_port ~= nil, "missing ui_port")
  if game.ui_port.wait_action_anim then
    game:QueueActionAnim({
      kind = kind,
      player_id = player.id,
      tile_index = idx,
      item_id = opts.item_id,
    })
    queued = true
  end
  return { ok = true, action_anim = queued }
end

function Demolish.Use(game, player, distance, consume_fn, opts)
  opts = opts or {}
  local best_idx = Demolish.FindTarget(game, player, distance)
  assert(best_idx ~= nil, "missing demolish target")

  if not opts.by_ai then
    local idxs = BoardUtils.IndicesInRange(game.board, player.position, distance)
    local options = {}
    local body_lines = {}

    local function _PushOption(idx)
      if idx and idx ~= player.position then
        local tile = game.board:GetTile(idx)
        if tile.type == "land" then
          local st = tile_state(game, tile)
          if st.owner_id and st.owner_id ~= player.id and st.level > 0 then
            table.insert(body_lines, "#" .. idx .. " " .. tile.name)
            table.insert(options, { id = idx, label = tile.name })
          end
        end
      end
    end

    for _, idx in ipairs(idxs) do
       _PushOption(idx)
    end

    if #options == 0 then
       _PushOption(best_idx)
    end

    if #options > 0 then
      local title = opts.title or "选择目标"
      return {
        waiting = true,
        intent = {
          kind = "need_choice",
          choice_spec = {
            kind = "demolish_target",
            title = title .. "：选择目标格子",
            body_lines = body_lines,
            options = options,
            allow_cancel = true,
            cancel_label = "取消",
            meta = {
              player_id = player.id,
              item_id = opts.item_id,
              injure = opts.injure,
              title = opts.title
            },
          },
        },
      }
    end
  end

  if consume_fn and not consume_fn(player, opts.item_id) then
    return false
  end
  return Demolish.Apply(game, player, best_idx, opts)
end

return Demolish


