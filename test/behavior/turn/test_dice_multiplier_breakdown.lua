---@diagnostic disable: undefined-global, undefined-field

-- 骰子加倍行动日志（#103）：加倍生效时补一条行动日志，写明
-- “骰面 N × 倍率 = 移动 M 步”。经真实 event_feed_adapter 观察；
-- 日志只入行动日志，不弹 tip（提示归“使用骰子加倍卡”一条）。

local luassert = assert
local phase_pre_move = require("src.turn.phases.pre_move")
local dice_multiplier_phase = require("src.turn.phases.dice_multiplier")
local item_phase = require("src.rules.items.phase")
local status_ops = require("src.player.actions.status")
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local event_log = require("src.state.event_log")
local event_kinds = require("src.config.gameplay.event_kinds")

local function _build_game(player, raw_total)
  local tips = {}
  local game = {
    state = { event_log = event_log.new() },
    dirty = {},
    current_player = function() return player end,
    last_turn = { raw_total = raw_total, total = raw_total, player_id = player.id },
    turn = { item_phase = {} },
    auto_play_port = {
      is_auto_player = function() return false end,
      pick_target_player = function() return nil end,
      pick_remote_dice_value = function() return nil end,
      pick_roadblock_target = function() return nil end,
      auto_action_for_choice = function() return nil end,
    },
    player_pending_dice_multiplier = status_ops.player_pending_dice_multiplier,
    consume_pending_dice_multiplier = status_ops.consume_pending_dice_multiplier,
    tip_output_port = {
      enqueue = function(_, intent)
        tips[#tips + 1] = intent
        return true
      end,
    },
  }
  game.event_feed_port = event_feed_adapter.new(game)
  return { game = game }, tips
end

local function _with_item_phase_run(stub_fn, fn)
  local orig = item_phase.run
  item_phase.run = stub_fn
  local ok, err = pcall(fn)
  item_phase.run = orig
  if not ok then error(err, 2) end
end

describe("TestDiceMultiplierBreakdown", function()

it("test_pre_move_logs_face_times_multiplier_equals_steps", function()
  local player = { id = 1, name = "P1", status = { pending_dice_multiplier = 2 } }
  local turn_mgr, tips = _build_game(player, 7)

  _with_item_phase_run(function() return nil end, function()
    local state, args = phase_pre_move(turn_mgr, { player = player, total = 7, raw_total = 7 })
    luassert.is.equal("move", state)
    luassert.is.equal(14, args.total, "total must be face 7 x multiplier 2")
  end)

  local entries = event_log.get_entries(turn_mgr.game.state.event_log)
  luassert.is.equal(1, #entries, "multiplier application must add one action log line")
  luassert.is.equal(event_kinds.dice_multiplier_breakdown, entries[1].kind)
  luassert.is.equal("P1 骰面 7 × 2 = 移动 14 步", entries[1].text)
  luassert.is.equal(0, #tips, "the breakdown is a log line, not a tip")
end)

it("test_pre_move_without_multiplier_adds_no_breakdown_log", function()
  local player = { id = 1, name = "P1", status = {} }
  local turn_mgr, _ = _build_game(player, 5)

  _with_item_phase_run(function() return nil end, function()
    local state, args = phase_pre_move(turn_mgr, { player = player, total = 5, raw_total = 5 })
    luassert.is.equal("move", state)
    luassert.is.equal(5, args.total)
  end)

  local entries = event_log.get_entries(turn_mgr.game.state.event_log)
  luassert.is.equal(0, #entries, "no multiplier pending means no breakdown line")
end)

it("test_move_survivor_path_logs_face_times_multiplier_equals_steps", function()
  local player = { id = 1, name = "P1", status = { pending_dice_multiplier = 4 } }
  local turn_mgr, tips = _build_game(player, 3)
  turn_mgr.game.last_turn = { raw_total = 3, total = 3 }

  local new_total = dice_multiplier_phase.apply_move_total(turn_mgr.game, player, 3, 3)

  luassert.is.equal(12, new_total)
  local entries = event_log.get_entries(turn_mgr.game.state.event_log)
  luassert.is.equal(1, #entries)
  luassert.is.equal(event_kinds.dice_multiplier_breakdown, entries[1].kind)
  luassert.is.equal("P1 骰面 3 × 4 = 移动 12 步", entries[1].text)
  luassert.is.equal(0, #tips, "the breakdown is a log line, not a tip")
end)

end)
