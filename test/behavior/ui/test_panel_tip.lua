-- panel_tip.enqueue 补测:blocks_inter_turn=false 的 false→true 突变体。
local support = require("test.support.shared_support")
local tip_queue = require("src.foundation.tips")
local panel_tip = require("src.ui.coord.panel_tip")

local _assert_eq = support.assert_eq

TestPanelTip = {}

function TestPanelTip:test_enqueue_sets_blocks_inter_turn_false()
  local captured = nil
  support.with_patches({
    { target = tip_queue, key = "enqueue", value = function(tip)
      captured = tip
    end },
  }, function()
    panel_tip.enqueue("test_src", "hello", "key1")
  end)

  _assert_eq(captured.blocks_inter_turn, false,
    "panel_tip should always set blocks_inter_turn to false")
  _assert_eq(captured.text, "hello",
    "panel_tip should pass through text")
  _assert_eq(captured.source, "test_src",
    "panel_tip should pass through source")
  _assert_eq(captured.dedupe_key, "key1",
    "panel_tip should pass through dedupe_key")
end

return TestPanelTip
