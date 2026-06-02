local context = require("src.rules.movement_context")

local function _assert_eq(actual, expected, label)
  assert(actual == expected, tostring(label) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _make_board(opts)
  opts = opts or {}
  local tiles = opts.tiles or {
    [1] = { id = 1, type = "road" },
    [2] = { id = 2, type = "road" },
  }
  return {
    map = opts.map,
    step_forward_by_facing = function() return "forward" end,
    step_backward_by_facing = function() return "backward" end,
    get_tile = function(_, index) return tiles[index] end,
  }
end

local function _build(opts)
  opts = opts or {}
  local player = opts.player or {
    id = 1,
    position = opts.position or 1,
    status = opts.status or {},
  }
  local game = {
    board = opts.board or _make_board(opts.board_opts),
  }
  return context.build(game, player, opts.steps or 1, opts.move_opts or {})
end

describe("rules.movement_context.build", function()
  it("builds fresh forward context with positive fractional steps", function()
    local ctx = _build({ steps = 0.5 })
    _assert_eq(ctx.backward, false, "positive fractional move should be forward")
    _assert_eq(ctx.abs_steps, 0.5, "positive fractional abs_steps preserved")
    _assert_eq(ctx.branch_parity, 0.5, "branch_parity defaults to abs_steps")
    _assert_eq(ctx.step_fn(), "forward", "forward step function selected")
    _assert_eq(ctx.facing, nil, "fresh forward starts without facing")
    _assert_eq(ctx.entered_inner, false, "fresh forward starts outside inner ring")
    _assert_eq(ctx.stopped_on_roadblock, false, "roadblock state starts false")
    _assert_eq(ctx.market_interrupt, nil, "market interrupt starts nil")
    _assert_eq(ctx.consume_skip_inner_entry, false, "skip consumption starts false")
    _assert_eq(ctx.exited_inner, false, "inner exit starts false")
  end)

  it("builds relative backward context from negative steps", function()
    local ctx = _build({
      steps = -2,
      status = { move_dir = "left" },
    })
    _assert_eq(ctx.backward, true, "negative move should be backward")
    _assert_eq(ctx.abs_steps, 2, "negative move abs_steps should be positive")
    _assert_eq(ctx.step_fn(), "backward", "backward step function selected")
    _assert_eq(ctx.facing, "left", "relative backward uses recorded move_dir")
  end)

  it("keeps zero-step moves in fresh forward mode", function()
    local ctx = _build({
      steps = 0,
      status = { move_dir = "left" },
    })
    _assert_eq(ctx.backward, false, "zero-step move should not be backward")
    _assert_eq(ctx.abs_steps, 0, "zero-step abs_steps should stay zero")
    _assert_eq(ctx.step_fn(), "forward", "zero-step move should select forward step function")
    _assert_eq(ctx.facing, nil, "zero-step fresh move should not reuse move_dir")
  end)

  it("resumes forward from explicit direction and branch parity", function()
    local ctx = _build({
      steps = 3,
      move_opts = {
        direction = "up",
        branch_parity = 7,
        entered_inner = true,
      },
    })
    _assert_eq(ctx.backward, false, "resume forward should not be backward")
    _assert_eq(ctx.branch_parity, 7, "explicit branch parity preserved")
    _assert_eq(ctx.entered_inner, true, "explicit entered_inner preserved")
    _assert_eq(ctx.facing, "up", "resume forward uses explicit direction")
  end)

  it("marks inner start tiles as already entered and restores persisted facing", function()
    local ctx = _build({
      steps = 2,
      position = 2,
      status = { move_dir = "down" },
      board_opts = {
        map = {
          outer_next = { [1] = 2 },
          entry_points = {},
        },
      },
    })
    _assert_eq(ctx.entered_inner, true, "inner start marks entered_inner")
    _assert_eq(ctx.facing, "down", "inner fresh start restores persisted facing")
  end)

  it("does not restore persisted facing when an entered context starts on the outer ring", function()
    local ctx = _build({
      steps = 2,
      status = { move_dir = "right" },
      move_opts = { entered_inner = true },
      board_opts = {
        map = {
          outer_next = { [1] = 2 },
          entry_points = {},
        },
      },
    })
    _assert_eq(ctx.entered_inner, true, "entered_inner remains explicit")
    _assert_eq(ctx.facing, nil, "outer fresh start keeps fresh facing")
  end)

  it("captures one-shot inner-entry skip state at the current entry tile", function()
    local ctx = _build({
      steps = 2,
      status = { skip_next_inner_entry = true },
      board_opts = {
        map = {
          outer_next = { [1] = 2 },
          entry_points = { [1] = true },
        },
      },
    })
    _assert_eq(ctx.skip_entry_on_tile_id, 1, "skip applies to current entry tile")
    _assert_eq(ctx.consume_skip_inner_entry, true, "skip should be consumed by movement")
  end)

  it("treats missing map metadata as a non-outer start without crashing", function()
    local ctx = _build({
      steps = 2,
      status = { move_dir = "left" },
      board_opts = { map = nil },
    })
    _assert_eq(ctx.entered_inner, false, "missing map leaves entered_inner unchanged")
    _assert_eq(ctx.facing, nil, "missing map leaves fresh facing unchanged")
  end)

  it("missing map with explicit entered_inner restores persisted facing", function()
    local ctx = _build({
      steps = 2,
      status = { move_dir = "left" },
      move_opts = { entered_inner = true },
      board_opts = { map = nil },
    })
    _assert_eq(ctx.entered_inner, true, "explicit entered_inner remains set")
    _assert_eq(ctx.facing, "left", "missing map is treated as non-outer for persisted facing")
  end)
end)
