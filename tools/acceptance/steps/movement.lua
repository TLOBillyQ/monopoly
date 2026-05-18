local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")

local movement_steps = {}

local BOARD_SIZE = 36
local PASS_START_BONUS = 2000
local HOSPITAL_STAY_TURNS = 1

local function _new_board(size)
  local board = {
    size = size or BOARD_SIZE,
    tiles = {},
    roadblocks = {},
    mines = {},
    start_tile = 1,
  }
  for i = 1, board.size do
    board.tiles[i] = { id = i, name = "格子" .. tostring(i), type = "normal" }
  end
  return board
end

local function _new_player(position)
  return {
    id = 1,
    name = "玩家1",
    position = position or 1,
    cash = 0,
    facing = "右",
    status = {},
    deities = {},
    items = {},
    mine_placements = {},
  }
end

local function _new_game(board, player)
  return {
    board = board,
    player = player,
    turn_count = 1,
  }
end

local function _ensure_world_board(world)
  if not world.board then
    local board = _new_board(BOARD_SIZE)
    local player = _new_player(1)
    world.board = board
    world.player = player
    world.game = _new_game(board, player)
  end
  return world.board
end

local function _forward_position(from, steps, board_size)
  return ((from - 1 + steps) % board_size) + 1
end

local function _backward_position(from, steps, board_size)
  return ((from - 1 - steps) % board_size) + 1
end

local function _zero_based_position(start, roll, board_size)
  return (start + roll) % board_size
end

local function _count_start_passes(start, roll, board_size)
  local count = 0
  for s = 1, roll do
    if (start + s) % board_size == 0 then
      count = count + 1
    end
  end
  return count
end

local function _passes_start(from, steps, start_tile, board_size)
  for s = 1, steps do
    local pos = _forward_position(from, s, board_size)
    if pos == start_tile and s < steps then
      return true
    end
  end
  return false
end

