-- src/turn/choice/lifecycle.lua 的直测 + 回合边界不变量的端到端钉子。
-- 待决选择是回合内概念(CONTEXT「待决选择」):回合推进到下一位玩家时必然已经
-- 消失。此前这条不变量只靠约定维持,没有任何东西拦住残留 —— 5ce62507 那类 bug
-- (跟随选择道具收尾时少清一次)就是这么把 choice 门控带进下一位玩家的回合的。
-- 守卫落在 next_player(current_player_index 的唯一写入点)这个咽喉上:
-- 测试期红灯,生产期 warn + 清掉残留自愈。
local lu = require("luaunit")

local support = require("test.support.shared_support")
local lifecycle = require("src.turn.choice.lifecycle")
local turn_runtime = require("src.turn.scheduler")
local logger = require("src.foundation.log")
local config_reset = require("test.support.config_reset")

local function _pending(kind)
  return {
    id = 7,
    kind = kind or "item_target_player",
    owner_role_id = 1,
    meta = { phase = "post_action", item_id = 2013, player_id = 1 },
  }
end

TestLifecycle = {}

function TestLifecycle:setUp()
  config_reset.reset_all()
end

-- nil game 兜底:守卫链 game and game.turn or nil 必须对空输入短路,不能索引 nil。
function TestLifecycle:test_handles_nil_game_without_error()
  lu.assertEvalToTrue(lifecycle.assert_cleared_on_turn_advance(nil) == nil,
    "nil game must be a no-op")
end

function TestLifecycle:test_passes_cleanly_when_no_choice_is_pending()
  local g = support.new_game()  g.turn.pending_choice = nil

  lifecycle.assert_cleared_on_turn_advance(g)

  lu.assertEvalToTrue(g.turn.pending_choice == nil, "a nil pending choice must stay nil")
end

function TestLifecycle:test_raises_in_test_mode_when_a_resolved_choice_survives_the_turn_boundary()
  local g = support.new_game()
  g.turn.pending_choice = _pending()

  local ok, err = pcall(lifecycle.assert_cleared_on_turn_advance, g)

  lu.assertEvalToTrue(ok == false, "a surviving pending choice must be a hard failure in test mode")
  lu.assertEvalToTrue(tostring(err):find("survived into the next turn", 1, true) ~= nil,
    "failure must name the invariant, got: " .. tostring(err))
  lu.assertEvalToTrue(tostring(err):find("item_target_player", 1, true) ~= nil,
    "failure must carry the choice kind for diagnosis, got: " .. tostring(err))
end

function TestLifecycle:test_clears_the_leftover_and_keeps_running_in_production_mode()
  local g = support.new_game()
  g.turn.pending_choice = _pending()

  -- spy on logger.warn to verify the invariant warning is emitted
  local warned = {}
  local orig_warn = logger.warn
  logger.warn = function(msg, detail)
    warned.msg = msg
    warned.detail = detail
  end

  logger.set_test_mode(false)
  local ok = pcall(lifecycle.assert_cleared_on_turn_advance, g)
  logger.set_test_mode(true)
  logger.warn = orig_warn

  lu.assertEvalToTrue(ok == true, "production must not crash the game on a leftover choice")
  lu.assertEvalToTrue(g.turn.pending_choice == nil, "production must clear the leftover so the next player is not gated")
  lu.assertEvalToTrue(warned.msg ~= nil, "production must emit a warning when clearing a leftover choice")
  lu.assertEvalToTrue(type(warned.detail) == "string", "production must include the choice detail in the warning")
end

-- 回合交接是 scheduler 私有协作；通过 inter_turn_wait 的公开驱动验证边界。
function TestLifecycle:test_guards_turn_boundary_when_inter_turn_wait_advances_player()
  local g = support.new_game()
  local scheduler = turn_runtime:new(g, {
    start = function(_, args)
      if args and args.finished then
        return nil
      end
      return "inter_turn_wait", { finished = true }
    end,
  })
  g.turn.pending_choice = _pending("item_phase_passive")

  local ok, err = pcall(function()
    scheduler:run_turn()
  end)

  lu.assertEvalToTrue(ok == false, "turn boundary must refuse to advance past a leftover choice")
  lu.assertEvalToTrue(tostring(err):find("survived into the next turn", 1, true) ~= nil,
    "turn boundary failure must come from the lifecycle guard, got: " .. tostring(err))
end

function TestLifecycle:test_advances_normally_once_the_choice_is_gone()
  local g = support.new_game()
  local scheduler = turn_runtime:new(g, {
    start = function(_, args)
      if args and args.finished then
        return nil
      end
      return "inter_turn_wait", { finished = true }
    end,
  })
  local before = g.turn.current_player_index
  g.turn.pending_choice = nil

  scheduler:run_turn()

  lu.assertEvalToTrue(g.turn.current_player_index ~= before, "a clean turn boundary must still advance the player")
end

-- 闭合变异: pending.meta 为 nil 时 or {} 兜底,防止 _describe 里访问 nil 字段崩
function TestLifecycle:test_describes_a_pending_choice_whose_meta_is_nil_without_crashing()
  local g = support.new_game()
  g.turn.pending_choice = { id = 7, kind = "item_target_player", owner_role_id = 1 }
  -- meta 缺省为 nil,依赖 or {} 兜底

  local ok, err = pcall(lifecycle.assert_cleared_on_turn_advance, g)

  lu.assertEvalToTrue(ok == false, "nil-meta choice must still be detected as a boundary violation")
  lu.assertEvalToTrue(tostring(err):find("survived into the next turn", 1, true) ~= nil,
    "nil-meta choice must trigger the same invariant error")
end


return TestLifecycle
