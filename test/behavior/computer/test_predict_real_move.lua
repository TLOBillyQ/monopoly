require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- #102: 遥控骰子预测必须与真实移动走同一套计算语义。
-- 接缝：
--   预测侧 = path_planner.predict_landing(game, player, steps)（电脑落点预测的公共入口）
--   真实侧 = src.turn.phases.move + move_followup 真实调用链（托管玩家，黑市自动跳过），
--            观察 player.position 的最终落点。
-- 覆盖：黑市恢复、自雷宽限、已武装敌雷、内圈朝向、入口跳过。
local support = require("test.support.shared_support")
local control = require("src.player.control")
local default_map = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")
local phase_move = require("src.turn.phases.move")
local path_planner = require("src.computer.agent.path")

local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual,
    tostring(message) .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

local _config_reset = require("test.support.config_reset")

local function _tile_id_at(row, col)
  for _, tile_cfg in ipairs(tiles_cfg) do
    if tile_cfg.row == row and tile_cfg.col == col then
      return tile_cfg.id
    end
  end
  error("missing tile at row " .. tostring(row) .. " col " .. tostring(col))
end

local function _index_at(game, row, col)
  return game.board:index_of_tile_id(_tile_id_at(row, col))
end

local function _new_game()
  local game = support.new_game({ map = default_map })
  game.last_turn = game.last_turn or {}
  return game
end

local function _place_player(game, row, col, move_dir)
  local player = game.players[1]
  game:update_player_position(player, _index_at(game, row, col))
  if move_dir ~= nil then
    game:set_player_status(player, "move_dir", move_dir)
  end
  return player
end

-- 真实移动链：move 阶段 + move_followup，托管玩家黑市自动跳过后恢复剩余步数，
-- 与回合内真实执行路径一致；返回最终落点索引。
local function _real_move_endpoint(game, player, steps)
  control.toggle_manual_delegation(player)
  local turn_mgr = { game = game }
  local state, args = phase_move(turn_mgr, { player = player, raw_total = steps, total = steps })
  local guard = 0
  while state == "move" do
    guard = guard + 1
    luassert.truthy(guard < 10, "real move chain did not settle")
    state, args = phase_move(turn_mgr, args)
  end
  luassert.is.equal("landing", state, "real move chain should end at landing, got " .. tostring(state))
  return player.position
end

