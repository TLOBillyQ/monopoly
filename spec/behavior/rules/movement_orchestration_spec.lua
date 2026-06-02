local movement = require("src.rules.movement")
local movement_context = require("src.rules.movement_context")
local movement_events = require("src.rules.movement_events")
local mine_effect = require("src.rules.effects.mine")

local function _assert_eq(actual, expected, label)
  assert(actual == expected, tostring(label) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _stub(target, key, value)
  local saved = target[key]
  target[key] = value
  return function()
    target[key] = saved
  end
end

local function _make_game(opts)
  opts = opts or {}
  local game = {
    occupants = opts.occupants or {},
    statuses = {},
    updated_position = nil,
  }
  function game:update_player_position(player, index)
    self.updated_position = { player = player, index = index }
    player.position = index
  end
  function game:set_player_status(_, key, value)
    self.statuses[key] = value
  end
  function game:clear_roadblock(index)
    self.cleared_roadblock = index
  end
  return game
end

local function _make_board(opts)
  opts = opts or {}
  local tiles = opts.tiles or {}
  local roadblocks = opts.roadblocks or {}
  return {
    map = opts.map,
    has_roadblock = function(_, index) return roadblocks[index] == true end,
    get_tile = function(_, index) return tiles[index] end,
  }
end

local function _base_ctx(opts)
  opts = opts or {}
  local player = opts.player or { id = 1, name = "P1", position = opts.current or 1, status = {} }
  local game = opts.game or _make_game({ occupants = opts.occupants })
  local ctx = {
    game = game,
    player = player,
    steps = opts.steps or 1,
    abs_steps = opts.abs_steps or opts.steps or 1,
    opts = opts.move_opts or {},
    board = opts.board,
    branch_parity = opts.branch_parity or opts.steps or 1,
    encountered = {},
    visited = {},
    pass_start = 0,
    pass_start_at_steps = {},
    stopped_on_roadblock = false,
    market_interrupt = nil,
    current = opts.current or player.position,
    backward = opts.backward == true,
    facing = opts.facing,
    persisted_facing = opts.persisted_facing,
    entered_inner = opts.entered_inner == true,
    exited_inner = false,
    skip_entry_on_tile_id = nil,
  }
  ctx.step_fn = opts.step_fn or function(_, current)
    return current + 1, 0, ctx.facing, false
  end
  return ctx
end

local function _run_with_ctx(ctx)
  local completed_ctx
  local restore_build = _stub(movement_context, "build", function() return ctx end)
  local restore_mine = _stub(mine_effect, "can_trigger", function() return false end)
  local restore_completed = _stub(movement_events, "emit_move_completed", function(done_ctx)
    completed_ctx = done_ctx
  end)
  local market_calls = {}
  local restore_market = _stub(movement_events, "emit_market_interrupt", function(done_ctx, remaining)
    market_calls[#market_calls + 1] = { ctx = done_ctx, remaining = remaining }
  end)
  local roadblock_calls = {}
  local restore_roadblock = _stub(movement_events, "emit_roadblock_hit", function(game, player, current, tile)
    roadblock_calls[#roadblock_calls + 1] = { game = game, player = player, current = current, tile = tile }
  end)
  local result = movement.move(ctx.game, ctx.player, ctx.steps, ctx.opts)
  restore_roadblock()
  restore_market()
  restore_completed()
  restore_mine()
  restore_build()
  return result, {
    completed_ctx = completed_ctx,
    market_calls = market_calls,
    roadblock_calls = roadblock_calls,
  }
end

describe("rules.movement.move orchestration", function()
  it("records mid-step market interrupt state", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 1, type = "road", name = "一" },
        [2] = { id = 2, type = "market", name = "黑市" },
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 3,
      abs_steps = 3,
      entered_inner = true,
      step_fn = function(_, current) return current + 1, 0, "east", false end,
    })
    local result, calls = _run_with_ctx(ctx)
    _assert_eq(#calls.market_calls, 1, "market interrupt emitted once")
    _assert_eq(calls.market_calls[1].remaining, 2, "remaining steps are computed from current step")
    _assert_eq(result.market_interrupt.position, 2, "market interrupt records tile position")
    _assert_eq(result.market_interrupt.remaining_steps, 2, "market interrupt returns remaining steps")
    _assert_eq(result.market_interrupt.facing, "east", "market interrupt preserves facing")
    _assert_eq(result.market_interrupt.entered_inner, true, "market interrupt preserves entered_inner")
  end)

  it("skip_market_check suppresses a market interrupt", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 1, type = "road", name = "一" },
        [2] = { id = 2, type = "market", name = "黑市" },
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 3,
      abs_steps = 1,
      move_opts = { skip_market_check = true },
      step_fn = function(_, current) return current + 1, 0, nil, false end,
    })
    local result, calls = _run_with_ctx(ctx)
    _assert_eq(#calls.market_calls, 0, "market interrupt should be skipped")
    _assert_eq(result.market_interrupt, nil, "result has no market interrupt")
  end)

  it("non-positive logical steps suppress market checks even when a stubbed step advances", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 1, type = "road", name = "一" },
        [2] = { id = 2, type = "market", name = "黑市" },
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 0,
      abs_steps = 1,
      step_fn = function(_, current) return current + 1, 0, nil, false end,
    })
    local result, calls = _run_with_ctx(ctx)
    _assert_eq(#calls.market_calls, 0, "non-positive steps should suppress market interrupt")
    _assert_eq(result.market_interrupt, nil, "non-positive steps have no market interrupt")
  end)

  it("does not interrupt on the final market tile or count landing occupants as encountered", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 1, type = "road", name = "一" },
        [2] = { id = 2, type = "market", name = "黑市" },
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 1,
      abs_steps = 1,
      occupants = { [2] = { 1, 2 } },
      step_fn = function(_, current) return current + 1, 0, nil, false end,
    })
    local result, calls = _run_with_ctx(ctx)
    _assert_eq(#calls.market_calls, 0, "final market tile should not interrupt")
    _assert_eq(result.market_interrupt, nil, "final market tile has no interrupt result")
    _assert_eq(#result.encountered_players, 0, "landing occupants are not pass-through encounters")
  end)

  it("tracks pass-start steps only for positive pass counts", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 1, type = "road", name = "一" },
        [2] = { id = 2, type = "road", name = "二" },
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 1,
      abs_steps = 1,
      move_opts = { skip_market_check = true },
      step_fn = function(_, current) return current + 1, 0, nil, false end,
    })
    local result, calls = _run_with_ctx(ctx)
    _assert_eq(result.passed_start, 0, "zero pass count remains zero")
    _assert_eq(#calls.completed_ctx.pass_start_at_steps, 0, "zero pass count does not record pass step")
  end)

  it("marks inner exit and requests one-shot entry skip only for entry landing tiles", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 10, type = "road", name = "内圈" },
        [2] = { id = 20, type = "road", name = "外圈入口" },
      },
      map = {
        outer_next = { [20] = 21 },
        entry_points = { [20] = true },
        direction = function(from_id, to_id) return tostring(from_id) .. ">" .. tostring(to_id) end,
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 1,
      abs_steps = 1,
      move_opts = { skip_market_check = true },
      step_fn = function(_, current) return current + 1, 0, "north", false end,
    })
    local result = _run_with_ctx(ctx)
    _assert_eq(result.arrival_direction, "10>20", "arrival direction is captured")
    _assert_eq(result.arrival_from_index, 1, "arrival source index captured")
    _assert_eq(ctx.exited_inner, true, "inner exit detected")
    _assert_eq(ctx.game.statuses.skip_next_inner_entry, true, "entry landing sets one-shot skip")
  end)

  it("does not set arrival direction when tile metadata is incomplete", function()
    local board = _make_board({
      tiles = {
        [2] = { id = 20, type = "road", name = "二" },
      },
      map = {
        direction = function() return "should-not-run" end,
        outer_next = {},
        entry_points = {},
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 1,
      abs_steps = 1,
      move_opts = { skip_market_check = true },
      step_fn = function(_, current) return current + 1, 0, nil, false end,
    })
    local result = _run_with_ctx(ctx)
    _assert_eq(result.arrival_direction, nil, "missing previous tile leaves arrival direction nil")
    _assert_eq(result.arrival_from_index, nil, "missing previous tile leaves arrival source nil")
    _assert_eq(ctx.exited_inner, false, "missing previous tile is not an inner exit")
  end)

  it("records pass-through occupants but not the moving player", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 1, type = "road", name = "一" },
        [2] = { id = 2, type = "road", name = "二" },
        [3] = { id = 3, type = "road", name = "三" },
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 2,
      abs_steps = 2,
      occupants = { [2] = { 1, 2 } },
      move_opts = { skip_market_check = true },
      step_fn = function(_, current) return current + 1, 0, nil, false end,
    })
    local result = _run_with_ctx(ctx)
    _assert_eq(#result.encountered_players, 1, "one other player encountered while passing through")
    _assert_eq(result.encountered_players[1], 2, "moving player is excluded from encounters")
  end)

  it("keeps skip_next_inner_entry false when landing is an entry without an inner exit", function()
    local board = _make_board({
      tiles = {
        [1] = { id = 10, type = "road", name = "外圈A" },
        [2] = { id = 20, type = "road", name = "外圈入口" },
      },
      map = {
        outer_next = { [10] = 20, [20] = 21 },
        entry_points = { [20] = true },
        direction = function() return "east" end,
      },
    })
    local ctx = _base_ctx({
      board = board,
      steps = 1,
      abs_steps = 1,
      move_opts = { skip_market_check = true },
      step_fn = function(_, current) return current + 1, 0, nil, false end,
    })
    _run_with_ctx(ctx)
    _assert_eq(ctx.exited_inner, false, "outer-to-outer move is not an inner exit")
    _assert_eq(ctx.game.statuses.skip_next_inner_entry, false, "entry tile without inner exit does not set skip")
  end)
end)
