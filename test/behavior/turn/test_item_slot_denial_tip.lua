-- item_slot_denial_tip 直测:tip_output_port 缺位时回落 tip_queue 直投,
-- intent 五字段全钉(文案/时长/去重键/role_id/source)。
-- (#260 变异清扫 survivor 闭合:_enqueue 的 tip_queue.enqueue -> nil)
local support = require("test.support.shared_support")
local tip_queue = require("src.foundation.tips")
local denial_cfg = require("src.config.content.item_slot_denial")
local denial_tip = require("src.turn.actions.item_slot_denial_tip")

local _assert_eq = support.assert_eq

TestItemSlotDenialTip = {}

function TestItemSlotDenialTip:test_falls_back_to_tip_queue_enqueue_with_the_full_intent_when_no_tip_output_port()
  -- kills _enqueue's `tip_queue.enqueue(intent)` -> nil.
  local captured = {}
  local result
  support.with_patches({
    { target = tip_queue, key = "enqueue", value = function(intent)
      captured[#captured + 1] = intent
      return true
    end },
  }, function()
    result = denial_tip.emit({}, 7, 2001, "not_current_turn")
  end)
  _assert_eq(result, true, "the fallback returns the enqueue result")
  _assert_eq(#captured, 1, "exactly one intent is enqueued")
  local intent = captured[1]
  _assert_eq(intent.text, denial_cfg.text_for_reason("not_current_turn"),
    "the denial text comes from the config")
  _assert_eq(intent.duration, denial_cfg.DURATION, "the duration comes from the config")
  _assert_eq(intent.dedupe_key, denial_cfg.dedupe_key(7, 2001, "not_current_turn"),
    "the dedupe key comes from the config")
  _assert_eq(intent.role_id, 7, "the tip targets the clicking role")
  _assert_eq(intent.source, "turn.item_slot", "the tip source is turn.item_slot")
end

function TestItemSlotDenialTip:test_prefers_tip_output_port_enqueue_when_present()
  local port_calls = {}
  local queue_calls = 0
  local result
  support.with_patches({
    { target = tip_queue, key = "enqueue", value = function() queue_calls = queue_calls + 1 end },
  }, function()
    local game = { tip_output_port = { enqueue = function(g, intent)
      port_calls[#port_calls + 1] = { game = g, intent = intent }
      return "via-port"
    end } }
    result = denial_tip.emit(game, 7, 2001, "not_current_turn")
  end)
  _assert_eq(result, "via-port", "the port result flows back")
  _assert_eq(#port_calls, 1, "the port receives exactly one intent")
  _assert_eq(port_calls[1].intent.role_id, 7, "the intent carries the clicking role")
  _assert_eq(queue_calls, 0, "the queue fallback is not used when the port exists")
end


return TestItemSlotDenialTip