describe("TestPredictRealMove", function()
  before_each(function()
    _config_reset.reset_all()
  end)

  it("test_market_interrupt_resumes_remaining_steps", function()
    -- 从 (5,2) 向右走 4 步：第 3 步踩黑市 (5,5)，真实流程恢复剩余 1 步落到道具卡 (5,6)；
    -- 旧模拟遇黑市即停在 (5,5)。
    local predict_game = _new_game()
    local predict_player = _place_player(predict_game, 5, 2, "right")
    local real_game = _new_game()
    local real_player = _place_player(real_game, 5, 2, "right")

    local predicted = path_planner.predict_landing(predict_game, predict_player, 4)
    local actual = _real_move_endpoint(real_game, real_player, 4)

    local expected = _index_at(real_game, 5, 6)
    _assert_eq(actual, expected, "real move should resume past the market onto the item tile")
    _assert_eq(predicted, actual, "prediction must match the real landing after market resume")
  end)

  it("test_self_mine_grace_lets_the_walk_continue", function()
    -- 自己的已武装地雷在宽限期内不触发：真实移动会越过，预测也必须越过。
    local predict_game = _new_game()
    local predict_player = _place_player(predict_game, 9, 9)
    local real_game = _new_game()
    local real_player = _place_player(real_game, 9, 9)
    for _, pair in ipairs({ { predict_game, predict_player }, { real_game, real_player } }) do
      local game, player = pair[1], pair[2]
      game:set_player_status(player, "own_turn_started_count", 2)
      game.board:place_mine(_index_at(game, 9, 8), {
        owner_id = player.id,
        armed = true,
        owner_turn_started_count_at_placement = 2,
      })
    end

    local predicted = path_planner.predict_landing(predict_game, predict_player, 3)
    local actual = _real_move_endpoint(real_game, real_player, 3)

    local expected = _index_at(real_game, 9, 6)
    _assert_eq(actual, expected, "real move should walk past a self mine inside the grace window")
    _assert_eq(predicted, actual, "prediction must respect self-mine grace")
  end)

  it("test_armed_enemy_mine_stops_both_prediction_and_real_move", function()
    -- 敌方已武装地雷必须停：预测与真实移动一致地停在雷格。
    local predict_game = _new_game()
    local predict_player = _place_player(predict_game, 9, 9)
    local real_game = _new_game()
    local real_player = _place_player(real_game, 9, 9)
    for _, pair in ipairs({ { predict_game, predict_player }, { real_game, real_player } }) do
      local game, player = pair[1], pair[2]
      local enemy = game.players[2]
      game.board:place_mine(_index_at(game, 9, 8), {
        owner_id = enemy.id,
        armed = true,
        owner_turn_started_count_at_placement = 0,
      })
      game:set_player_status(player, "own_turn_started_count", 5)
    end

    local predicted = path_planner.predict_landing(predict_game, predict_player, 3)
    local actual = _real_move_endpoint(real_game, real_player, 3)

    local expected = _index_at(real_game, 9, 8)
    _assert_eq(actual, expected, "real move should stop on the armed enemy mine")
    _assert_eq(predicted, actual, "prediction must stop on the armed enemy mine")
  end)

  it("test_inner_ring_uses_the_persisted_facing", function()
    -- 内圈起步按持久 move_dir 走：从 (5,4) 向左 2 步落到 (5,2)；
    -- 旧模拟用 fresh 朝向会拐向黑市 (5,5)。
    local predict_game = _new_game()
    local predict_player = _place_player(predict_game, 5, 4, "left")
    local real_game = _new_game()
    local real_player = _place_player(real_game, 5, 4, "left")

    local predicted = path_planner.predict_landing(predict_game, predict_player, 2)
    local actual = _real_move_endpoint(real_game, real_player, 2)

    local expected = _index_at(real_game, 5, 2)
    _assert_eq(actual, expected, "real move should follow the persisted inner-ring heading")
    _assert_eq(predicted, actual, "prediction must use the persisted inner-ring heading")
  end)

  it("test_entry_skip_walks_past_the_inner_entry", function()
    -- 入口格带 skip_next_inner_entry 标记：偶数步本来允许进内圈，
    -- 真实移动跳过入口沿外圈走，预测也必须跳过。
    local predict_game = _new_game()
    local predict_player = _place_player(predict_game, 9, 5)
    local real_game = _new_game()
    local real_player = _place_player(real_game, 9, 5)
    for _, pair in ipairs({ { predict_game, predict_player }, { real_game, real_player } }) do
      local game, player = pair[1], pair[2]
      game:set_player_status(player, "skip_next_inner_entry", true)
    end

    local predicted = path_planner.predict_landing(predict_game, predict_player, 2)
    local actual = _real_move_endpoint(real_game, real_player, 2)

    local expected = _index_at(real_game, 9, 3)
    _assert_eq(actual, expected, "real move should skip the inner entry and stay on the outer ring")
    _assert_eq(predicted, actual, "prediction must honor the one-shot inner-entry skip")
  end)

  it("test_pick_remote_dice_value_prefers_the_tile_real_movement_reaches", function()
    -- 电脑接线钉：从 (5,2) 向右，点数 4 经黑市恢复落到道具卡 (5,6)（rank 1），
    -- 旧模拟停在黑市会错选点数 6 的 (5,8) 空地。
    local game = _new_game()
    local player = _place_player(game, 5, 2, "right")

    local value, tile_ref = path_planner.pick_remote_dice_value(game, player, 1)

    _assert_eq(value, 4, "remote dice should pick the value whose real landing is the item tile")
    _assert_eq(tile_ref.id, _tile_id_at(5, 6), "the picked tile should be the resumed item landing")

    local real_game = _new_game()
    local real_player = _place_player(real_game, 5, 2, "right")
    local actual = _real_move_endpoint(real_game, real_player, 4)
    _assert_eq(actual, _index_at(real_game, 5, 6), "the picked value must be reachable by real movement")
  end)
end)
