-- land_events.apply 的入口守卫:没有 result / 没有 result.event 时静默返回,
-- 不发领域事件、不进事件流。
local support = require("test.support.shared_support")
local land_events = require("src.rules.land.events")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _config_reset = require("test.support.config_reset")

-- 捕获事件流投递(emit 在模块加载期取了本地引用,打桩不到,只能从 feed 侧观测)。
local function _with_feed_capture(fn)
  local published = {}
  _with_patches({
    {
      target = event_feed,
      key = "publish",
      value = function(_, entry)
        published[#published + 1] = entry
      end,
    },
  }, function()
    fn(published)
  end)
end

TestLandEventsApplyGuards = {}

function TestLandEventsApplyGuards:setUp()
  _config_reset.reset_all()
end

function TestLandEventsApplyGuards:test_does_nothing_when_there_is_no_result(self)
  _with_feed_capture(function(published)
    land_events.apply({}, nil)
    _assert_eq(#published, 0, "a nil result must not reach the event feed")
  end)
end

function TestLandEventsApplyGuards:test_does_nothing_when_the_result_carries_no_event(self)
  _with_feed_capture(function(published)
    land_events.apply({}, { ok = true, payload = { text = "ignored" } })
    _assert_eq(#published, 0, "a result without an event must not reach the event feed")
  end)
end

function TestLandEventsApplyGuards:test_publishes_rent_paid_text_to_the_feed(self)
  _with_feed_capture(function(published)
    land_events.apply({}, { ok = true, event = "rent_paid", payload = { text = "付了租金" } })

    _assert_eq(#published, 1, "rent_paid should publish one feed entry")
    _assert_eq(published[1].kind, event_kinds.rent_paid, "feed entry should be kind rent_paid")
    _assert_eq(published[1].text, "付了租金", "feed entry should carry the payload text")
  end)
end

-- 山地免租是唯一 ok == false 仍要发事件的结果形状。apply 不看 ok,只看 event,
-- 所以这条必须单独钉住:哪天有人给 apply 加「失败就不发」的守卫,这里当场红。
function TestLandEventsApplyGuards:test_publishes_rent_skipped_mountain_even_though_the_result_failed(self)
  _with_feed_capture(function(published)
    land_events.apply({}, {
      ok = false,
      event = "rent_skipped_mountain",
      payload = { text = "在深山，租金不收取" },
    })

    _assert_eq(#published, 1, "a failed mountain skip must still publish one feed entry")
    _assert_eq(published[1].kind, event_kinds.rent_immune, "mountain skip maps to the rent_immune kind")
    _assert_eq(published[1].text, "在深山，租金不收取", "feed entry should carry the payload text")
  end)
end

function TestLandEventsApplyGuards:test_does_not_publish_a_second_rent_breakdown(self)
  _with_feed_capture(function(published)
    land_events.apply({}, {
      ok = true,
      event = "rent_paid",
      payload = {
        text = "小明向小红支付租金 120 金币（穷神、财神）",
        multiplier_text = "（穷神、财神）",
      },
    })

    _assert_eq(#published, 1, "rent_paid should publish one complete feed entry")
    _assert_eq(published[1].kind, event_kinds.rent_paid, "feed entry should be kind rent_paid")
    _assert_eq(published[1].text, "小明向小红支付租金 120 金币（穷神、财神）",
      "the feed entry should carry the final amount and compact breakdown")
  end)
end

function TestLandEventsApplyGuards:test_publishes_the_mountain_rent_immunity_event_even_though_the_settlement_failed(self)
  _with_feed_capture(function(published)
    land_events.apply({}, {
      ok = false,
      event = "rent_skipped_mountain",
      payload = { text = "山地免租" },
    })

    _assert_eq(#published, 1, "the mountain skip should still publish a feed entry")
    _assert_eq(published[1].kind, event_kinds.rent_immune, "feed entry should be kind rent_immune")
  end)
end

function TestLandEventsApplyGuards:test_skips_the_feed_when_the_payload_has_no_text(self)
  _with_feed_capture(function(published)
    land_events.apply({}, { ok = true, event = "rent_paid", payload = {} })
    _assert_eq(#published, 0, "a textless payload must not reach the event feed")
  end)
end

-- build 的 extra 形参用于构造 bankrupt_reason 等旁路字段。
-- 没有测试驱动过该分支 -> 变异体替换 pairs(extra) 为 nil 仍存活。
function TestLandEventsApplyGuards:test_build_copies_extra_keys_onto_the_result(self)
  local result = land_events.build("rent_paid", { text = "x" }, { bankrupt_reason = "资金不足" })
  _assert_eq(result.ok, true)
  _assert_eq(result.event, "rent_paid")
  _assert_eq(result.payload.text, "x")
  _assert_eq(result.bankrupt_reason, "资金不足", "extra key must be copied onto the result")
end


return TestLandEventsApplyGuards
