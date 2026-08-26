-- #293 批3 pin:src/turn/deadlines/force_skip.lua 的 29 个幸存者集中在
-- 预消费退款守卫链(_should_refund_preconsume)、foundation 事件发射链
-- (_emitable/_force_skip_payload/_emit_foundation_event)与日志字符串。
-- 策略:桩 package.loaded 的 item_preconsume_policy / foundation.events,
-- 经 api.force_skip 直测可观测面(退款是否调用、事件名与 payload 字段)。

local lu = require("luaunit")
local force_skip = require("src.turn.deadlines.force_skip")

local _refund_spy = nil
local _emit_spy = nil
local _loaded_policy = package.loaded["src.rules.choice.item_preconsume_policy"]
local _loaded_events = package.loaded["src.foundation.events"]

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _new_api()
  local cancelled = {}
  local api = {
    cancel = function(_, state, kind)
      cancelled[#cancelled + 1] = kind
    end,
  }
  return api, cancelled
end

local function _base_state()
  return {
    _game = { marker = true },
    pending_confirmation = nil,
    _choice_force_skip_pending = false,
  }
end

TestForceSkip = {}

function TestForceSkip:setUp()
  _refund_spy = { calls = {} }
  _emit_spy = { calls = {} }
end

function TestForceSkip:tearDown()
  package.loaded["src.rules.choice.item_preconsume_policy"] = _loaded_policy
  package.loaded["src.foundation.events"] = _loaded_events
end

local function _preconsumed_choice()
  return {
    id = "c7",
    kind = "k9",
    meta = { item_preconsumed = true, item_id = "it1" },
    owner_role_id = "r1",
  }
end

function TestForceSkip:test_refunds_preconsumed_choice_with_state_game()
  -- L14 `game or (state and state._game or nil)` 的 and->or:退款必须收到
  -- state._game 而非整个 state 表。
  package.loaded["src.rules.choice.item_preconsume_policy"] = {
    refund = function(game, choice)
      _refund_spy.calls[#_refund_spy.calls + 1] = { game = game, choice = choice }
    end,
  }
  local api = _new_api()
  local state = _base_state()
  force_skip.install(api)
  api.force_skip(nil, state, _preconsumed_choice(), "manual")
  _assert_eq(#_refund_spy.calls, 1, "preconsumed choice must be refunded")
  _assert_eq(_refund_spy.calls[1].game, state._game, "refund must receive the state game")
  _assert_eq(_refund_spy.calls[1].choice.owner_role_id, "r1", "refund must receive the choice")
end

function TestForceSkip:test_does_not_refund_non_preconsumed_or_incomplete_choices()
  -- L9 `return false` -> true(choice 无 meta 表)/ L12 `return false` -> true
  -- (item_preconsumed 非 true):都必须不退款。
  package.loaded["src.rules.choice.item_preconsume_policy"] = {
    refund = function(game, choice)
      _refund_spy.calls[#_refund_spy.calls + 1] = true
    end,
  }
  local api = _new_api()
  local state = _base_state()
  force_skip.install(api)

  api.force_skip(nil, state, { id = "c" }, "manual")
  _assert_eq(#_refund_spy.calls, 0, "choice without meta must not refund")

  api.force_skip(nil, state, { id = "c", meta = {} }, "manual")
  _assert_eq(#_refund_spy.calls, 0, "choice without preconsume meta must not refund")

  local incomplete = _preconsumed_choice()
  incomplete.owner_role_id = nil
  api.force_skip(nil, state, incomplete, "manual")
  _assert_eq(#_refund_spy.calls, 0, "choice without owner_role_id must not refund")
end

function TestForceSkip:test_emits_foundation_event_with_full_payload()
  -- L56 `pcall(require, "src.foundation.events")` 整体/字符串换 nil、L40
  -- _emitable 六连变异、L57 `ok and _emitable(...)` 的 and->or(本桩下同真)、
  -- L44 `_choice_field` 的 or->and、L58 事件名/载荷换 nil、L49 原因缺省与
  -- L50/L51 字段名换 nil:发射面必须带完整 payload。
  package.loaded["src.foundation.events"] = {
    emit = function(event_name, payload)
      _emit_spy.calls[#_emit_spy.calls + 1] = { event_name = event_name, payload = payload }
    end,
  }
  local api = _new_api()
  local state = _base_state()
  force_skip.install(api)
  api.force_skip(nil, state, _preconsumed_choice(), "manual")
  _assert_eq(#_emit_spy.calls, 1, "force skip must emit the foundation event")
  _assert_eq(_emit_spy.calls[1].event_name, "fb.choice_force_skipped",
    "event name must be fb.choice_force_skipped")
  local payload = _emit_spy.calls[1].payload
  lu.assertEvalToTrue(type(payload) == "table", "payload must be a table")
  _assert_eq(payload.reason, "manual", "explicit reason must carry through")
  _assert_eq(payload.choice_id, "c7", "choice id must carry through")
  _assert_eq(payload.kind, "k9", "choice kind must carry through")
end

function TestForceSkip:test_emits_default_reason_when_none_given()
  -- L49 `reason or "tick_timeout"` 的 tick_timeout 换 nil:nil 原因必须落默认值。
  package.loaded["src.foundation.events"] = {
    emit = function(event_name, payload)
      _emit_spy.calls[#_emit_spy.calls + 1] = { event_name = event_name, payload = payload }
    end,
  }
  local api = _new_api()
  local state = _base_state()
  force_skip.install(api)
  api.force_skip(nil, state, _preconsumed_choice(), nil)
  _assert_eq(_emit_spy.calls[1].payload.reason, "tick_timeout",
    "nil reason must default to tick_timeout")
end

function TestForceSkip:test_does_not_emit_when_events_module_has_no_emit_function()
  -- L40 `type(monopoly_events.emit) == "function"` 链的 and->or 与
  -- L57 `ok and _emitable(...)` 的 and->or:模块无 emit 时基线静默跳过,
  -- 变异体 pcall(nil) 撞错。
  package.loaded["src.foundation.events"] = {
    not_an_emit = true,
  }
  local api = _new_api()
  local state = _base_state()
  force_skip.install(api)
  api.force_skip(nil, state, _preconsumed_choice(), "manual")
  lu.assertEvalToTrue(#_emit_spy.calls == 0, "module without emit must not be called")
end

return TestForceSkip
