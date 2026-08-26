-- remote_dice.apply 直测:守卫(dice_count 非空且 ≥1)、values 长度与内容、
-- event_feed 文案、action_anim 队列参数与时长回退链。
local lu = require("luaunit")
local support = require("test.support.shared_support")

local remote_dice = require("src.rules.items.remote_dice")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local timing = require("src.config.gameplay.timing")

TestRemoteDice = {}

local function _drive(dice_count, value)
  local captured = {}
  local game = {
    set_pending_remote_dice = function(_, player, values)
      captured.values = values
      captured.player = player
    end,
  }
  support.with_patches({
    { target = event_feed, key = "publish", value = function(_, payload)
      captured.feed = payload
    end },
    { target = action_anim_port, key = "queue", value = function(_, opts)
      captured.anim = opts
      return "q1"
    end },
  }, function()
    remote_dice.apply(game, { id = 1, name = "P1" }, dice_count, value)
  end)
  return captured
end

function TestRemoteDice:test_rejects_a_nil_dice_count()
  lu.assertErrorMsgContains("invalid dice_count", function()
    _drive(nil, 5)
  end)
end

function TestRemoteDice:test_rejects_a_zero_dice_count()
  lu.assertErrorMsgContains("invalid dice_count", function()
    _drive(0, 5)
  end)
end

function TestRemoteDice:test_single_die_produces_one_value()
  local captured = _drive(1, 5)
  lu.assertEvalToTrue(#captured.values == 1, "one die must produce one value")
  lu.assertEvalToTrue(captured.values[1] == 5, "the die value must be pinned")
  lu.assertEvalToTrue(captured.values[0] == nil, "the loop must start at index 1")
end

function TestRemoteDice:test_two_dice_produce_two_values_and_comma_joined_text()
  local captured = _drive(2, 3)
  lu.assertEvalToTrue(#captured.values == 2, "two dice must produce two values")
  lu.assertEvalToTrue(captured.values[1] == 3 and captured.values[2] == 3,
    "every die must carry the configured value")
  lu.assertEvalToTrue(captured.feed ~= nil and type(captured.feed.text) == "string"
    and captured.feed.text:find(",", 1, true) ~= nil,
    "the feed text must comma-join the values")
end

function TestRemoteDice:test_queues_the_item_use_animation()
  local captured = _drive(1, 5)
  lu.assertEvalToTrue(captured.anim ~= nil, "an action anim must be queued")
  lu.assertEvalToTrue(captured.anim.kind == "item_use", "the anim kind must be item_use")
  lu.assertEvalToTrue(captured.anim.player_id == 1, "the player id must be pinned")
  lu.assertEvalToTrue(captured.anim.item_name ~= nil and captured.anim.item_name ~= "",
    "the item name must resolve")
end

function TestRemoteDice:test_duration_uses_the_remote_dice_timing_when_configured()
  local prev = timing.remote_dice_wait_seconds
  timing.remote_dice_wait_seconds = 2.5
  local captured = _drive(1, 5)
  timing.remote_dice_wait_seconds = prev
  lu.assertEvalToTrue(captured.anim.duration == 2.5,
    "the remote dice wait timing must drive the anim duration")
end

return TestRemoteDice
