local lu = require("luaunit")
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local timing = require("src.config.gameplay.timing")
local base_nodes = require("src.ui.schema.base")
local cash_delta = require("src.ui.render.widgets.cash_delta")

local function _delta_label_name(index)
  return string.format(base_nodes.player_cash_delta, index)
end

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_ui()
  local ui = {
    labels = {},
    visibles = {},
    player_cash_value_cache_by_index = {},
    player_cash_delta_state_by_index = {},
  }
  function ui:set_label(name, text)
    ui.labels[name] = text
    return true
  end
  function ui:set_visible(name, visible)
    ui.visibles[name] = visible
    return true
  end
  return ui
end

local function _with_runtime_mock(fn)
  runtime_ports.reset_for_tests()
  local scheduled = {}
  runtime_ports.configure({
    schedule = function(delay, fn_sched)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn_sched }
    end,
    wall_now_seconds = function() return 0 end,
  })
  local ok, err = pcall(function()
    fn(scheduled)
  end)
  runtime_ports.reset_for_tests()
  if not ok then
    error(err, 2)
  end
end

TestCashDelta = {}

function TestCashDelta:tearDown()
  support.restore_runtime_services()
end

-- ===== _safe_ui_call 间接测试 =====

function TestCashDelta:test_set_label_returns_true_when_ui_valid()
  local ui = _make_ui()
  cash_delta.ensure_state(ui)
  -- 通过 refresh_cash_delta_label 间接测试 _safe_ui_call 成功路径
  local row = { cash_value = 100 }
  cash_delta.refresh_cash_delta_label(ui, 1, row)
  _assert_eq(ui.player_cash_value_cache_by_index[1], 100, "cash value should be cached")
end

function TestCashDelta:test_ensure_state_initializes_tables()
  local ui = {}
  cash_delta.ensure_state(ui)
  lu.assertEvalToTrue(ui.player_cash_value_cache_by_index ~= nil, "cache table should be created")
  lu.assertEvalToTrue(ui.player_cash_delta_state_by_index ~= nil, "state table should be created")
end

-- ===== refresh_cash_delta_label 核心路径 =====

function TestCashDelta:test_nil_cash_value_clears_label()
  _with_runtime_mock(function()
    local ui = _make_ui()
    cash_delta.ensure_state(ui)
    local row = {}
    cash_delta.refresh_cash_delta_label(ui, 1, row)
    _assert_eq(ui.player_cash_value_cache_by_index[1], nil, "nil cash should clear cache")
    -- entry 应被清理
    local entry = ui.player_cash_delta_state_by_index[1]
    lu.assertEvalToTrue(entry ~= nil, "entry should exist")
    _assert_eq(entry.anchor_cash, nil, "anchor_cash should be nil")
  end)
end

function TestCashDelta:test_first_cash_value_initializes_cache()
  _with_runtime_mock(function()
    local ui = _make_ui()
    cash_delta.ensure_state(ui)
    local row = { cash_value = 200 }
    cash_delta.refresh_cash_delta_label(ui, 1, row)
    _assert_eq(ui.player_cash_value_cache_by_index[1], 200, "first cash value cached")
  end)
end

function TestCashDelta:test_unchanged_cash_value_no_update()
  _with_runtime_mock(function(scheduled)
    local ui = _make_ui()
    cash_delta.ensure_state(ui)
    -- first call: initialize
    local row = { cash_value = 200 }
    cash_delta.refresh_cash_delta_label(ui, 1, row)
    -- second call: same value
    cash_delta.refresh_cash_delta_label(ui, 1, row)
    -- no schedule should be triggered for unchanged value
    _assert_eq(#scheduled, 0, "no schedule for unchanged cash")
  end)
end

function TestCashDelta:test_changed_cash_shows_label_with_correct_sign_positive()
  _with_runtime_mock(function(scheduled)
    local ui = _make_ui()
    cash_delta.ensure_state(ui)
    -- first: set to 100
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 100 })
    -- second: increase to 150
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 150 })
    -- schedule that shows label should be created (show_delay <= 0 → immediate)
    -- show_delay is timing.panel_cash_delta_show_delay_seconds or 0.0
    -- by default it's 0, so immediate show via _do_show
    local label_name = _delta_label_name(1)
    _assert_eq(ui.labels[label_name], "+50", "positive delta should show + sign")
  end)
end

function TestCashDelta:test_changed_cash_shows_label_with_correct_sign_negative()
  _with_runtime_mock(function()
    local ui = _make_ui()
    cash_delta.ensure_state(ui)
    -- first: set to 150
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 150 })
    -- second: decrease to 100
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 100 })
    local label_name = _delta_label_name(1)
    _assert_eq(ui.labels[label_name], "-50", "negative delta should show - sign")
  end)
end

function TestCashDelta:test_multiple_consecutive_changes_show_individual_deltas_not_cumulative()
  _with_runtime_mock(function()
    local ui = _make_ui()
    cash_delta.ensure_state(ui)
    -- first: 100
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 100 })
    -- second: 200 (+100)
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 200 })
    -- third: 180 (-20) — 应该显示 -20(锚点是 200),而不是 +80(累计)
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 180 })
    local label_name = _delta_label_name(1)
    _assert_eq(ui.labels[label_name], "-20", "each change should use prev value as anchor, not cumulative")
  end)
end

-- ===== show_delay 非零路径 =====

function TestCashDelta:test_positive_show_delay_schedules_show_immediately()
  _with_runtime_mock(function(scheduled)
    local ui = _make_ui()
    cash_delta.ensure_state(ui)
    -- first call: initialize with 100
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 100 })
    -- override the timing value to a positive number
    local orig_delay = timing.panel_cash_delta_show_delay_seconds
    timing.panel_cash_delta_show_delay_seconds = 0.5

    -- second call: change to 200 — should schedule the show
    cash_delta.refresh_cash_delta_label(ui, 1, { cash_value = 200 })

    timing.panel_cash_delta_show_delay_seconds = orig_delay

    lu.assertEvalToTrue(#scheduled >= 1, "non-zero show delay should schedule the show callback")
  end)
end

-- ===== ensure_state 幂等 =====

function TestCashDelta:test_ensure_state_is_idempotent()
  local ui = {}
  cash_delta.ensure_state(ui)
  local cache1 = ui.player_cash_value_cache_by_index
  local state1 = ui.player_cash_delta_state_by_index
  cash_delta.ensure_state(ui)
  _assert_eq(ui.player_cash_value_cache_by_index, cache1, "cache table preserved on second call")
  _assert_eq(ui.player_cash_delta_state_by_index, state1, "state table preserved on second call")
end

return TestCashDelta
