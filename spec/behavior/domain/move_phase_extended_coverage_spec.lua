local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game(opts)
  opts = opts or {}
  return {
    turn = { move_anim_seq = opts.prior_seq },
    dirty = { turn = false, any = false },
    anim_gate_port = { wait_move_anim = opts.wait_move_anim == true },
    set_player_status = nil,
    last_turn = nil,
  }
end

local function _make_player(opts)
  opts = opts or {}
  return {
    id = opts.id or 1,
    position = opts.position or 5,
    status = { pending_dice_multiplier = opts.multiplier or 1 },
  }
end

local function _stub(modname, replacement)
  local module = require(modname)
  local saved = {}
  for k, v in pairs(replacement) do
    saved[k] = module[k]
    module[k] = v
  end
  return function()
    for k, v in pairs(saved) do
      module[k] = v
    end
  end
end

describe("domain move phase extended coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("returns wait_move_anim when anim_gate_port enabled", function()
    local game = _make_game({ wait_move_anim = true })
    local player = _make_player({ id = 1, position = 3 })
    local turn_mgr = { game = game }
    local move_result = {
      visited = { 3, 4, 5, 6, 7 },
      steps = 4,
      stopped_on_roadblock = false,
      market_interrupt = false,
      steal_interrupt = false,
    }
    local restore_movement = _stub("src.rules.movement", {
      move = function(_, _, _, _) player.position = 7; return move_result end,
    })
    local _phase_move = require("src.turn.phases.move")
    local state_name, args = _phase_move(turn_mgr, { player = player, raw_total = 4, total = 4 })
    restore_movement()
    _assert_eq(state_name, "wait_move_anim", "should return wait_move_anim state")
    assert(type(args) == "table", "should return args table")
    _assert_eq(args.next_state, "move_followup", "next_state should be move_followup")
    assert(args.next_args ~= nil, "next_args should be present")
    _assert_eq(args.next_args.mode, "resume_turn_move", "mode should be resume_turn_move")
    _assert_eq(args.next_args.move_result, move_result, "move_result should be forwarded")
    _assert_eq(game.turn.move_anim.player_id, 1, "move_anim should record player_id")
    _assert_eq(game.turn.move_anim.from_index, 3, "from_index should be start position")
    _assert_eq(game.turn.move_anim.to_index, 7, "to_index should be player's new position")
    _assert_eq(game.turn.move_anim.steps, 4, "steps should be forwarded")
    _assert_eq(game.dirty.turn, true, "dirty.turn should be set")
    _assert_eq(game.dirty.any, true, "dirty.any should be set")
  end)

  it("flags propagate from move_result to move_anim", function()
    local game = _make_game({ wait_move_anim = true })
    local player = _make_player()
    local turn_mgr = { game = game }
    local move_result = {
      visited = { 5, 6 },
      steps = 1,
      stopped_on_roadblock = true,
      market_interrupt = true,
      steal_interrupt = true,
    }
    local restore_movement = _stub("src.rules.movement", {
      move = function() return move_result end,
    })
    local _phase_move = require("src.turn.phases.move")
    _phase_move(turn_mgr, { player = player, raw_total = 1, total = 1 })
    restore_movement()
    _assert_eq(game.turn.move_anim.stopped_on_roadblock, true, "roadblock flag forwarded")
    _assert_eq(game.turn.move_anim.market_interrupt, true, "market_interrupt forwarded")
    _assert_eq(game.turn.move_anim.steal_interrupt, true, "steal_interrupt forwarded")
  end)

  it("delegates to move_followup when anim_gate_port disabled", function()
    local game = _make_game({ wait_move_anim = false })
    local player = _make_player()
    local turn_mgr = { game = game }
    local followup_calls = {}
    local restore_movement = _stub("src.rules.movement", {
      move = function() return { visited = {}, steps = 0 } end,
    })
    local restore_followup = _stub("src.turn.phases.move_followup", {
      run = function(mgr, args)
        followup_calls[#followup_calls + 1] = { mgr = mgr, args = args }
        return "followup_done"
      end,
    })
    local _phase_move = require("src.turn.phases.move")
    local result = _phase_move(turn_mgr, { player = player, raw_total = 3, total = 3 })
    restore_movement()
    restore_followup()
    _assert_eq(result, "followup_done", "should return followup result")
    _assert_eq(#followup_calls, 1, "move_followup.run should be called once")
    _assert_eq(followup_calls[1].args.mode, "resume_turn_move", "mode should be set")
    _assert_eq(followup_calls[1].args.player, player, "player forwarded")
  end)

  it("continue_from_market preserves direction/branch_parity/entered_inner and uses remaining_steps", function()
    local game = _make_game({ wait_move_anim = false })
    local player = _make_player()
    local turn_mgr = { game = game }
    local captured_total, captured_opts = nil, nil
    local restore_movement = _stub("src.rules.movement", {
      move = function(_, _, total, opts)
        captured_total = total
        captured_opts = opts
        return { visited = {}, steps = 0 }
      end,
    })
    local restore_followup = _stub("src.turn.phases.move_followup", { run = function() return "done" end })
    local _phase_move = require("src.turn.phases.move")
    _phase_move(turn_mgr, {
      player = player,
      raw_total = 6,
      total = 6,
      continue_from_market = true,
      facing = "forward",
      branch_parity = 5,
      entered_inner = true,
      remaining_steps = 2,
    })
    restore_movement()
    restore_followup()
    _assert_eq(captured_total, 2, "remaining_steps should override total")
    _assert_eq(captured_opts.direction, "forward", "facing should map to direction")
    _assert_eq(captured_opts.branch_parity, 5, "branch_parity preserved")
    _assert_eq(captured_opts.entered_inner, true, "entered_inner preserved")
  end)

  it("continue_from_steal also routes through resume path", function()
    local game = _make_game({ wait_move_anim = false })
    local player = _make_player()
    local turn_mgr = { game = game }
    local captured_total = nil
    local restore_movement = _stub("src.rules.movement", {
      move = function(_, _, total, _)
        captured_total = total
        return { visited = {}, steps = 0 }
      end,
    })
    local restore_followup = _stub("src.turn.phases.move_followup", { run = function() return "done" end })
    local _phase_move = require("src.turn.phases.move")
    _phase_move(turn_mgr, {
      player = player,
      raw_total = 6,
      total = 6,
      continue_from_steal = true,
      facing = "back",
      branch_parity = 1,
      remaining_steps = 4,
    })
    restore_movement()
    restore_followup()
    _assert_eq(captured_total, 4, "remaining_steps should override total in steal resume")
  end)

  it("default branch uses raw_total and no opt direction", function()
    local game = _make_game({ wait_move_anim = false })
    local player = _make_player()
    local turn_mgr = { game = game }
    local captured_opts, captured_total = nil, nil
    local restore_movement = _stub("src.rules.movement", {
      move = function(_, _, total, opts)
        captured_total = total
        captured_opts = opts
        return { visited = {}, steps = 0 }
      end,
    })
    local restore_followup = _stub("src.turn.phases.move_followup", { run = function() return "done" end })
    local _phase_move = require("src.turn.phases.move")
    _phase_move(turn_mgr, { player = player, raw_total = 8, total = 8 })
    restore_movement()
    restore_followup()
    _assert_eq(captured_total, 8, "default branch uses total directly")
    _assert_eq(captured_opts.direction, nil, "default branch has no direction")
    _assert_eq(captured_opts.branch_parity, 8, "branch_parity defaults to raw_total")
    _assert_eq(captured_opts.entered_inner, nil, "entered_inner not set in default branch")
  end)

  it("with provided move_result skips _perform_move and runs move_followup directly", function()
    local game = _make_game({ wait_move_anim = true })
    local player = _make_player()
    local turn_mgr = { game = game }
    local move_calls = 0
    local followup_calls = 0
    local restore_movement = _stub("src.rules.movement", {
      move = function() move_calls = move_calls + 1; return { visited = {}, steps = 0 } end,
    })
    local restore_followup = _stub("src.turn.phases.move_followup", {
      run = function() followup_calls = followup_calls + 1; return "ok" end,
    })
    local _phase_move = require("src.turn.phases.move")
    local existing_result = { visited = { 1, 2 }, steps = 1 }
    _phase_move(turn_mgr, {
      player = player,
      raw_total = 2,
      total = 2,
      move_result = existing_result,
    })
    restore_movement()
    restore_followup()
    _assert_eq(move_calls, 0, "movement.move should NOT be called when move_result provided")
    _assert_eq(followup_calls, 1, "move_followup.run should be called once")
  end)

  it("move_anim_seq increments on successive perform calls", function()
    local game = _make_game({ wait_move_anim = true, prior_seq = 5 })
    local player = _make_player()
    local turn_mgr = { game = game }
    local restore_movement = _stub("src.rules.movement", {
      move = function() return { visited = {}, steps = 0 } end,
    })
    local _phase_move = require("src.turn.phases.move")
    _phase_move(turn_mgr, { player = player, raw_total = 1, total = 1 })
    _assert_eq(game.turn.move_anim.seq, 6, "seq should bump from 5 to 6")
    _phase_move(turn_mgr, { player = player, raw_total = 1, total = 1 })
    restore_movement()
    _assert_eq(game.turn.move_anim.seq, 7, "seq should bump again to 7")
  end)

  it("missing anim_gate_port asserts", function()
    local game = _make_game({ wait_move_anim = false })
    game.anim_gate_port = nil
    local player = _make_player()
    local turn_mgr = { game = game }
    local restore_movement = _stub("src.rules.movement", {
      move = function() return { visited = {}, steps = 0 } end,
    })
    local _phase_move = require("src.turn.phases.move")
    local ok, err = pcall(_phase_move, turn_mgr, { player = player, raw_total = 1, total = 1 })
    restore_movement()
    _assert_eq(ok, false, "missing anim_gate_port should error")
    assert(tostring(err):find("anim_gate_port") ~= nil, "error should mention anim_gate_port")
  end)
end)
