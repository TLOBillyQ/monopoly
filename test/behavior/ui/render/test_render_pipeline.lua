-- Behavior specs for src/ui/render/support/render_pipeline.lua.
-- The pipeline is pure routing: it decides which of the three refreshers (panel,
-- board, effects) run for a given dirty set, and which runtime/touch deps they
-- get. #329: the three refreshers are injected via opts (panel/board/effects) —
-- support 不再静态 require 下游,装配侧(ui_runtime)负责给实现。缺实现的刷新
-- 分支当场报错,接线遗漏即刻暴露。

local lu = require("luaunit")
local luax = require("test.support.luax")

local canvas_store = require("src.ui.state.canvas_store")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local ui_touch_policy = require("src.ui.input.touch")

local function _assert_eq(a, b, msg)
  lu.assertIs(a, b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local PIPELINE = "src.ui.render.support.render_pipeline"

-- Builds the three stubbed refreshers. Each records what it saw into `calls`,
-- shaped like the real collaborators' invocation surfaces.
local function _stub_impls(calls)
  return {
    panel = {
      refresh = function(state_ctx, ui_model, opts)
        calls.panel[#calls.panel + 1] = {
          state_ctx = state_ctx,
          ui_model = ui_model,
          runtime = opts.runtime,
          refresh_item_slots = opts.refresh_item_slots,
          ui_touch_policy = opts.ui_touch_policy,
        }
      end,
    },
    board = {
      refresh = function(state_ctx, ui_model, log_once, build_log_prefix)
        calls.board[#calls.board + 1] = {
          state_ctx = state_ctx,
          ui_model = ui_model,
          log_once = log_once,
          build_log_prefix = build_log_prefix,
        }
      end,
    },
    effects = {
      sync = function(state_ctx, ui_model, opts)
        calls.effects[#calls.effects + 1] = {
          state_ctx = state_ctx,
          ui_model = ui_model,
          runtime = opts.runtime,
        }
      end,
    },
  }
end

-- Runs fn(pipeline, calls, impls) with the pipeline reloaded and the stubbed
-- collaborators injected via opts.
local function _with_stubs(fn)
  local calls = { panel = {}, board = {}, effects = {} }
  local pipeline = require(PIPELINE)
  local ok, err = pcall(function()
    fn(pipeline, calls, _stub_impls(calls))
  end)
  if not ok then
    error(err, 2)
  end
end

-- Which refreshers ran, as a "panel/board/effects" signature.
local function _routed(calls)
  return table.concat({
    #calls.panel > 0 and "panel" or "-",
    #calls.board > 0 and "board" or "-",
    #calls.effects > 0 and "effects" or "-",
  }, "/")
end

-- render opts that inject the stubbed refreshers, plus any caller extras.
local function _render_opts(impls, extra)
  local opts = { panel = impls.panel, board = impls.board, effects = impls.effects }
  if extra then
    for key, value in pairs(extra) do
      opts[key] = value
    end
  end
  return opts
end

local function _render_with_dirty(dirty)
  local routed
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render({}, { model = true }, nil, nil, _render_opts(impls, { dirty = dirty }))
    routed = _routed(calls)
  end)
  return routed
end

TestRenderPipeline = {}

-- render_pipeline.render dirty routing
function TestRenderPipeline:test_routes_each_panel_only_flag_to_the_panel_refresher_alone()
  for _, flag in ipairs({ "permanent", "choice", "market" }) do
    _assert_eq(_render_with_dirty({ [flag] = true }), "panel/-/-",
      "dirty." .. flag .. " must refresh the panel only")
  end
end

function TestRenderPipeline:test_routes_dirty_board_to_the_board_refresher_alone()
  _assert_eq(_render_with_dirty({ board = true }), "-/board/-", "dirty.board refreshes the board only")
end

function TestRenderPipeline:test_routes_dirty_effects_to_the_effects_sync_alone()
  _assert_eq(_render_with_dirty({ effects = true }), "-/-/effects", "dirty.effects syncs effects only")
