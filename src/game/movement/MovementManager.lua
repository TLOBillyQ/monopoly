local Constants = require("Config.Generated.Constants")
local GameplayRules = require("Config.GameplayRules")
local Inventory = require("src.game.item.ItemInventory")
local MonopolyEvent = require("src.game.MonopolyEvents")

local MovementManager = {}
local ITEM_IDS = GameplayRules.item_ids

local function _EmitEvent(kind, payload)
  assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
  TriggerCustomEvent(kind, payload or {})
end

function MovementManager.Move(game, player, steps, opts)
  opts = opts or {}
  local abs_steps = steps < 0 and -steps or steps
  local branch_parity = opts.branch_parity or abs_steps
  local board = game.board
  local encountered = {}
  local visited = {}
  local pass_start = 0
  local stopped_on_roadblock = false
  local market_interrupt = nil
  local steal_interrupt = nil
  local current = player.position
  local start_tile = board:GetTile(current)
  local facing = opts.direction or player.status.move_dir
  local step_fn = board.StepForwardByFacing
  if steps < 0 then
    step_fn = board.StepBackwardByFacing
  end

  for step = 1, abs_steps do
    local next_index, passed, step_dir = step_fn(board, current, facing, branch_parity)
    pass_start = pass_start + passed
    facing = step_dir or facing
    current = next_index
    table.insert(visited, current)

    local others = game.occupants[current] or {}
    local encountered_step = {}
    for _, pid in ipairs(others) do
      if pid ~= player.id then
        table.insert(encountered_step, pid)
        table.insert(encountered, pid)
      end
    end

    if board:HasRoadblock(current) then
      board:ClearRoadblock(current)
      stopped_on_roadblock = true
      _EmitEvent(MonopolyEvent.movement.roadblock_hit, {
        player = player,
        tile = board:GetTile(current),
        text = player.name .. " 触发路障，停在 " .. board:GetTile(current).name,
      })
      break
    end

    if not opts.skip_steal_check and #encountered_step > 0 then
      local has_steal = Inventory.FindIndex(player, ITEM_IDS.steal)
      local remaining = abs_steps - step
      if has_steal and remaining > 0 then
        steal_interrupt = {
          position = current,
          remaining_steps = remaining,
          facing = facing,
          branch_parity = branch_parity,
          encountered_ids = encountered_step,
        }
        _EmitEvent(MonopolyEvent.movement.steal_interrupt, {
          player = player,
          encountered_ids = encountered_step,
          text = player.name .. " 经过玩家，触发偷窃中断",
        })
        break
      end
    end

    if steps > 0 and not opts.skip_market_check then
      local tile = board:GetTile(current)
      assert(tile ~= nil, "missing tile: " .. tostring(current))
      if tile.type == "market" and step < steps then
        market_interrupt = {
          position = current,
          remaining_steps = abs_steps - step,
          facing = facing,
          branch_parity = branch_parity,
        }
        _EmitEvent(MonopolyEvent.movement.market_interrupt, {
          player = player,
          remaining_steps = market_interrupt.remaining_steps,
          text = player.name .. " 经过黑市，剩余 " .. market_interrupt.remaining_steps .. " 步",
        })
        break
      end
    end
  end

  local landing_tile = board:GetTile(current)
  local function _TileLabel(tile, fallback_index)
    local name = tile.name
    if tile.row and tile.col then
      return name .. "（" .. tile.row .. "，" .. tile.col .. "）"
    end
    return name
  end
  _EmitEvent(MonopolyEvent.movement.moved, {
    player = player,
    from_tile = start_tile,
    to_tile = landing_tile,
    steps = steps,
    text = player.name .. " 从 " .. _TileLabel(start_tile, player.position) .. " 移动到 " .. _TileLabel(landing_tile, current),
  })

  if pass_start > 0 then
    local bonus = pass_start * Constants.pass_start_bonus
    player:AddCash(bonus)
    _EmitEvent(MonopolyEvent.movement.passed_start, {
      player = player,
      count = pass_start,
      bonus = bonus,
      text = player.name .. " 经过起点，获得 " .. bonus .. " 金币",
    })
  end

  game:UpdatePlayerPosition(player, current)

  game:SetPlayerStatus(player, "move_dir", facing)

  return {
    encountered_players = encountered,
    passed_start = pass_start,
    stopped_on_roadblock = stopped_on_roadblock,
    visited = visited,
    landing_tile = landing_tile,
    steps = steps,
    market_interrupt = market_interrupt,
    steal_interrupt = steal_interrupt,
  }
end

return MovementManager
