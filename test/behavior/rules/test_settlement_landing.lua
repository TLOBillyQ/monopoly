-- settlement_landing 直测:跟随落地(followup landing)机制全家——relocation 动画判定、
-- wait key、深度上限、stop_if / optional_cost_resolver / on_need_landing 三个 pipeline
-- 回调,以及入口三守卫。集成 spec 只驱动主落地路径(变异清扫 #259 survivor 真缺口
-- 闭合);effect_pipeline.run 桩把三个回调捕获出来直驱,被测模块本体不桩。
require("test.bootstrap").install_package_paths()
local luassert = assert
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local effect_pipeline = require("src.rules.effects.pipeline")
local land_actions = require("src.rules.land.actions")
local pricing = require("src.rules.land.pricing")
local landing = require("src.rules.land.settlement_landing")

-- game 桩:find_player_by_id 对 nil id 返回 nil;board.get_tile 记录查询序。
local function _make_game(opts)
  opts = opts or {}
  local game = {
    turn = opts.turn or {},
    find_player_by_id = function(_, pid)
      if pid == nil then
        return nil
      end
      return { id = pid, position = opts.target_position or 6, name = "P" .. tostring(pid) }
    end,
  }
  if not opts.no_board then
    local queried = {}
    game.board = {
      queried = queried,
      get_tile = function(_, index)
        queried[#queried + 1] = index
        if opts.tile_at == nil then
          return { index = index }
        end
        return opts.tile_at[index]
      end,
    }
  end
  return game
end

local _tile = { id = 7, type = "land", name = "T" }

-- effect_pipeline.run 桩:捕获 opts,behavior(opts) 决定返回值。
local function _run_with(behavior, fn)
  local captured = { calls = 0 }
  with_patches({
    { target = effect_pipeline, key = "run", value = function(_, player, tile, _, opts)
      captured.calls = captured.calls + 1
      captured.player = player
      captured.tile = tile
      captured.opts = opts
      return behavior(opts, captured.calls)
    end },
  }, fn)
  return captured
end

local function _begin(game, context)
  return landing.begin_landing_settlement(game, 1, context or { tile = _tile })
end

describe("TestSettlementLanding", function()
it("test_begin_landing_settlement_guards_nil_game_missing_actor_and_missing_tile", function()
  local no_game = landing.begin_landing_settlement(nil, 1, { tile = _tile })
  luassert.truthy(no_game.ok == false and no_game.reason == "missing_game", "nil game rejects")

  local no_actor = landing.begin_landing_settlement({}, 1, { tile = _tile })
  luassert.truthy(no_actor.ok == false and no_actor.reason == "missing_actor", "unresolvable actor rejects")

  local no_tile = _begin(_make_game({ no_board = true }), {})
  luassert.truthy(no_tile.ok == false and no_tile.reason == "missing_tile", "unresolvable tile rejects")
end)

it("test_with_ok_marks_a_plain_pipeline_result_ok_and_a_nil_result_settles", function()
  local plain = _run_with(function()
    return { status = "resolved" }
  end, function()
    local result = _begin(_make_game())
    luassert.truthy(result.status == "resolved" and result.ok == true, "with_ok fills ok")
  end)
  luassert.truthy(plain.calls == 1, "pipeline ran once")

  _run_with(function()
    return nil
  end, function()
    local result = _begin(_make_game())
    luassert.truthy(result.ok == true and result.status == "settled" and result.settled == true,
      "nil pipeline result falls back to settled")
  end)
end)

it("test_stop_if_stops_on_ok_false_rejected_status_and_need_landing_kind_only", function()
  local captured = _run_with(function()
    return { status = "resolved" }
  end, function()
    _begin(_make_game())
  end)
  local stop_if = captured.opts.stop_if

  luassert.is_true(stop_if({ ok = false }))
  luassert.is_true(stop_if({ status = "rejected" }))
  luassert.is_true(stop_if({ kind = "need_landing" }))
  luassert.is_false(stop_if({ ok = true, status = "resolved" }))
  luassert.is_false(stop_if("not-a-table"))
end)

it("test_optional_cost_resolver_prices_upgrade_land_and_ignores_everything_else", function()
  local captured = _run_with(function()
    return { status = "resolved" }
  end, function()
    _begin(_make_game())
  end)
  local resolver = captured.opts.optional_cost_resolver
  local game = _make_game()

  luassert.is_nil(resolver("other_effect", _tile, game), "non-upgrade effect has no cost")
  luassert.is_nil(resolver("upgrade_land", nil, game), "nil tile has no cost")
  luassert.is_nil(resolver("upgrade_land", _tile, nil), "nil game has no cost")

  with_patches({
    { target = land_actions, key = "safe_tile_state", value = function()
      return { level = 2 }
    end },
    { target = pricing, key = "upgrade_cost", value = function(_, level)
      return 100 + level
    end },
  }, function()
    luassert.is.equal(resolver("upgrade_land", _tile, game), 102)
  end)

  with_patches({
    { target = land_actions, key = "safe_tile_state", value = function()
      return nil
    end },
    { target = pricing, key = "upgrade_cost", value = function(_, level)
      return 200 + level
    end },
  }, function()
    luassert.is.equal(resolver("upgrade_land", _tile, game), 200)
  end)
end)

it("test_followup_with_wait_move_anim_builds_the_move_followup_wait_result", function()
  local out = { wait_move_anim = true, move_result = "m" }
  _run_with(function(opts)
    return opts.on_need_landing(out)
  end, function()
    local result = _begin(_make_game())
    luassert.truthy(result.ok == true and result.waiting == true and result.reason == "followup_landing_wait",
      "followup waits with followup_landing_wait")
    luassert.truthy(result.wait_move_anim == true, "wait key is wait_move_anim")
    luassert.truthy(result.next_state == "move_followup", "next state is move_followup")
    luassert.truthy(result.next_args ~= nil and result.next_args.mode == "resolve_landing"
      and result.next_args.player_id == 1 and result.next_args.move_result == "m",
      "next args carry the fallback player and the move result")
  end)
end)

it("test_followup_with_a_pending_relocation_anim_waits_with_wait_action_anim", function()
  local out = { move_result = "m" }
  _run_with(function(opts)
    return opts.on_need_landing(out)
  end, function()
    local result = _begin(_make_game({ turn = { action_anim = { kind = "forced_relocation" } } }))
    luassert.truthy(result.waiting == true and result.wait_action_anim == true,
      "relocation anim pending waits with wait_action_anim")
  end)
end)

it("test_followup_targeting_another_player_resolves_that_player_into_next_args", function()
  local out = { wait_move_anim = true, player_id = 2, move_result = "m" }
  _run_with(function(opts)
    return opts.on_need_landing(out)
  end, function()
    local result = _begin(_make_game())
    luassert.truthy(result.next_args.player_id == 2, "explicit player_id wins over the fallback")
  end)
end)

it("test_followup_without_any_wait_recurses_into_the_next_landing", function()
  local game = _make_game()
  local out = { board_index = 5, move_result = "m" }
  local captured = _run_with(function(opts, calls)
    if calls == 1 then
      return opts.on_need_landing(out)
    end
    return { status = "second_landing" }
  end, function()
    local result = _begin(game)
    luassert.truthy(result.status == "second_landing" and result.ok == true,
      "no wait continues the landing chain")
  end)
  luassert.truthy(captured.calls == 2, "pipeline ran for the followup landing")
  luassert.truthy(game.board.queried[1] == 5, "followup tile resolves by board_index")
end)

it("test_followup_prefers_out_board_index_over_the_target_position", function()
  local game = _make_game()
  local out = { board_index = 9, move_result = "m" }
  _run_with(function(opts, calls)
    if calls == 1 then
      return opts.on_need_landing(out)
    end
    return { status = "done" }
  end, function()
    _begin(game)
  end)
  luassert.truthy(game.board.queried[1] == 9, "board_index wins over position 4")
end)

it("test_followup_returns_out_unchanged_when_the_next_tile_does_not_resolve", function()
  local out = { board_index = 5, move_result = "m" }
  local captured = _run_with(function(opts)
    return opts.on_need_landing(out)
  end, function()
    local result = _begin(_make_game({ tile_at = {} }))
    luassert.truthy(result.move_result == "m" and result.ok == true,
      "unresolvable next tile returns the followup out")
  end)
  luassert.truthy(captured.calls == 1, "no recursion without a next tile")
end)

it("test_followup_returns_out_unchanged_when_the_game_has_no_board", function()
  local out = { board_index = 1, move_result = "m" }
  _run_with(function(opts)
    return opts.on_need_landing(out)
  end, function()
    local result = _begin(_make_game({ no_board = true }))
    luassert.truthy(result.move_result == "m" and result.ok == true,
      "board-less game returns the followup out")
  end)
end)

it("test_followup_chain_rejects_at_the_depth_cap_with_the_out_attached", function()
  local out = { board_index = 1, move_result = "m" }
  local captured = _run_with(function(opts)
    return opts.on_need_landing(out)
  end, function()
    local result = _begin(_make_game())
    luassert.truthy(result.ok == false and result.status == "rejected"
      and result.reason == "landing_depth_exceeded",
      "depth cap rejects with landing_depth_exceeded")
    luassert.is.equal(result.followup, out)
  end)
  -- 深度从 0 起,第 11 次 pipeline 后触顶;depth 默认值的 0→1 变异会提前一次。
  luassert.truthy(captured.calls == 11, "depth counts from 0 to the cap of 10")
end)

it("test_explicit_context_depth_shortens_the_followup_chain", function()
  -- 入口契约:begin_landing_settlement 按 context.depth or 0 给初值(见 _landing_opts)。
  -- depth=9 时第一次 followup 后 depth=10 即触顶;`(context or {}).depth` 里的 or→and
  -- 变异会把 depth 抹成恒 0,让链路跑到第 11 次才触顶。
  local out = { board_index = 1, move_result = "m" }
  local captured = _run_with(function(opts)
    return opts.on_need_landing(out)
  end, function()
    local result = landing.begin_landing_settlement(_make_game(), 1, { tile = _tile, depth = 9 })
    luassert.truthy(result.ok == false and result.status == "rejected"
      and result.reason == "landing_depth_exceeded",
      "explicit depth near the cap still rejects")
  end)
  luassert.truthy(captured.calls == 2, "depth 9 caps on the second pipeline call (9 then 10)")
end)

it("test_followup_recursion_increments_depth_across_the_chain", function()
  -- 链路小于上限时不触顶:depth 随递归增长(or→and 变异会让深度停在 0 无限递归)。
  local out = { board_index = 1, move_result = "m" }
  local captured = _run_with(function(opts, calls)
    if calls <= 3 then
      return opts.on_need_landing(out)
    end
    return { status = "done" }
  end, function()
    local result = _begin(_make_game())
    luassert.truthy(result.status == "done", "short chain completes below the cap")
  end)
  luassert.truthy(captured.calls == 4, "three followups then the final landing")
end)

it("test__has_pending_relocation_action_anim_pins_the_relocation_kind_matrix", function()
  local has_pending = landing._M_test._has_pending_relocation_action_anim

  luassert.is_false(has_pending(nil))
  luassert.is_false(has_pending({}))
  luassert.is_false(has_pending({ turn = {} }))
  luassert.is_false(has_pending({ turn = { action_anim = { kind = "other" } } }))
  luassert.is_true(has_pending({ turn = { action_anim = { kind = "move_effect" } } }))
  luassert.is_true(has_pending({ turn = { action_anim = { kind = "teleport_effect" } } }))
  luassert.is_true(has_pending({ turn = { action_anim = { kind = "forced_relocation" } } }))
  luassert.is_false(has_pending({ turn = { action_anim_queue = "not-a-table" } }))
  luassert.is_false(has_pending({ turn = { action_anim_queue = {} } }))
  luassert.is_false(has_pending({ turn = { action_anim_queue = { { kind = "other" } } } }))
  luassert.is_true(has_pending({ turn = { action_anim_queue = { { kind = "move_effect" } } } }))
end)


end)