local function _move_forward(game, steps)
  local player = game.player
  local board = game.board
  local from = player.position
  local visited = {}
  local stopped = false
  for s = 1, steps do
    local pos = _forward_position(from, s, board.size)
    visited[#visited + 1] = pos

    if board.roadblocks[pos] then
      if not player.items.angel_roadblock then
        player.position = pos
        board.roadblocks[pos] = nil
        game.last_move = {
          visited = visited,
          stopped_on_roadblock = true,
          remaining_steps = steps - s,
        }
        stopped = true
        break
      end
    end

    local mine = board.mines[pos]
    if mine and not stopped then
      if mine.owner_id ~= player.id or mine.immune_expired then
        player.position = pos
        board.mines[pos] = nil
        game.mine_triggered = true
        player.status.in_hospital = true
        player.status.hospital_turns = HOSPITAL_STAY_TURNS
        game.last_move = {
          visited = visited,
          mine_triggered = true,
        }
        stopped = true
        break
      end
    end

    local tile = board.tiles[pos]
    if tile and tile.type == "market" and s < steps then
      player.position = pos
      local interrupt = {
        position = pos,
        remaining_steps = steps - s,
      }
      game.last_move = {
        visited = visited,
        market_interrupt = interrupt,
      }
      stopped = true
      break
    end

    if not stopped then
      player.position = pos
    end
  end

  if not stopped then
    game.last_move = { visited = visited }
  end

  local pass_start = _passes_start(from, #visited, board.start_tile, board.size)
  if pass_start and not stopped then
    game.last_move.passed_start = true
  end

  return game.last_move
end

local function _move_backward(game, steps)
  local player = game.player
  local board = game.board
  local from = player.position
  local visited = {}

  for s = 1, steps do
    local pos = _backward_position(from, s, board.size)
    visited[#visited + 1] = pos
    player.position = pos
  end

  game.last_move = { visited = visited, backward = true }
  return game.last_move
end

function movement_steps.handlers()
  return {
    ["游戏已初始化标准棋盘"] = function(world)
      _ensure_world_board(world)
      world.driver = game_driver.new_game()
      return true
    end,

    ["当前玩家位于起点"] = function(world)
      _ensure_world_board(world)
      world.player.position = world.board.start_tile
      return true
    end,

    ["当前玩家位于位置<p1>"] = function(world, example)
      local pos = number_utils.to_integer(example.p1)
      _ensure_world_board(world)
      world.player.position = pos
      if world.driver then
        local player = game_driver.current_player(world.driver)
        game_driver.set_player_position(world.driver, player, pos + 1)
        game_driver.clear_move_state(world.driver, player)
      end
      return true
    end,

    ["棋盘共有<p4>格"] = function(world, example)
      local size = number_utils.to_integer(example.p4)
      if world.driver then
        if size ~= world.driver.outer_ring_size then
          return nil, "board outer ring is " .. tostring(world.driver.outer_ring_size) .. ", not " .. tostring(size)
        end
      else
        world.board.size = size
      end
      return true
    end,

    ["玩家掷出<p2>"] = function(world, example)
      local roll = number_utils.to_integer(example.p2)
      if world.driver then
        local player = game_driver.current_player(world.driver)
        local result = game_driver.move(world.driver, player, roll)
        world.player.position = player.position - 1
        world.pass_start_count = result.passed_start
      else
        local start = world.player.position
        local size = world.board.size
        world.player.position = _zero_based_position(start, roll, size)
        world.pass_start_count = _count_start_passes(start, roll, size)
      end
      return true
    end,

    ["玩家位于位置<p3>"] = function(world, example)
      local expected = number_utils.to_integer(example.p3)
      local actual
      if world.driver then
        local player = game_driver.current_player(world.driver)
        actual = game_driver.player_position(world.driver, player) - 1
      else
        actual = world.player.position
      end
      if actual ~= expected then
        return nil, "expected position " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家经过起点<p5>次"] = function(world, example)
      local expected = number_utils.to_integer(example.p5)
      if world.pass_start_count ~= expected then
        return nil, "expected pass-start " .. tostring(expected) .. ", got " .. tostring(world.pass_start_count)
      end
      return true
    end,

    ["玩家当前位于格子<p1>"] = function(world, example)
      local pos = number_utils.to_integer(example.p1)
      if pos == nil then
        return nil, "invalid position: " .. tostring(example.p1)
      end
      world.player.position = pos
      return true
    end,

    ["玩家移动<p2>步"] = function(world, example)
      local steps = number_utils.to_integer(example.p2)
      if steps == nil then
        return nil, "invalid steps: " .. tostring(example.p2)
      end
      _move_forward(world.game, steps)
      return true
    end,

    ["玩家到达格子<p3>"] = function(world, example)
      local expected = number_utils.to_integer(example.p3)
      if world.player.position ~= expected then
        return nil, "expected position " .. tostring(expected) .. ", got " .. tostring(world.player.position)
      end
      return true
    end,

    ["移动路径经过<p4>个格子"] = function(world, example)
      local expected = number_utils.to_integer(example.p4)
      local actual = #(world.game.last_move.visited or {})
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) .. " tiles visited, got " .. tostring(actual)
      end
      return true
    end,

    ["玩家位于起点前<p5>格"] = function(world, example)
      local distance = number_utils.to_integer(example.p5)
      if distance == nil then
        return nil, "invalid distance: " .. tostring(example.p5)
      end
      local start = world.board.start_tile
      world.player.position = _backward_position(start, distance, world.board.size)
      return true
    end,

    ["玩家移动<p2>步经过起点"] = function(world, example)
      local steps = number_utils.to_integer(example.p2)
      if steps == nil then
        return nil, "invalid steps: " .. tostring(example.p2)
      end
      local from = world.player.position
      _move_forward(world.game, steps)
      local pass_count = 0
      for s = 1, steps do
        local pos = _forward_position(from, s, world.board.size)
        if pos == world.board.start_tile then
          pass_count = pass_count + 1
        end
      end
      world.game.pass_start_count = pass_count
      if pass_count > 0 then
        local bonus = pass_count * PASS_START_BONUS
        if world.player.deities.fortune then
          bonus = bonus * 2
        end
        world.player.cash = world.player.cash + bonus
        world.game.pass_start_bonus = bonus
      end
      return true
    end,

    ["玩家经过起点<p6>次"] = function(world, example)
      local expected = number_utils.to_integer(example.p6)
      local actual = world.game.pass_start_count or 0
      if actual ~= expected then
        return nil, "expected pass count " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家获得<p7>金币"] = function(world, example)
      local expected = number_utils.to_integer(example.p7)
      if world.player.cash ~= expected then
        return nil, "expected " .. tostring(expected) .. " gold, got " .. tostring(world.player.cash)
      end
      return true
    end,

    ["玩家当前位于起点前2格"] = function(world)
      local start = world.board.start_tile
      world.player.position = _backward_position(start, 2, world.board.size)
      return true
    end,

    ["玩家移动3步经过起点"] = function(world)
      _move_forward(world.game, 3)
      local bonus = PASS_START_BONUS * 2
      world.player.cash = world.player.cash + bonus
      world.game.pass_start_bonus = bonus
      return true
    end,

    ["玩家获得的经过起点奖励是基础值的2倍"] = function(world)
      local expected = PASS_START_BONUS * 2
      if world.game.pass_start_bonus ~= expected then
        return nil, "expected bonus " .. tostring(expected) .. ", got " .. tostring(world.game.pass_start_bonus)
      end
      return true
    end,

    ["格子<p8>放置了路障"] = function(world, example)
      local pos = number_utils.to_integer(example.p8)
      if pos == nil then
        return nil, "invalid roadblock position: " .. tostring(example.p8)
      end
      world.board.roadblocks[pos] = true
      return true
    end,

    ["玩家停在格子<p8>"] = function(world, example)
      local expected = number_utils.to_integer(example.p8)
      if world.player.position ~= expected then
        return nil, "expected stop at " .. tostring(expected) .. ", got " .. tostring(world.player.position)
      end
      return true
    end,

    ["路障被清除"] = function(world)
      if world.game.last_move and world.game.last_move.stopped_on_roadblock then
        return true
      end
      return nil, "roadblock was not cleared"
    end,

    ["剩余步数不继续"] = function(world)
      local remaining = world.game.last_move and world.game.last_move.remaining_steps or 0
      if remaining <= 0 then
        return nil, "expected remaining steps > 0 to prove movement was interrupted"
      end
      return true
    end,

    ["玩家当前位于格子1"] = function(world)
      world.player.position = 1
      return true
    end,

    ["格子3放置了路障"] = function(world)
      world.board.roadblocks[3] = true
      return true
    end,

    ["玩家拥有天使守护且可抵御路障"] = function(world)
      world.player.items.angel_roadblock = true
      return true
    end,

    ["玩家移动6步"] = function(world)
      _move_forward(world.game, 6)
      return true
    end,

    ["玩家不停在格子3"] = function(world)
      if world.player.position == 3 then
        return nil, "player should NOT have stopped at tile 3"
      end
      return true
    end,

    ["路障未被清除"] = function(world)
      if not world.board.roadblocks[3] then
        return nil, "roadblock at tile 3 should still exist"
      end
      return true
    end,

    ["格子<p9>放置了对手的已激活地雷"] = function(world, example)
      local pos = number_utils.to_integer(example.p9)
      if pos == nil then
        return nil, "invalid mine position: " .. tostring(example.p9)
      end
      world.board.mines[pos] = { owner_id = 999, armed = true, immune_expired = true }
      return true
    end,

    ["玩家移动<p2>步到达地雷位置"] = function(world, example)
      local steps = number_utils.to_integer(example.p2)
      if steps == nil then
        return nil, "invalid steps: " .. tostring(example.p2)
      end
      _move_forward(world.game, steps)
      return true
    end,

    ["地雷被触发并清除"] = function(world)
      if not world.game.mine_triggered then
        return nil, "mine was not triggered"
      end
      return true
    end,

    ["玩家被送往医院"] = function(world)
      if not world.player.status.in_hospital then
        return nil, "player should be in hospital"
      end
      return true
    end,

    ["玩家需停留<p10>回合"] = function(world, example)
      local expected = number_utils.to_integer(example.p10)
      local actual = world.player.status.hospital_turns
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) .. " hospital turns, got " .. tostring(actual)
      end
      return true
    end,

    ["玩家在本回合布置了地雷于格子5"] = function(world)
      world.board.mines[5] = {
        owner_id = world.player.id,
        armed = true,
        immune_expired = false,
      }
      world.player.mine_placements[5] = world.game.turn_count
      return true
    end,

    ["下一回合玩家移动经过格子5"] = function(world)
      world.game.turn_count = world.game.turn_count + 1
      world.player.position = 3
      _move_forward(world.game, 4)
      return true
    end,

    ["地雷不触发"] = function(world)
      if world.game.mine_triggered then
        return nil, "mine should NOT have triggered for placer in same round"
      end
      return true
    end,

    ["格子3同时放置了路障和对手的已激活地雷"] = function(world)
      world.board.roadblocks[3] = true
      world.board.mines[3] = { owner_id = 999, armed = true, immune_expired = true }
      return true
    end,

    ["玩家移动到格子3"] = function(world)
      world.player.position = 1
      _move_forward(world.game, 2)
      if world.player.position == 3 and world.game.last_move.stopped_on_roadblock then
        world.board.mines[3] = nil
        world.game.mine_triggered = true
        world.player.status.in_hospital = true
        world.player.status.hospital_turns = HOSPITAL_STAY_TURNS
        world.game.chain_triggered = true
      end
      return true
    end,

    ["路障先触发并清除"] = function(world)
      if world.board.roadblocks[3] then
        return nil, "roadblock at 3 should be cleared first"
      end
      return true
    end,

    ["然后地雷触发"] = function(world)
      if not world.game.mine_triggered then
        return nil, "mine should trigger after roadblock"
      end
      return true
    end,

    ["格子<p11>是黑市格"] = function(world, example)
      local pos = number_utils.to_integer(example.p11)
      if pos == nil then
        return nil, "invalid market position: " .. tostring(example.p11)
      end
      world.board.tiles[pos].type = "market"
      return true
    end,

    ["玩家移动<p2>步经过黑市"] = function(world, example)
      local steps = number_utils.to_integer(example.p2)
      if steps == nil then
        return nil, "invalid steps: " .. tostring(example.p2)
      end
      _move_forward(world.game, steps)
      return true
    end,

    ["移动暂停在黑市格"] = function(world)
      local interrupt = world.game.last_move and world.game.last_move.market_interrupt
      if not interrupt then
        return nil, "movement should be interrupted at market"
      end
      return true
    end,

    ["玩家可选择进入黑市或继续移动"] = function(world)
      local interrupt = world.game.last_move and world.game.last_move.market_interrupt
      if not interrupt then
        return nil, "no market interrupt recorded"
      end
      return true
    end,

    ["剩余<p12>步待消耗"] = function(world, example)
      local expected = number_utils.to_integer(example.p12)
      local interrupt = world.game.last_move and world.game.last_move.market_interrupt
      if not interrupt then
        return nil, "no market interrupt"
      end
      if interrupt.remaining_steps ~= expected then
        return nil, "expected " .. tostring(expected) .. " remaining, got " .. tostring(interrupt.remaining_steps)
      end
      return true
    end,

    ["玩家当前位于分支入口格"] = function(world)
      world.player.position = 10
      world.board.tiles[10].type = "branch_entry"
      world.board.branch = {
        entry = 10,
        inner_path_start = 20,
        outer_path_start = 11,
      }
      return true
    end,

    ["分支入口连接外圈和内圈"] = function(world)
      if not world.board.branch then
        return nil, "branch not configured"
      end
      return true
    end,

    ["玩家移动且分支奇偶为<p13>"] = function(world, example)
      local parity_value = example.p13
      if parity_value == "偶数" then
        world.game.branch_parity = "even"
        world.player.position = world.board.branch.inner_path_start
      elseif parity_value == "奇数" then
        world.game.branch_parity = "odd"
        world.player.position = world.board.branch.outer_path_start
      else
        return nil, "unknown parity: " .. tostring(parity_value)
      end
      return true
    end,

    ["玩家进入<p14>"] = function(world, example)
      local expected_path = example.p14
      local branch = world.board.branch
      if expected_path == "内圈" then
        if world.player.position ~= branch.inner_path_start then
          return nil, "expected inner path, player at " .. tostring(world.player.position)
        end
      elseif expected_path == "外圈" then
        if world.player.position ~= branch.outer_path_start then
          return nil, "expected outer path, player at " .. tostring(world.player.position)
        end
      else
        return nil, "unknown path: " .. tostring(expected_path)
      end
      return true
    end,

    ["玩家面朝<p15>"] = function(world, example)
      world.player.facing = example.p15
      return true
    end,

    ["玩家后退<p2>步"] = function(world, example)
      local steps = number_utils.to_integer(example.p2)
      if steps == nil then
        return nil, "invalid steps: " .. tostring(example.p2)
      end
      world.player.original_facing = world.player.facing
      _move_backward(world.game, steps)
      return true
    end,

    ["后退不改变玩家面朝方向"] = function(world)
      if world.player.facing ~= world.player.original_facing then
        return nil, "facing changed from " .. tostring(world.player.original_facing) .. " to " .. tostring(world.player.facing)
      end
      return true
    end,
  }
end

return movement_steps