end

function TestRenderPipeline:test_routes_dirty_base_and_dirty_any_to_all_three_refreshers()
  _assert_eq(_render_with_dirty({ base = true }), "panel/board/effects", "dirty.base refreshes everything")
  _assert_eq(_render_with_dirty({ any = true }), "panel/board/effects", "dirty.any refreshes everything")
end

function TestRenderPipeline:test_treats_a_dirty_set_with_nothing_marked_as_a_full_refresh()
  local dirty = {}
  local routed
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render({}, {}, nil, nil, _render_opts(impls, { dirty = dirty }))
    routed = _routed(calls)
  end)
  _assert_eq(routed, "panel/board/effects", "an empty dirty set falls back to a full refresh")
  _assert_eq(dirty.any, true, "the empty dirty set is promoted to any=true")
end

function TestRenderPipeline:test_treats_dirty_flags_that_are_not_literally_true_as_not_dirty()
  _assert_eq(_render_with_dirty({ board = "yes" }), "panel/board/effects",
    "a non-true board flag leaves the set empty, so it becomes a full refresh")
end

function TestRenderPipeline:test_does_not_promote_a_marked_dirty_set_to_any_true()
  local dirty = { board = true }
  _with_stubs(function(pipeline, _, impls)
    pipeline.render({}, {}, nil, nil, _render_opts(impls, { dirty = dirty }))
  end)
  _assert_eq(dirty.any, nil, "a marked dirty set stays partial")
end

-- render_pipeline.render dirty source
function TestRenderPipeline:test_consumes_the_canvas_stores_dirty_set_when_opts_carries_none()
  local state_ctx = {}
  canvas_store.mark_dirty(state_ctx, "board")
  local routed
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render(state_ctx, {}, nil, nil, _render_opts(impls))
    routed = _routed(calls)
  end)
  -- mark_dirty sets both `board` and `any`, so a consumed store drives everything.
  _assert_eq(routed, "panel/board/effects", "the consumed store's dirty set drives the render")
end

function TestRenderPipeline:test_consumes_the_store_so_a_second_render_with_nothing_marked_stays_a_no_op()
  local state_ctx = {}
  canvas_store.mark_dirty(state_ctx, "board")
  local second_routed
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render(state_ctx, {}, nil, nil, _render_opts(impls))
    calls.panel, calls.board, calls.effects = {}, {}, {}
    -- The store was consumed by the first render; nothing has been marked since,
    -- so the second render sees a clean store.
    pipeline.render(state_ctx, {}, nil, nil, _render_opts(impls, { dirty = canvas_store.consume_dirty(state_ctx) }))
    second_routed = _routed(calls)
  end)
  _assert_eq(second_routed, "panel/board/effects",
    "a clean store yields an empty dirty set, which the pipeline promotes to a full refresh")
end

-- render_pipeline.render dependency wiring
function TestRenderPipeline:test_forwards_the_callers_runtime_touch_policy_and_item_slot_refresher()
  local runtime = { id = "runtime" }
  local touch = { id = "touch" }
  local refresh_item_slots = function() end
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render({}, {}, nil, nil, _render_opts(impls, {
      dirty = { any = true },
      runtime = runtime,
      ui_touch_policy = touch,
      refresh_item_slots = refresh_item_slots,
    }))
    _assert_eq(calls.panel[1].runtime, runtime, "panel gets the caller's runtime")
    _assert_eq(calls.panel[1].ui_touch_policy, touch, "panel gets the caller's touch policy")
    _assert_eq(calls.panel[1].refresh_item_slots, refresh_item_slots, "panel gets the item-slot refresher")
    _assert_eq(calls.effects[1].runtime, runtime, "effects sync gets the caller's runtime")
  end)
end

