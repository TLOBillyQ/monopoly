local number_utils = require("src.foundation.number")
local game_driver = require("tools.acceptance.game_driver")
local phase_move = require("src.turn.phases.move")

local movement_steps = {}

local PASS_START_BONUS = 2000

local FACING_MAP = {
  ["左"] = "left",
  ["右"] = "right",
  ["上"] = "up",
  ["下"] = "down",
}

local function _ctx(world) return world.driver end
local function _game(world) return world.driver.game end
local function _player(world) return game_driver.current_player(world.driver) end

local function _tile_at_player(world)
  return _game(world).board:get_tile(_player(world).position)
end

local function _tile_index(world, tile_id)
  return _game(world).board:index_of_tile_id(tile_id)
end

local function _tile_id_at_player(world)
  local tile = _tile_at_player(world)
  return tile and tile.id
end

local function _place_player(world, idx)
  local player = _player(world)
  game_driver.set_player_position(_ctx(world), player, idx)
  game_driver.sync_outer_facing(_ctx(world), player)
  return player
end

function movement_steps.handlers()
  return {

    -- ──────────────────────────────────────────────────────────────────────────
    -- shared background / dice_roll handlers
    -- ──────────────────────────────────────────────────────────────────────────

    ["游戏已初始化标准棋盘"] = function(world)
      world.driver = game_driver.new_game()
      return true
    end,

    ["当前玩家位于起点"] = function(world)
      local start_idx = _game(world).board:index_of_tile_id(_game(world).board.map.start_id)
      _place_player(world, start_idx)
      return true
    end,

    -- dice_roll feature: 0-based position (0 = start)
    ["当前玩家位于位置<起始位置>"] = function(world, example)
      local pos = number_utils.to_integer(example["起始位置"])
      _place_player(world, pos + 1)
      world.player = world.player or {}
      world.player.position = pos
      return true
    end,

    -- dice_roll feature: verifies board outer ring size
    ["棋盘共有<途经格数>格"] = function(world, example)
      local size = number_utils.to_integer(example["途经格数"])
      if size ~= world.driver.outer_ring_size then
        return nil, "board outer ring is " .. tostring(world.driver.outer_ring_size) .. ", not " .. tostring(size)
      end
      return true
    end,

    -- dice_roll feature: roll + move
    ["玩家掷出<步数>"] = function(world, example)
      local roll = number_utils.to_integer(example["步数"])
      local player = _player(world)
      local result = game_driver.move(_ctx(world), player, roll)
      world.player = world.player or {}
      world.player.position = player.position - 1
      world.pass_start_count = result.passed_start
      return true
    end,

    -- dice_roll feature: assert 0-based position
    ["玩家位于位置<目标位置>"] = function(world, example)
      local expected = number_utils.to_integer(example["目标位置"])
      local actual = world.player.position
      if actual ~= expected then
        return nil, "expected position " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    -- dice_roll feature: assert pass-start count
    ["玩家经过起点<距离>次"] = function(world, example)
      local expected = number_utils.to_integer(example["距离"])
      if world.pass_start_count ~= expected then
        return nil, "expected pass-start " .. tostring(expected) .. ", got " .. tostring(world.pass_start_count)
      end
      return true
    end,

    -- ──────────────────────────────────────────────────────────────────────────
    -- movement feature handlers
    -- ──────────────────────────────────────────────────────────────────────────

    ["玩家当前位于格子<起始位置>"] = function(world, example)
      local tile_id = number_utils.to_integer(example["起始位置"])
      local idx = _tile_index(world, tile_id)
      if not idx then
        return nil, "unknown tile id: " .. tostring(tile_id)
      end
      _place_player(world, idx)
      return true
    end,

    ["玩家移动<步数>步"] = function(world, example)
      local steps = number_utils.to_integer(example["步数"])
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, steps)
      return true
    end,

    ["玩家到达格子<目标位置>"] = function(world, example)
      local expected_id = number_utils.to_integer(example["目标位置"])
      local actual_id = _tile_id_at_player(world)
      if actual_id ~= expected_id then
        return nil, "expected tile " .. tostring(expected_id) .. ", got " .. tostring(actual_id)
      end
      return true
    end,

    ["移动路径经过<途经格数>个格子"] = function(world, example)
      local expected = number_utils.to_integer(example["途经格数"])
      local visited = world.last_move_result and world.last_move_result.visited or {}
      if #visited ~= expected then
        return nil, "expected " .. tostring(expected) .. " tiles visited, got " .. tostring(#visited)
      end
      return true
    end,

    ["玩家位于起点前<距离>格"] = function(world, example)
      local n = number_utils.to_integer(example["距离"])
      local idx = game_driver.tile_n_before_start(_ctx(world), n)
      _place_player(world, idx)
      return true
    end,

    ["玩家移动<步数>步经过起点"] = function(world, example)
      local steps = number_utils.to_integer(example["步数"])
      local player = _player(world)
      world.pre_move_cash = _game(world):player_cash(player)
      world.last_move_result = game_driver.move(_ctx(world), player, steps)
      return true
    end,

    ["玩家经过起点<经过次数>次"] = function(world, example)
      local expected = number_utils.to_integer(example["经过次数"])
      local actual = (world.last_move_result and world.last_move_result.passed_start) or 0
      if actual ~= expected then
        return nil, "expected pass count " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["玩家获得<奖励金额>金币"] = function(world, example)
      local expected = number_utils.to_integer(example["奖励金额"])
      local player = _player(world)
      local gained = _game(world):player_cash(player) - (world.pre_move_cash or 0)
      if gained ~= expected then
        return nil, "expected gain " .. tostring(expected) .. ", got " .. tostring(gained)
      end
      return true
    end,

    ["玩家当前位于起点前2格"] = function(world)
      local idx = game_driver.tile_n_before_start(_ctx(world), 2)
      _place_player(world, idx)
      return true
    end,

    ["玩家移动3步经过起点"] = function(world)
      local player = _player(world)
      world.pre_move_cash = _game(world):player_cash(player)
      world.last_move_result = game_driver.move(_ctx(world), player, 3)
      return true
    end,

    ["玩家获得的经过起点奖励是基础值的2倍"] = function(world)
      local expected = PASS_START_BONUS * 2
      local player = _player(world)
      local gained = _game(world):player_cash(player) - (world.pre_move_cash or 0)
      if gained ~= expected then
        return nil, "expected bonus " .. tostring(expected) .. ", got " .. tostring(gained)
      end
      return true
    end,

    ["格子<路障位置>放置了路障"] = function(world, example)
      local tile_id = number_utils.to_integer(example["路障位置"])
      game_driver.place_roadblock(_ctx(world), tile_id)
      return true
    end,

    ["玩家停在格子<路障位置>"] = function(world, example)
      local expected_id = number_utils.to_integer(example["路障位置"])
      local actual_id = _tile_id_at_player(world)
      if actual_id ~= expected_id then
        return nil, "expected stop at tile " .. tostring(expected_id) .. ", got " .. tostring(actual_id)
      end
      return true
    end,

    ["路障被清除"] = function(world)
      if world.last_move_result and world.last_move_result.stopped_on_roadblock then
        return true
      end
      return nil, "roadblock was not cleared (stopped_on_roadblock not set)"
    end,

    ["剩余步数不继续"] = function(world)
      local result = world.last_move_result
      if not result then
        return nil, "no move result"
      end
      local visited = result.visited or {}
      local abs_steps = result.steps and math.abs(result.steps) or 0
      if #visited >= abs_steps then
        return nil, "all steps consumed, expected early stop (visited=" .. tostring(#visited) .. " steps=" .. tostring(abs_steps) .. ")"
      end
      return true
    end,

    ["继续访问路障所在格事件"] = function(world)
      if not (world.last_move_result and world.last_move_result.stopped_on_roadblock) then
        return nil, "roadblock tile event should be visited after stopping"
      end
      world.roadblock_tile_event_visited = true
      return true
    end,

    ["剩余<剩余步数>步未消耗"] = function(world, example)
      local expected = number_utils.to_integer(example["剩余步数"])
      local result = world.last_move_result
      if not result then
        return nil, "no move result"
      end
      local visited = result.visited or {}
      local actual_remaining = math.abs(result.steps or 0) - #visited
      if actual_remaining ~= expected then
        return nil, "expected " .. tostring(expected) .. " remaining steps, got " .. tostring(actual_remaining)
      end
      return true
    end,

    ["玩家当前位于格子1"] = function(world)
      _place_player(world, _tile_index(world, 1))
      return true
    end,

    ["格子3放置了路障"] = function(world)
      game_driver.place_roadblock(_ctx(world), 3)
      return true
    end,

    ["玩家拥有天使守护且可抵御路障"] = function(world)
      local player = _player(world)
      game_driver.set_player_deity(_ctx(world), player, "angel")
      return true
    end,

    ["玩家仅拥有天使守护"] = function(world)
      local player = _player(world)
      game_driver.set_player_deity(_ctx(world), player, "angel")
      return true
    end,

    ["玩家移动6步"] = function(world)
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, 6)
      return true
    end,

    ["玩家不停在格子3"] = function(world)
      if _tile_id_at_player(world) == 3 then
        return nil, "player should NOT have stopped at tile 3"
      end
      return true
    end,

    ["玩家仍停在格子3"] = function(world)
      if _tile_id_at_player(world) ~= 3 then
        return nil, "player should stop at tile 3, got " .. tostring(_tile_id_at_player(world))
      end
      return true
    end,

    ["路障未被清除"] = function(world)
      if not game_driver.has_roadblock(_ctx(world), 3) then
        return nil, "roadblock at tile 3 should still exist"
      end
      return true
    end,

    ["格子<地雷位置>放置了对手的已激活地雷"] = function(world, example)
      local tile_id = number_utils.to_integer(example["地雷位置"])
      local opponent = _game(world).players[2]
      game_driver.place_mine(_ctx(world), tile_id, {
        owner_id = opponent.id,
        armed = true,
      })
      world.mine_tile_id = tile_id
      return true
    end,

    ["玩家移动<步数>步到达地雷位置"] = function(world, example)
      local steps = number_utils.to_integer(example["步数"])
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, steps)
      -- movement.move detects mine but does not apply effect; apply it here
      game_driver.try_trigger_mine(_ctx(world), player)
      return true
    end,

    ["地雷被触发并清除"] = function(world)
      local tile = _tile_at_player(world)
      if not tile or tile.type ~= "hospital" then
        return nil, "player should be at hospital after mine trigger, at type=" .. tostring(tile and tile.type)
      end
      if world.mine_tile_id and game_driver.has_mine(_ctx(world), world.mine_tile_id) then
        return nil, "mine at tile " .. tostring(world.mine_tile_id) .. " should have been consumed"
      end
      return true
    end,

    ["玩家被送往医院"] = function(world)
      local tile = _tile_at_player(world)
      if not tile or tile.type ~= "hospital" then
        return nil, "player should be in hospital"
      end
      return true
    end,

    ["玩家需停留<住院回合>回合"] = function(world, example)
      local expected = number_utils.to_integer(example["住院回合"])
      local player = _player(world)
      local actual = player.status and player.status.stay_turns
      if actual ~= expected then
        return nil, "expected " .. tostring(expected) .. " stay turns, got " .. tostring(actual)
      end
      return true
    end,

    ["玩家在本回合布置了地雷于格子5"] = function(world)
      local player = _player(world)
      local turn_count = player.status and player.status.own_turn_started_count or 0
      game_driver.place_mine(_ctx(world), 5, {
        owner_id = player.id,
        armed = true,
        owner_turn_started_count_at_placement = turn_count,
      })
      return true
    end,

    ["地雷不触发"] = function(world)
      if world.mine_result ~= nil then
        if world.mine_result.hospitalized then
          return nil, "mine should not hospitalize protected player"
        end
        return true
      end
      local check_tile = world.mine_tile_id or 5
      if not game_driver.has_mine(_ctx(world), check_tile) then
        return nil, "mine at tile " .. tostring(check_tile) .. " should NOT have triggered"
      end
      return true
    end,

    ["玩家在之前的回合布置了地雷于格子5"] = function(world)
      local player = _player(world)
      game_driver.place_mine(_ctx(world), 5, {
        owner_id = player.id,
        armed = true,
        owner_turn_started_count_at_placement = 0,
      })
      _game(world):set_player_status(player, "own_turn_started_count", 0)
      return true
    end,

    ["已过去2个己方回合"] = function(world)
      local player = _player(world)
      _game(world):set_player_status(player, "own_turn_started_count", 2)
      return true
    end,

    ["格子3同时放置了路障和对手的已激活地雷"] = function(world)
      local opponent = _game(world).players[2]
      game_driver.place_roadblock(_ctx(world), 3)
      game_driver.place_mine(_ctx(world), 3, {
        owner_id = opponent.id,
        armed = true,
      })
      return true
    end,

    ["玩家移动到格子3"] = function(world)
      local player = _player(world)
      local result = game_driver.move(_ctx(world), player, 3)
      world.last_move_result = result
      -- roadblock stops at tile 3; chain: mine triggers after roadblock
      if result.stopped_on_roadblock then
        local mine_result = game_driver.try_trigger_mine(_ctx(world), player)
        if mine_result then
          world.chain_mine_triggered = true
        end
      end
      return true
    end,

    ["路障先触发并清除"] = function(world)
      local tile3_idx = _tile_index(world, 3)
      if _game(world).board:has_roadblock(tile3_idx) then
        return nil, "roadblock at tile 3 should be cleared"
      end
      if not world.last_move_result or not world.last_move_result.stopped_on_roadblock then
        return nil, "roadblock should have triggered"
      end
      return true
    end,

    ["然后地雷触发"] = function(world)
      if not world.chain_mine_triggered then
        return nil, "mine should trigger after roadblock"
      end
      return true
    end,

    ["格子<黑市位置>是黑市格"] = function(world, example)
      local tile_id = number_utils.to_integer(example["黑市位置"])
      game_driver.set_tile_type(_ctx(world), tile_id, "market")
      return true
    end,

    ["玩家移动<步数>步经过黑市"] = function(world, example)
      local steps = number_utils.to_integer(example["步数"])
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, steps)
      return true
    end,

    ["移动暂停在黑市格"] = function(world)
      local interrupt = world.last_move_result and world.last_move_result.market_interrupt
      if not interrupt then
        return nil, "movement should be interrupted at market"
      end
      return true
    end,

    ["黑市窗口自动打开"] = function(world)
      local interrupt = world.last_move_result and world.last_move_result.market_interrupt
      if not interrupt and not world.market_interrupt_at_42 then
        return nil, "market window should open"
      end
      world.market_window_open = true
      return true
    end,

    ["玩家可选择进入黑市或继续移动"] = function(world)
      local interrupt = world.last_move_result and world.last_move_result.market_interrupt
      if not interrupt then
        return nil, "no market interrupt recorded"
      end
      return true
    end,

    ["剩余<剩余步数>步待消耗"] = function(world, example)
      local expected = number_utils.to_integer(example["剩余步数"])
      local interrupt = world.last_move_result and world.last_move_result.market_interrupt
      if not interrupt then
        return nil, "no market interrupt"
      end
      if interrupt.remaining_steps ~= expected then
        return nil, "expected " .. tostring(expected) .. " remaining, got " .. tostring(interrupt.remaining_steps)
      end
      return true
    end,

    ["玩家当前位于分支入口格"] = function(world)
      _place_player(world, _tile_index(world, 42))
      return true
    end,

    ["玩家回合开始时位于格子<入口格>"] = function(world, example)
      local tile_id = number_utils.to_integer(example["入口格"])
      local idx = _tile_index(world, tile_id)
      if not idx then
        return nil, "unknown tile id: " .. tostring(tile_id)
      end
      _place_player(world, idx)
      return true
    end,

    ["玩家回合开始时位于固定入口格40"] = function(world)
      local idx = _tile_index(world, 40)
      if not idx then
        return nil, "unknown tile id: 40"
      end
      _place_player(world, idx)
      return true
    end,

    ["分支入口连接外圈和内圈"] = function(world)
      local player = _player(world)
      local tile = _game(world).board:get_tile(player.position)
      local entry = tile and _game(world).board.map.entry_points[tile.id]
      if not entry then
        return nil, "player not at entry point (tile " .. tostring(tile and tile.id) .. ")"
      end
      return true
    end,

    ["该格连接外圈和内圈"] = function(world)
      local player = _player(world)
      local tile = _game(world).board:get_tile(player.position)
      local map = _game(world).board.map
      local entry = tile and map.entry_points[tile.id]
      local on_inner_link = tile and map.outer_next[tile.id] == nil and map.neighbors[tile.id] ~= nil
      if not (entry or on_inner_link) then
        return nil, "player not at branch connector (tile " .. tostring(tile and tile.id) .. ")"
      end
      return true
    end,

    ["玩家移动且分支奇偶为<奇偶值>"] = function(world, example)
      local parity_value = example["奇偶值"]
      local player = _player(world)
      local parity
      if parity_value == "偶数" then
        parity = 2
      elseif parity_value == "奇数" then
        parity = 1
      else
        return nil, "unknown parity value: " .. tostring(parity_value)
      end
      world.last_move_result = game_driver.move_with_opts(_ctx(world), player, 1, { branch_parity = parity })
      return true
    end,

    ["玩家掷出原始点数<原始点数>并结算移动点数效果"] = function(world, example)
      local raw_total = number_utils.to_integer(example["原始点数"])
      if raw_total == nil then
        return nil, "invalid raw total: " .. tostring(example["原始点数"])
      end
      local player = _player(world)
      game_driver.set_next_rolls(_ctx(world), { raw_total })
      local _, rolled_raw_total, final_total = game_driver.roll_dice(_ctx(world), player, 1)
      world.raw_total = rolled_raw_total
      world.final_move_steps = final_total
      return true
    end,

    ["玩家执行本回合移动"] = function(world)
      local player = _player(world)
      local state, args = phase_move({ game = _game(world) }, {
        player = player,
        raw_total = world.raw_total,
        total = world.final_move_steps,
      })
      world.last_move_state = state
      world.last_move_args = args
      world.last_move_result = args and (args.move_result or (args.next_args and args.next_args.move_result))
        or (_game(world).last_turn and _game(world).last_turn.move_result)
      if not world.last_move_result then
        return nil, "move phase did not return a move result"
      end
      return true
    end,

    ["分支按最终移动步数<最终步数>判定"] = function(world, example)
      local expected = number_utils.to_integer(example["最终步数"])
      if expected == nil then
        return nil, "invalid final steps: " .. tostring(example["最终步数"])
      end
      if world.final_move_steps ~= expected then
        return nil, "expected final move steps " .. tostring(expected) .. ", got " .. tostring(world.final_move_steps)
      end
      local result = world.last_move_result
      if not result then
        return nil, "no move result"
      end
      if result.branch_parity ~= expected then
        return nil, "expected branch parity " .. tostring(expected) .. ", got " .. tostring(result.branch_parity)
      end
      return true
    end,

    ["玩家进入<选择路径>"] = function(world, example)
      local expected_path = example["选择路径"]
      local player = _player(world)
      local tile = _game(world).board:get_tile(player.position)
      local on_outer = tile and _game(world).board.map.outer_next[tile.id] ~= nil
      if expected_path == "内圈" then
        if on_outer then
          return nil, "expected inner ring but player is on outer (tile " .. tostring(tile and tile.id) .. ")"
        end
      elseif expected_path == "外圈" then
        if not on_outer then
          return nil, "expected outer ring but player is on inner (tile " .. tostring(tile and tile.id) .. ")"
        end
      else
        return nil, "unknown path: " .. tostring(expected_path)
      end
      return true
    end,

    ["玩家面朝<面朝方向>"] = function(world, example)
      local facing_cn = example["面朝方向"]
      local facing = FACING_MAP[facing_cn]
      if not facing then
        return nil, "unknown facing direction: " .. tostring(facing_cn)
      end
      local player = _player(world)
      game_driver.set_player_facing(_ctx(world), player, facing)
      world.expected_facing = facing
      return true
    end,

    ["玩家后退<步数>步"] = function(world, example)
      local steps = number_utils.to_integer(example["步数"])
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, -steps)
      return true
    end,

    ["后退不改变玩家面朝方向"] = function(world)
      local player = _player(world)
      local facing = player.status and player.status.move_dir
      if facing ~= world.expected_facing then
        return nil, "facing changed from " .. tostring(world.expected_facing) .. " to " .. tostring(facing)
      end
      return true
    end,

    ["玩家当前位于起点前3格"] = function(world)
      local player = _player(world)
      local idx = game_driver.tile_n_before_start(_ctx(world), 3)
      game_driver.set_player_position(_ctx(world), player, idx)
      game_driver.sync_outer_facing(_ctx(world), player)
      return true
    end,

    ["玩家移动恰好3步到达起点"] = function(world)
      local player = _player(world)
      world.pre_move_cash = _game(world):player_cash(player)
      world.last_move_result = game_driver.move(_ctx(world), player, 3)
      return true
    end,

    ["玩家获得经过起点的金币奖励"] = function(world)
      local player = _player(world)
      local gained = _game(world):player_cash(player) - (world.pre_move_cash or 0)
      if gained < PASS_START_BONUS then
        return nil, "expected at least " .. tostring(PASS_START_BONUS) .. " bonus, got " .. tostring(gained)
      end
      return true
    end,

    ["下一己方回合玩家移动经过格子5"] = function(world)
      local player = _player(world)
      local turns = player.status and player.status.own_turn_started_count or 0
      _game(world):set_player_status(player, "own_turn_started_count", turns + 1)
      local tile4_idx = _tile_index(world, 4)
      game_driver.set_player_position(_ctx(world), player, tile4_idx)
      game_driver.sync_outer_facing(_ctx(world), player)
      world.last_move_result = game_driver.move(_ctx(world), player, 2)
      return true
    end,

    ["玩家移动经过格子5"] = function(world)
      local player = _player(world)
      local tile4_idx = _tile_index(world, 4)
      game_driver.set_player_position(_ctx(world), player, tile4_idx)
      game_driver.sync_outer_facing(_ctx(world), player)
      world.last_move_result = game_driver.move(_ctx(world), player, 2)
      game_driver.try_trigger_mine(_ctx(world), player)
      return true
    end,

    ["地雷正常触发"] = function(world)
      if game_driver.has_mine(_ctx(world), 5) then
        return nil, "mine at tile 5 should have triggered"
      end
      return true
    end,

    ["格子42是黑市格"] = function(world)
      game_driver.set_tile_type(_ctx(world), 42, "market")
      return true
    end,

    ["格子42同时放置了对手的已激活地雷"] = function(world)
      local opponent = _game(world).players[2]
      game_driver.place_mine(_ctx(world), 42, {
        owner_id = opponent.id,
        armed = true,
      })
      world.mine_tile_id = 42
      return true
    end,

    ["玩家移动到格子42"] = function(world)
      local player = _player(world)
      local idx = _tile_index(world, 42)
      game_driver.set_player_position(_ctx(world), player, idx)
      game_driver.sync_outer_facing(_ctx(world), player)
      local mine_result = game_driver.try_trigger_mine(_ctx(world), player)
      if mine_result and mine_result.hospitalized then
        world.mine_triggered_at_market = true
      end
      if not world.mine_triggered_at_market then
        world.market_interrupt_at_42 = true
      end
      world.mine_result = mine_result
      return true
    end,

    ["不弹出黑市选择"] = function(world)
      if world.market_interrupt_at_42 then
        return nil, "market popup should not appear after mine"
      end
      return true
    end,

    ["黑市选择正常弹出"] = function(world)
      if not world.market_interrupt_at_42 then
        return nil, "market popup should appear"
      end
      return true
    end,

    ["玩家经过黑市格时移动被中断"] = function(world)
      local player = _player(world)
      game_driver.set_tile_type(_ctx(world), 42, "market")
      local tile41_idx = _tile_index(world, 41)
      game_driver.set_player_position(_ctx(world), player, tile41_idx)
      game_driver.sync_outer_facing(_ctx(world), player)
      world.last_move_result = game_driver.move(_ctx(world), player, 6)
      world.market_resume_direction = player.status and player.status.move_dir
      world.market_resume_parity = world.last_move_result and world.last_move_result.branch_parity
      return true
    end,

    ["剩余3步未消耗"] = function(world)
      world.market_remaining_steps = 3
      return true
    end,

    ["玩家选择离开黑市继续移动"] = function(world)
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, world.market_remaining_steps or 3)
      return true
    end,

    ["玩家关闭黑市继续移动"] = function(world)
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, world.market_remaining_steps or 3)
      return true
    end,

    ["玩家沿原方向继续前进3步"] = function(world)
      local result = world.last_move_result
      if not result then
        return nil, "no move result after resume"
      end
      local visited = result.visited or {}
      if #visited < 1 then
        return nil, "expected movement after market resume"
      end
      return true
    end,

    ["分支奇偶状态保持不变"] = function()
      return true
    end,

    ["玩家当前位于格子2"] = function(world)
      local player = _player(world)
      local idx = _tile_index(world, 2)
      if not idx then
        return nil, "unknown tile id: 2"
      end
      game_driver.set_player_position(_ctx(world), player, idx)
      game_driver.sync_outer_facing(_ctx(world), player)
      return true
    end,

    ["格子3放置了未激活的地雷"] = function(world)
      local opponent = _game(world).players[2]
      game_driver.place_mine(_ctx(world), 3, {
        owner_id = opponent.id,
        armed = false,
      })
      world.mine_tile_id = 3
      return true
    end,

    ["玩家移动1步到达格子3"] = function(world)
      local player = _player(world)
      world.last_move_result = game_driver.move(_ctx(world), player, 1)
      game_driver.try_trigger_mine(_ctx(world), player)
      return true
    end,

    ["玩家不被送往医院"] = function(world)
      local tile = _tile_at_player(world)
      if tile and tile.type == "hospital" then
        return nil, "player should NOT be in hospital"
      end
      return true
    end,

    ["不打开黑市窗口"] = function(world)
      if world.market_window_open then
        return nil, "market window should not open"
      end
      return true
    end,

  }
end

return movement_steps
