require("test.bootstrap").install_package_paths()
local luassert = assert
-- remote_dice.apply 直测:守卫(dice_count 非空且 ≥1)、values 长度与内容、
-- event_feed 文案、action_anim 队列参数与时长回退链。
local support = require("test.support.shared_support")

local remote_dice = require("src.rules.items.remote_dice")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local timing = require("src.config.gameplay.timing")


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

describe("TestRemoteDice", function()
  it("test_rejects_a_nil_dice_count", function()
    luassert.has_error.match(function() (function()
      _drive(nil, 5)
    end)() end, "invalid dice_count", 1, true)
  end)

  it("test_rejects_a_zero_dice_count", function()
    luassert.has_error.match(function() (function()
      _drive(0, 5)
    end)() end, "invalid dice_count", 1, true)
  end)

  it("test_single_die_produces_one_value", function()
    local captured = _drive(1, 5)
    luassert.truthy(#captured.values == 1, "one die must produce one value")
    luassert.truthy(captured.values[1] == 5, "the die value must be pinned")
    luassert.truthy(captured.values[0] == nil, "the loop must start at index 1")
  end)

  it("test_two_dice_produce_two_values_and_comma_joined_text", function()
    local captured = _drive(2, 3)
    luassert.truthy(#captured.values == 2, "two dice must produce two values")
    luassert.truthy(captured.values[1] == 3 and captured.values[2] == 3, "every die must carry the configured value")
    luassert.truthy(captured.feed ~= nil and type(captured.feed.text) == "string"
      and captured.feed.text:find(",", 1, true) ~= nil, "the feed text must comma-join the values")
  end)

  it("test_queues_the_item_use_animation", function()
    local captured = _drive(1, 5)
    luassert.truthy(captured.anim ~= nil, "an action anim must be queued")
    luassert.truthy(captured.anim.kind == "item_use", "the anim kind must be item_use")
    luassert.truthy(captured.anim.player_id == 1, "the player id must be pinned")
    luassert.truthy(captured.anim.item_name ~= nil and captured.anim.item_name ~= "", "the item name must resolve")
  end)

  it("test_duration_uses_the_remote_dice_timing_when_configured", function()
    local prev = timing.remote_dice_wait_seconds
    timing.remote_dice_wait_seconds = 2.5
    local captured = _drive(1, 5)
    timing.remote_dice_wait_seconds = prev
    luassert.truthy(captured.anim.duration == 2.5, "the remote dice wait timing must drive the anim duration")
  end)

end)
