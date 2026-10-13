require("test.bootstrap").install_package_paths()
local luassert = assert(require("test.support.luassert_loader").load())
-- angel_feedback.publish 直测:守卫(target 非空/item_label 非空串)、
-- event_feed 发布契约(tip 标志/source)与 emit 的 tile_index 透传。
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
  luassert.has_error(function()
    angel_feedback.publish({}, nil, "导弹")
  end, "missing target")
end

function TestAngelFeedback:test_rejects_a_non_string_item_label()
  luassert.has_error(function()
    angel_feedback.publish({}, { id = 3 }, 42)
  end, "missing item_label")
end

function TestAngelFeedback:test_rejects_an_empty_item_label()
  luassert.has_error(function()
    angel_feedback.publish({}, { id = 3 }, "")
  end, "missing item_label")
end

function TestAngelFeedback:test_publishes_an_immune_feedback_with_tip_flag()
  local captured = _drive("导弹")
  luassert.truthy(captured.feed ~= nil, "an immune feedback must be published")
  luassert.truthy(captured.feed.tip == true, "the feedback must be a tip")
  luassert.truthy(captured.feed.source == "rules.items.angel_feedback", "the feedback source must be pinned")
  luassert.truthy(captured.feed.text:find("天使保护", 1, true) ~= nil, "the feedback text must mention the angel protection")
end

function TestAngelFeedback:test_emit_passes_the_tile_index_through()
  local captured = _drive("导弹", { tile_index = 9 })
  luassert.truthy(captured.emit ~= nil, "an immune event must be emitted")
  luassert.truthy(captured.emit.player_id == 3, "the protected player must be pinned")
  luassert.truthy(captured.emit.tile_index == 9, "the tile index must pass through")
end

function TestAngelFeedback:test_emit_leaves_tile_index_nil_when_absent()
  local captured = _drive("导弹")
  luassert.truthy(captured.emit ~= nil, "an immune event must be emitted")
  luassert.truthy(captured.emit.tile_index == nil, "no tile index without opts")
end

return TestAngelFeedback
