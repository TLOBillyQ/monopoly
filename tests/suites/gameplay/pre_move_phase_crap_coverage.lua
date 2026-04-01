local phase_pre_move = require("src.turn.phases.pre_move")
local item_phase = require("src.rules.items.phase")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _build_auto_play_port_stub()
  return {
    is_auto_player = function() return false end,
    pick_target_player = function() return nil end,
    pick_remote_dice_value = function() return nil end,
    pick_roadblock_target = function() return nil end,
    auto_action_for_choice = function() return nil end,
  }
end

local function _build_turn_mgr(overrides)
  overrides = overrides or {}
  local player = overrides.player or { id = 1, status = {} }
  return {
    game = {
      current_player = function() return player end,
      last_turn = overrides.last_turn or { raw_total = 3, total = 3, player_id = 1 },
      turn = { item_phase = {} },
      auto_play_port = _build_auto_play_port_stub(),
    },
  }
end

local function _with_item_phase_run(stub_fn, fn)
  local orig = item_phase.run
  item_phase.run = stub_fn
  local ok, err = pcall(fn)
  item_phase.run = orig
  if not ok then error(err, 2) end
end

local function _test_resolve_wait_choice_when_no_wait_action_anim()
  local player = { id = 1, status = {} }
  local turn_mgr = _build_turn_mgr({ player = player })
  local captured_state, captured_args

  _with_item_phase_run(function(_, _, _)
    return { waiting = true, next_state = "pre_move", next_args = nil }
  end, function()
    captured_state, captured_args = phase_pre_move(turn_mgr, { player = player, total = 5, raw_total = 5 })
  end)

  _assert_eq(captured_state, "wait_choice", "should return wait_choice when no wait_action_anim")
  _assert_eq(captured_args.next_state, "pre_move", "next_state should be pre_move")
end

local function _test_resolve_wait_action_anim_when_flag_set()
  local player = { id = 1, status = {} }
  local turn_mgr = _build_turn_mgr({ player = player })
  local captured_state

  _with_item_phase_run(function(_, _, _)
    return { waiting = true, wait_action_anim = true, next_state = "pre_move", next_args = nil }
  end, function()
    captured_state, _ = phase_pre_move(turn_mgr, { player = player, total = 5, raw_total = 5 })
  end)

  _assert_eq(captured_state, "wait_action_anim", "should return wait_action_anim when flag is set")
end

local function _test_default_next_args_built_from_player_total_raw_total()
  local player = { id = 1, status = {} }
  local turn_mgr = _build_turn_mgr({ player = player })
  local captured_args

  _with_item_phase_run(function(_, _, _)
    return { waiting = true, next_state = "pre_move", next_args = nil }
  end, function()
    _, captured_args = phase_pre_move(turn_mgr, { player = player, total = 7, raw_total = 3 })
  end)

  _assert_eq(captured_args.next_args.total, 7, "default next_args should include total")
  _assert_eq(captured_args.next_args.raw_total, 3, "default next_args should include raw_total")
  _assert_eq(captured_args.next_args.player, player, "default next_args should include player")
end

local function _test_provided_next_args_used_as_is()
  local player = { id = 1, status = {} }
  local custom_args = { player = player, total = 99, raw_total = 1, custom = true }
  local turn_mgr = _build_turn_mgr({ player = player })
  local captured_args

  _with_item_phase_run(function(_, _, _)
    return { waiting = true, next_state = "move", next_args = custom_args }
  end, function()
    _, captured_args = phase_pre_move(turn_mgr, { player = player, total = 99, raw_total = 1 })
  end)

  _assert_eq(captured_args.next_state, "move", "should use provided next_state")
  _assert_eq(captured_args.next_args, custom_args, "should use provided next_args unchanged")
end

local function _test_no_item_phase_continues_to_move()
  local player = { id = 1, status = {} }
  local turn_mgr = _build_turn_mgr({ player = player })

  _with_item_phase_run(function(_, _, _)
    return nil
  end, function()
    local state, args = phase_pre_move(turn_mgr, { player = player, total = 4, raw_total = 4 })
    _assert_eq(state, "move", "when item_phase returns nil, should continue to move state")
    _assert_eq(args.player, player, "move args should include player")
  end)
end

return {
  name = "pre_move_phase_crap_coverage",
  tests = {
    { name = "_test_resolve_wait_choice_when_no_wait_action_anim", run = _test_resolve_wait_choice_when_no_wait_action_anim },
    { name = "_test_resolve_wait_action_anim_when_flag_set", run = _test_resolve_wait_action_anim_when_flag_set },
    { name = "_test_default_next_args_built_from_player_total_raw_total", run = _test_default_next_args_built_from_player_total_raw_total },
    { name = "_test_provided_next_args_used_as_is", run = _test_provided_next_args_used_as_is },
    { name = "_test_no_item_phase_continues_to_move", run = _test_no_item_phase_continues_to_move },
  },
}
