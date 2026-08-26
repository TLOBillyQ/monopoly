-- angel_feedback.publish 直测:守卫(target 非空/item_label 非空串)、
-- event_feed 发布契约(tip 标志/source)与 emit 的 tile_index 透传。
local lu = require("luaunit")
local luax = require("test.support.luax")
local support = require("test.support.shared_support")

local angel_feedback = require("src.rules.items.angel_feedback")
local event_feed = require("src.rules.ports.event_feed")
local monopoly_event = require("src.foundation.events")

TestAngelFeedback = {}

local function _drive(item_label, opts)
  local captured = {}
  support.with_patches({
    { target = event_feed, key = "publish", value = function(_, payload)
      captured.feed = payload
    end },
    { target = monopoly_event, key = "emit", value = function(_, payload)
      captured.emit = payload
    end },
  }, function()
    angel_feedback.publish({}, { id = 3, name = "P3" }, item_label, opts)
  end)
  return captured
end

function TestAngelFeedback:test_rejects_a_nil_target()
  luax.has_error(function()
    angel_feedback.publish({}, nil, "导弹")
  end, "missing target")
end

function TestAngelFeedback:test_rejects_a_non_string_item_label()
  luax.has_error(function()
    angel_feedback.publish({}, { id = 3 }, 42)
  end, "missing item_label")
end

function TestAngelFeedback:test_rejects_an_empty_item_label()
  luax.has_error(function()
    angel_feedback.publish({}, { id = 3 }, "")
  end, "missing item_label")
end

function TestAngelFeedback:test_publishes_an_immune_feedback_with_tip_flag()
  local captured = _drive("导弹")
  lu.assertEvalToTrue(captured.feed ~= nil, "an immune feedback must be published")
  lu.assertEvalToTrue(captured.feed.tip == true, "the feedback must be a tip")
  lu.assertEvalToTrue(captured.feed.source == "rules.items.angel_feedback",
    "the feedback source must be pinned")
  lu.assertEvalToTrue(captured.feed.text:find("天使保护", 1, true) ~= nil,
    "the feedback text must mention the angel protection")
end

function TestAngelFeedback:test_emit_passes_the_tile_index_through()
  local captured = _drive("导弹", { tile_index = 9 })
  lu.assertEvalToTrue(captured.emit ~= nil, "an immune event must be emitted")
  lu.assertEvalToTrue(captured.emit.player_id == 3, "the protected player must be pinned")
  lu.assertEvalToTrue(captured.emit.tile_index == 9, "the tile index must pass through")
end

function TestAngelFeedback:test_emit_leaves_tile_index_nil_when_absent()
  local captured = _drive("导弹")
  lu.assertEvalToTrue(captured.emit ~= nil, "an immune event must be emitted")
  lu.assertEvalToTrue(captured.emit.tile_index == nil, "no tile index without opts")
end

return TestAngelFeedback
