---@diagnostic disable: undefined-global, undefined-field

-- 遥控骰子反馈（#103）：经真实 event_feed_adapter，使用遥控骰子必须
-- 进行动日志并弹出全场可见提示（谁使用、设定点数）。只改 tip 策略，
-- 不碰骰面渲染。

local luassert = assert
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_log = require("src.state.event_log")
local event_kinds = require("src.config.gameplay.event_kinds")
local remote_dice = require("src.rules.items.remote_dice")

local function _build_game()
  local tips = {}
  local game = {
    state = { event_log = event_log.new() },
    anim_gate_port = { wait_action_anim = false },
    set_pending_remote_dice = function() end,
    tip_output_port = {
      enqueue = function(_, intent)
        tips[#tips + 1] = intent
        return true
      end,
    },
  }
  game.event_feed_port = event_feed_adapter.new(game)
  return game, tips
end

describe("TestRemoteDiceTip", function()

it("test_remote_dice_use_enters_action_log_with_who_and_set_point", function()
  local game, _ = _build_game()
  local player = { id = 1, name = "小明", status = {} }

  local result = remote_dice.apply(game, player, 2, 5)

  luassert.is_true(result.ok)
  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(1, #entries, "remote dice use must land in the action log")
  luassert.is.equal(event_kinds.remote_dice, entries[1].kind)
  luassert.is.equal("小明 使用遥控骰子，设定点数 5,5", entries[1].text)
end)

it("test_remote_dice_use_pops_tip_visible_to_all_with_who_and_set_point", function()
  local game, tips = _build_game()
  local player = { id = 1, name = "小红", status = {} }

  remote_dice.apply(game, player, 1, 3)

  luassert.is.equal(1, #tips, "remote dice use must pop a tip visible to the whole table")
  luassert.is.equal("小红 使用遥控骰子，设定点数 3", tips[1].text)
end)

end)