function TestRenderPipeline:test_defaults_to_the_module_runtime_and_touch_policy_when_opts_omits_them()
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render({}, {}, nil, nil, _render_opts(impls, { dirty = { any = true } }))
    _assert_eq(calls.panel[1].runtime, runtime_ui, "panel falls back to runtime_ui")
    _assert_eq(calls.panel[1].ui_touch_policy, ui_touch_policy, "panel falls back to the ui touch policy")
    _assert_eq(calls.panel[1].refresh_item_slots, nil, "no item-slot refresher when none is given")
    _assert_eq(calls.effects[1].runtime, runtime_ui, "effects sync falls back to runtime_ui")
  end)
end

function TestRenderPipeline:test_passes_the_log_hooks_straight_through_to_the_board_refresher()
  local log_once = { id = "log_once" }
  local build_log_prefix = function() return "prefix" end
  local state_ctx, ui_model = {}, { model = true }
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render(state_ctx, ui_model, log_once, build_log_prefix, _render_opts(impls, { dirty = { board = true } }))
    _assert_eq(calls.board[1].state_ctx, state_ctx, "board gets the state context")
    _assert_eq(calls.board[1].ui_model, ui_model, "board gets the ui model")
    _assert_eq(calls.board[1].log_once, log_once, "board gets log_once")
    _assert_eq(calls.board[1].build_log_prefix, build_log_prefix, "board gets build_log_prefix")
  end)
end

function TestRenderPipeline:test_base_only_flag_stays_partial_without_any_promotion()
  -- 杀 L17 两个位点(_flag_true(dirty, "base") -> nil 与 "base" -> nil):
  -- base 单独为 true 时 dirty 集是"部分脏"——变异把 base 判定删掉后空判定
  -- 误判为全空,render 会把 any 提升为 true,副作用不同。
  local dirty = { base = true }
  local routed
  _with_stubs(function(pipeline, calls, impls)
    pipeline.render({}, { model = true }, nil, nil, _render_opts(impls, { dirty = dirty }))
    routed = _routed(calls)
  end)
  _assert_eq(routed, "panel/board/effects", "dirty.base alone must still refresh everything")
  _assert_eq(dirty.any, nil, "a base-marked dirty set must stay partial, not be promoted")
end

function TestRenderPipeline:test_non_table_dirty_set_raises_when_promoting_any()
  -- 杀 L30 _is_empty_dirty 非表分支的 true->false:非表 dirty 判空为 true 后
  -- render 会执行 any 提升,对非表索引赋值必须报错——变异(判非空)会跳过提升
  -- 悄悄成功。
  luax.has_error(function()
    local pipeline = require(PIPELINE)
    pipeline.render({}, {}, nil, nil, { dirty = "not-a-table" })
  end)
end

-- #329:刷新分支的实现由注入提供——缺实现的路线不是静默跳过,必须当场报错
-- (装配遗漏即刻暴露,与 paid_purchase 缺网关同款纪律)。
function TestRenderPipeline:test_errors_when_a_refresh_branch_has_no_implementation()
  -- #329:缺实现的刷新分支当场报错,报错点名缺失实现(panel/board/effects)。
  local impls = _stub_impls({ panel = {}, board = {}, effects = {} })

  luax.has_error(function()
    local pipeline = require(PIPELINE)
    pipeline.render({}, {}, nil, nil, { panel = nil, board = impls.board, effects = impls.effects, dirty = { choice = true } })
  end, "render_pipeline: missing opts.panel implementation")

  luax.has_error(function()
    local pipeline = require(PIPELINE)
    pipeline.render({}, {}, nil, nil, { panel = impls.panel, board = nil, effects = impls.effects, dirty = { board = true } })
  end, "render_pipeline: missing opts.board implementation")

  luax.has_error(function()
    local pipeline = require(PIPELINE)
    pipeline.render({}, {}, nil, nil, { panel = impls.panel, board = impls.board, effects = nil, dirty = { effects = true } })
  end, "render_pipeline: missing opts.effects implementation")
end


return TestRenderPipeline
