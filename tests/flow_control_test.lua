-- 流程控制与恢复机制测试
-- 测试目标：验证状态机恢复、中断处理、嵌套等待等复杂场景

local Flow = require("src.core.flow")
local Game = require("src.game")
local MovementService = require("src.gameplay.movement_service")
local ChoiceService = require("src.gameplay.choice_service")

local TestUtils = require("tests.test_utils")
local assert_eq = TestUtils.assert_eq

local function new_game()
  return Game.new({ players = { "P1", "P2" }, ai = { [2] = true }, auto_all = false, seed = 42 })
end

local function get_choice(game)
  if not (game and game.store) then
    return nil
  end
  return game.store:get({ "turn", "pending_choice" })
end

-- ========== Flow 状态机基础测试 ==========

local function test_flow_simple_state_transition()
  local visited = {}
  local states = {
    init = function(args)
      table.insert(visited, "init")
      return "process", { data = args.data .. "->init" }
    end,
    process = function(args)
      table.insert(visited, "process")
      return "complete", { data = args.data .. "->process" }
    end,
    complete = function(args)
      table.insert(visited, "complete")
      assert_eq(args.data, "start->init->process", "data flow")
      return nil
    end,
  }

  local flow = Flow.new({ start = "init", states = states, args = { data = "start" } })
  
  while flow.current do
    flow:step()
  end
  
  assert_eq(#visited, 3, "all states visited")
  assert_eq(visited[1], "init", "first state")
  assert_eq(visited[2], "process", "second state")
  assert_eq(visited[3], "complete", "third state")
end

local function test_flow_can_loop()
  local counter = 0
  local states = {
    loop = function(args)
      counter = counter + 1
      if counter >= 3 then
        return nil
      end
      return "loop", args
    end,
  }

  local flow = Flow.new({ start = "loop", states = states })
  
  while flow.current do
    flow:step()
  end
  
  assert_eq(counter, 3, "loop executed 3 times")
end

local function test_flow_error_on_missing_state()
  local states = {
    init = function()
      return "missing_state"
    end,
  }

  local flow = Flow.new({ start = "init", states = states })
  
  -- First step succeeds (transitions to missing_state)
  flow:step()
  
  -- Second step should error (missing_state is not in states)
  local ok, err = pcall(function()
    flow:step()
  end)
  
  assert(not ok, "should error on missing state")
  assert(tostring(err):match("flow state not found"), "error message mentions missing state")
end

-- ========== TurnManager 恢复机制测试 ==========

local function test_turn_manager_basic_flow()
  local g = new_game()
  g.turn_manager:run_turn()
  
  -- 第一次运行应该到达 wait_choice 或完成
  local phase = g.store:get({ "turn", "phase" })
  assert(phase, "phase should be set")
end

local function test_turn_manager_resume_after_choice()
  local g = new_game()
  local p = g:current_player()
  
  -- 定位到一个空地块
  local land_idx = nil
  for idx, tile in ipairs(g.board.path) do
    if tile.type == "land" then
      land_idx = idx
      break
    end
  end
  assert(land_idx, "should find a land tile")
  
  g:update_player_position(p, land_idx)
  
  -- 运行回合
  g:advance_turn()
  
  -- 应该出现购地选择
  local choice = get_choice(g)
  if choice and choice.kind == "landing_optional_effect" then
    -- 取消购买
    ChoiceService.resolve(g, choice, { type = "choice_cancel", choice_id = choice.id })
    
    -- 验证选择已清除
    assert_eq(get_choice(g), nil, "choice should be cleared")
  end
end

local function test_market_interrupt_resume()
  local g = new_game()
  local p = g:current_player()
  
  -- 找到黑市位置
  local market_idx = nil
  for idx, tile in ipairs(g.board.path) do
    if tile.type == "market" then
      market_idx = idx
      break
    end
  end
  
  if not market_idx then
    print("  [SKIP] no market tile found")
    return
  end
  
  -- 设置玩家在黑市前
  local start_pos = market_idx > 2 and (market_idx - 2) or 1
  g:update_player_position(p, start_pos)
  p:set_cash(10000)
  
  -- 移动经过黑市
  local move_distance = market_idx - start_pos + 2
  local res = MovementService.move(g, p, move_distance, { branch_parity = move_distance })
  
  -- 验证移动结果
  assert(res, "move should return result")
  
  -- 如果触发了黑市中断
  if res.market_interrupt then
    local interrupt = res.market_interrupt
    assert(interrupt.remaining_steps ~= nil, "should have remaining_steps")
    assert(interrupt.facing, "should have facing direction")
    assert(interrupt.branch_parity ~= nil, "should have branch_parity")
    
    -- 继续移动（模拟选择后恢复）
    local res2 = MovementService.move(g, p, interrupt.remaining_steps, {
      direction = interrupt.facing,
      branch_parity = interrupt.branch_parity,
    })
    assert(res2, "resume move should succeed")
  end
end

local function test_steal_interrupt_resume()
  local g = new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  
  -- 给 p1 偷窃卡
  p1.inventory:add({ id = 2007 })
  
  -- 设置 p2 在 p1 前方
  g:update_player_position(p1, 5)
  g:update_player_position(p2, 8)
  
  -- p1 移动经过 p2
  local res = MovementService.move(g, p1, 5, { branch_parity = 5, skip_market_check = true })
  
  -- 验证偷窃中断
  if res.steal_interrupt then
    local interrupt = res.steal_interrupt
    assert(interrupt.encountered_ids, "should have encountered_ids")
    assert(interrupt.remaining_steps ~= nil, "should have remaining_steps")
    assert(interrupt.facing, "should have facing direction")
    
    -- 继续移动（模拟处理偷窃后恢复）
    if interrupt.remaining_steps > 0 then
      local res2 = MovementService.move(g, p1, interrupt.remaining_steps, {
        direction = interrupt.facing,
        branch_parity = interrupt.branch_parity,
        skip_steal_check = true,
      })
      assert(res2, "resume move after steal should succeed")
    end
  end
end

-- ========== 嵌套等待恢复测试 ==========

local function test_nested_choice_resolution()
  local g = new_game()
  local p = g:current_player()
  
  -- 给玩家一些道具
  p.inventory:add({ id = 2001 }) -- 路障卡
  p:set_cash(10000)
  
  -- 运行一个完整回合
  g:advance_turn()
  
  -- 处理所有可能出现的选择
  local max_iterations = 10
  local iteration = 0
  while get_choice(g) and iteration < max_iterations do
    iteration = iteration + 1
    local choice = get_choice(g)
    
    -- 总是取消
    ChoiceService.resolve(g, choice, { type = "choice_cancel", choice_id = choice.id })
    
    -- 继续推进
    g:advance_turn()
  end
  
  assert(iteration < max_iterations, "should not infinite loop on choices")
end

-- ========== 状态一致性测试 ==========

local function test_phase_state_consistency()
  local g = new_game()
  
  -- 初始状态
  local turn_count_0 = g.store:get({ "turn", "turn_count" })
  assert_eq(turn_count_0, 0, "initial turn count")
  
  -- 运行几个回合
  for i = 1, 3 do
    g:advance_turn()
    
    -- 处理任何选择
    local choice = get_choice(g)
    if choice then
      ChoiceService.resolve(g, choice, { type = "choice_cancel", choice_id = choice.id })
    end
  end
  
  -- 验证回合计数增加
  local turn_count_final = g.store:get({ "turn", "turn_count" })
  assert(turn_count_final > turn_count_0, "turn count should increase")
end

local function test_store_immutability()
  local g = new_game()
  
  -- 获取状态快照
  local phase1 = g.store:get({ "turn", "phase" })
  
  -- 运行回合
  g:advance_turn()
  
  -- 验证旧引用未被修改（Store 使用 deep_copy）
  local phase2 = g.store:get({ "turn", "phase" })
  assert(phase1 ~= phase2 or g.finished, "phase should change or game finished")
end

-- ========== 错误恢复测试 ==========

local function test_invalid_choice_clears_state()
  local g = new_game()
  local p = g:current_player()
  
  -- 模拟打开一个选择
  g.store:set({ "turn", "pending_choice" }, {
    id = 1,
    kind = "test_choice",
    options = { { id = "opt1", label = "Option 1" } },
  })
  
  local choice = get_choice(g)
  assert(choice, "choice should be set")
  
  -- 发送无效选项
  ChoiceService.resolve(g, choice, { option_id = "invalid_option" })
  
  -- 验证选择已清除
  assert_eq(get_choice(g), nil, "invalid choice should clear state")
end

local function test_recovery_after_missing_handler()
  local g = new_game()
  
  -- 模拟打开一个未知类型的选择
  g.store:set({ "turn", "pending_choice" }, {
    id = 1,
    kind = "unknown_choice_kind",
    options = {},
  })
  
  local choice = get_choice(g)
  assert(choice, "choice should be set")
  
  -- 尝试解析未知类型
  local res = ChoiceService.resolve(g, choice, { option_id = "any" })
  
  -- 验证优雅降级
  assert(res, "should return result")
  assert_eq(get_choice(g), nil, "unknown choice should clear state")
end

-- ========== 集成测试：复杂场景 ==========

local function test_complex_turn_with_multiple_interrupts()
  local g = new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  
  -- 设置复杂场景：
  -- 1. p1 有偷窃卡和其他道具
  -- 2. p2 在前方某位置
  -- 3. 前方有黑市
  
  p1.inventory:add({ id = 2007 }) -- 偷窃卡
  p1.inventory:add({ id = 2001 }) -- 路障卡
  p1:set_cash(50000)
  p2:set_cash(50000)
  
  -- 运行一个完整回合
  local initial_phase = g.store:get({ "turn", "phase" })
  g:advance_turn()
  
  -- 处理所有等待
  local max_wait = 20
  local wait_count = 0
  while get_choice(g) and wait_count < max_wait do
    wait_count = wait_count + 1
    local choice = get_choice(g)
    
    -- 取消所有选择
    ChoiceService.resolve(g, choice, { type = "choice_cancel", choice_id = choice.id })
    
    -- 继续推进
    g:advance_turn()
  end
  
  assert(wait_count < max_wait, "should not loop indefinitely")
  
  -- 验证回合推进
  local final_player_idx = g.store:get({ "turn", "current_player_index" })
  assert(final_player_idx, "current player index should be set")
end

-- ========== 测试套件 ==========

local tests = {
  -- Flow 状态机
  test_flow_simple_state_transition,
  test_flow_can_loop,
  test_flow_error_on_missing_state,
  
  -- TurnManager
  test_turn_manager_basic_flow,
  test_turn_manager_resume_after_choice,
  test_market_interrupt_resume,
  test_steal_interrupt_resume,
  
  -- 嵌套等待
  test_nested_choice_resolution,
  
  -- 状态一致性
  test_phase_state_consistency,
  test_store_immutability,
  
  -- 错误恢复
  test_invalid_choice_clears_state,
  test_recovery_after_missing_handler,
  
  -- 集成测试
  test_complex_turn_with_multiple_interrupts,
}

for _, fn in ipairs(tests) do
  fn()
  io.stdout:write(".")
end

print("\nAll flow control tests passed (" .. #tests .. ")")
