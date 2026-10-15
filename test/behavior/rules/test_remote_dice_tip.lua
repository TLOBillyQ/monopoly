---@diagnostic disable: undefined-global, undefined-field

-- 遥控骰子反馈（#103）：经真实 event_feed_adapter，使用遥控骰子必须
-- 进行动日志并弹出全场可见提示（谁使用、设定点数）。只改 tip 策略，
-- 不碰骰面渲染。

local luassert = assert
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_log = require("src.state.event_log")
local event_kinds = require("src.config.gameplay.event_kinds")
local item_ids = require("src.config.gameplay.item_ids")
local remote_dice = require("src.rules.items.remote_dice")
local handlers = require("src.rules.items.handlers")
local use_flow = require("src.rules.items.use_flow")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")

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

-- 遥控骰子单提示回归（#109）：#103 让 remote_dice 弹 tip 后，AI 直放路径
-- 再发一条 remote_dice 事件（目标格），一次用卡弹两条提示。修复口径：
-- 一次 AI 遥控骰子使用只弹一条提示（谁 + 设定点数），目标格信息只进
-- 行动日志（remote_dice_target, tip=false）；真人路径不受影响。
-- 接缝：handlers.handle_remote_dice（AI 直放）与 use_flow.resolve_item_use_choice
-- （choice 结算），经 support.new_game 装配的真实 event_feed_adapter 观察
-- tip_output_port 与行动日志；auto_play_port 是 AI 决策边界，按局替换。

describe("TestRemoteDiceSingleTip", function()

local function _new_tip_game(tips)
  return support.new_game({
    map = default_map,
    players = { "小明", "小红" },
    ui_port = {
      show_tip = function(_, intent)
        tips[#tips + 1] = intent
        return true
      end,
    },
  })
end

local function _resolve_remote_dice_choice(game, user, value, use_context)
  local choice = support.open_choice(game, {
    kind = "remote_dice_value",
    options = { { id = value, label = tostring(value) } },
    meta = { player_id = user.id, item_id = item_ids.remote_dice, dice_count = 1 },
  })
  return use_flow.resolve_item_use_choice(game, choice, {
    type = "choice_select",
    choice_id = choice.id,
    option_id = value,
    actor_role_id = user.id,
  }, use_context)
end

it("test_ai_direct_use_pops_exactly_one_tip_and_logs_use_plus_target", function()
  local tips = {}
  local game = _new_tip_game(tips)
  local user = game.players[1]
  user.inventory:add({ id = item_ids.remote_dice })
  game.auto_play_port.pick_remote_dice_value = function()
    return 4, { name = "财神庙" }
  end

  local settled = handlers.handle_remote_dice(game, user, item_ids.remote_dice, { is_computer_controlled = true })

  luassert.is_true(settled.ok)
  luassert.is.equal(1, #tips, "one AI remote dice use pops exactly one tip (#109)")
  luassert.is.equal("小明 使用遥控骰子，设定点数 4", tips[1].text)
  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(2, #entries, "action log keeps the use entry plus the target-tile entry")
  luassert.is.equal(event_kinds.remote_dice, entries[1].kind)
  luassert.is.equal("小明 使用遥控骰子，设定点数 4", entries[1].text)
  luassert.is.equal(event_kinds.remote_dice_target, entries[2].kind)
  luassert.truthy(entries[2].text:find("财神庙", 1, true), "the target-tile entry names the target tile")
end)

it("test_ai_choice_settlement_pops_exactly_one_tip", function()
  local tips = {}
  local game = _new_tip_game(tips)
  local user = game.players[1]
  user.inventory:add({ id = item_ids.remote_dice })

  local result = _resolve_remote_dice_choice(game, user, 5, { is_computer_controlled = true })

  luassert.is_true(result.ok)
  luassert.is.equal(1, #tips, "AI choice settlement pops exactly one tip (#109)")
  luassert.is.equal("小明 使用遥控骰子，设定点数 5", tips[1].text)
  local entries = event_log.get_entries(game.state.event_log)
  luassert.is.equal(1, #entries, "the use lands in the action log")
  luassert.is.equal(event_kinds.remote_dice, entries[1].kind)
end)

it("test_human_choice_settlement_still_pops_exactly_one_tip", function()
  local tips = {}
  local game = _new_tip_game(tips)
  local user = game.players[1]
  user.inventory:add({ id = item_ids.remote_dice })

  local result = _resolve_remote_dice_choice(game, user, 6, {})

  luassert.is_true(result.ok)
  luassert.is.equal(1, #tips, "the human path is unaffected: still exactly one tip")
  luassert.is.equal("小明 使用遥控骰子，设定点数 6", tips[1].text)
end)

end)
