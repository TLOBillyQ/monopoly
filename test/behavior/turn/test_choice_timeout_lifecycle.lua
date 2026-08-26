-- #602 构造面收窄:resolve_output_ports / deadline_service / resolve_choice /
-- force_skip 四个不变量收进模块内部,本适配改用仓库的模块字段补丁通路——
-- DeadlineService 字段经 with_patches 替换为观测桩,输出端口经
-- state.gameplay_loop_ports.output 注入(resolve_port 的解析路径)。
local lu = require("luaunit")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")
local DeadlineService = require("src.turn.deadlines")
local support = require("test.support.shared_support")

local _with_patches = support.with_patches

local function _output_state()
  local values = {
    pending_choice = nil,
    pending_choice_id = "old-choice",
    pending_choice_elapsed = 9.0,
  }
  values.ports = {
    get_pending_choice = function() return values.pending_choice end,
    sync_pending_choice = function(_, choice)
      values.pending_choice = choice
      values.pending_choice_id = choice and choice.id or nil
      values.pending_choice_elapsed = 0
    end,
    clear_pending_choice = function()
      values.pending_choice = nil
      values.pending_choice_id = nil
      values.pending_choice_elapsed = 0
    end,
    get_pending_choice_id = function() return values.pending_choice_id end,
    set_pending_choice_id = function(_, value) values.pending_choice_id = value end,
    get_pending_choice_elapsed = function() return values.pending_choice_elapsed end,
    set_pending_choice_elapsed = function(_, value) values.pending_choice_elapsed = value end,
  }
  return values
end

-- 输出端口经 gameplay_loop_ports 注入,与生产 resolve_port 路径一致。
local function _state_with_output(output)
  return { gameplay_loop_ports = { output = output.ports } }
end

local _PATCH_KEYS = { resolve_choice = true, force_skip = true }

local function _new_lifecycle(overrides)
  local canceled = {}
  local started = {}
  local active = {}
  local dependencies = {
    on_pending_choice = function() end,
    is_choice_active = function() return true end,
    resolve_choice_ui_state = function(_, _, choice)
      return { route_key = choice and choice.route_key or nil, should_warn = false }
    end,
    build_action = function() return nil end,
    dispatch_action_with_close_choice = function() end,
    get_timeout_seconds = function() return 0 end,
    get_min_visible_seconds = function() return 0 end,
  }
  local patch_overrides = {}
  for key, value in pairs(overrides or {}) do
    if _PATCH_KEYS[key] then
      patch_overrides[key] = value
    else
      dependencies[key] = value
    end
  end
  local real = ChoiceTimeout.new(dependencies)
  local function _deadline_patches()
    return {
      { target = DeadlineService, key = "cancel", value = function(_, scope)
          canceled[#canceled + 1] = scope
          active[scope] = nil
        end },
      { target = DeadlineService, key = "is_active", value = function(_, scope)
          return active[scope] ~= nil
        end },
      { target = DeadlineService, key = "start", value = function(_, scope, opts)
          active[scope] = opts
          started[#started + 1] = { scope = scope, timeout_seconds = opts.timeout_seconds }
        end },
      { target = DeadlineService, key = "resolve_choice",
        value = patch_overrides.resolve_choice or function() end },
      { target = DeadlineService, key = "force_skip",
        value = patch_overrides.force_skip or function() end },
    }
  end
  local lifecycle = {
    step = function(game, state, dt)
      return _with_patches(_deadline_patches(), function()
        return real.step(game, state, dt)
      end)
    end,
  }
  return lifecycle, {
    canceled = canceled,
    started = started,
    active = active,
  }
end

TestChoiceTimeoutLifecycle = {}

function TestChoiceTimeoutLifecycle:test_disabled_timeout_clears_runtime_tracking_and_both_deadline_scopes()
  local output = _output_state()
  local lifecycle, deadlines = _new_lifecycle()

  lifecycle.step({ turn = {} }, _state_with_output(output), 0.1)

  lu.assertEquals(output.pending_choice_elapsed, 0)
  lu.assertNil(output.pending_choice_id)
  lu.assertEquals(deadlines.canceled, { "choice", "market_buy" })
end

function TestChoiceTimeoutLifecycle:test_changed_choice_restarts_elapsed_and_arms_one_fresh_market_deadline()
  local output = _output_state()
  output.pending_choice = { id = "old-choice", kind = "normal" }
  local choice = { id = "new-choice", kind = "market_buy" }
  local lifecycle, deadlines = _new_lifecycle({
    get_timeout_seconds = function() return 60.0 end,
    get_min_visible_seconds = function() return 100.0 end,
  })
  local game = { turn = { pending_choice = choice } }
  local state = _state_with_output(output)

  lifecycle.step(game, state, 0.25)
  lifecycle.step(game, state, 0.25)

  lu.assertEquals(output.pending_choice_id, "new-choice")
  lu.assertEquals(output.pending_choice_elapsed, 0.5)
  lu.assertEquals(deadlines.canceled, { "choice", "market_buy" })
  lu.assertEquals(deadlines.started, {
    { scope = "market_buy", timeout_seconds = 60.0 },
  })
end

function TestChoiceTimeoutLifecycle:test_dangling_owner_force_skips_before_building_or_starting_a_deadline()
  local output = _output_state()
  local choice = { id = "orphan", kind = "normal", owner_role_id = 99 }
  output.pending_choice = choice
  output.pending_choice_id = choice.id
  output.pending_choice_elapsed = 0
  local built = 0
  local skipped = {}
  local lifecycle, deadlines = _new_lifecycle({
    get_timeout_seconds = function() return 15.0 end,
    build_action = function() built = built + 1 end,
    force_skip = function(_, _, skipped_choice, reason)
      skipped[#skipped + 1] = { choice = skipped_choice, reason = reason }
    end,
  })
  local game = support.new_game({ players = { "P1" } })
  game.turn.pending_choice = choice

  lifecycle.step(game, _state_with_output(output), 0.1)

  lu.assertEquals(built, 0)
  lu.assertEquals(#deadlines.started, 0)
  lu.assertEquals(skipped[1].choice, choice)
  lu.assertEquals(skipped[1].reason, "owner_dangling")
end

function TestChoiceTimeoutLifecycle:test_min_visible_action_dispatches_before_the_timeout_window()
  local output = _output_state()
  local game = support.new_game({ players = { "P1" } })
  local choice = { id = "choice-1", kind = "normal", owner_role_id = game.players[1].id }
  game.turn.pending_choice = choice
  output.pending_choice = choice
  output.pending_choice_id = choice.id
  output.pending_choice_elapsed = 0
  local payload
  local dispatched
  local lifecycle = _new_lifecycle({
    get_timeout_seconds = function() return 15.0 end,
    get_min_visible_seconds = function() return 0.5 end,
    build_action = function(_, _, _, action_payload)
      payload = action_payload
      return { type = "choice_select", choice_id = choice.id }
    end,
    dispatch_action_with_close_choice = function(_, _, action) dispatched = action end,
  })

  lifecycle.step(game, _state_with_output(output), 0.5)

  lu.assertEquals(payload.mode, "tick_min_visible")
  lu.assertEquals(dispatched.actor_role_id, game.players[1].id)
  lu.assertNil(dispatched.input_source)
  lu.assertEquals(output.pending_choice_elapsed, 0)
end

function TestChoiceTimeoutLifecycle:test_timeout_action_is_stamped_and_dispatched_through_the_close_choice_path()
  local output = _output_state()
  local game = support.new_game({ players = { "P1" } })
  local choice = { id = "choice-2", kind = "normal", owner_role_id = game.players[1].id }
  game.turn.pending_choice = choice
  output.pending_choice = choice
  output.pending_choice_id = choice.id
  output.pending_choice_elapsed = 0
  local payload
  local dispatched
  local lifecycle = _new_lifecycle({
    get_timeout_seconds = function() return 1.0 end,
    get_min_visible_seconds = function() return 2.0 end,
    build_action = function(_, _, _, action_payload)
      payload = action_payload
      return { type = "choice_cancel", choice_id = choice.id }
    end,
    dispatch_action_with_close_choice = function(_, _, action) dispatched = action end,
  })

  lifecycle.step(game, _state_with_output(output), 1.0)

  lu.assertEquals(payload.mode, "tick_timeout")
  lu.assertEquals(payload.timeout_seconds, 1.0)
  lu.assertEquals(payload.min_visible_seconds, 2.0)
  lu.assertEquals(dispatched.actor_role_id, game.players[1].id)
  lu.assertEquals(dispatched.input_source, "timeout")
  lu.assertEquals(output.pending_choice_elapsed, 0)
end

function TestChoiceTimeoutLifecycle:test_missing_timeout_action_uses_the_injected_fallback_resolution()
  local output = _output_state()
  local game = support.new_game({ players = { "P1" } })
  local choice = { id = "choice-3", kind = "normal", owner_role_id = game.players[1].id }
  game.turn.pending_choice = choice
  output.pending_choice = choice
  output.pending_choice_id = choice.id
  local resolved
  local lifecycle = _new_lifecycle({
    get_timeout_seconds = function() return 1.0 end,
    get_min_visible_seconds = function() return 2.0 end,
    resolve_choice = function(_, _, resolved_choice, reason, action)
      resolved = { choice = resolved_choice, reason = reason, action = action }
    end,
  })

  lifecycle.step(game, _state_with_output(output), 1.0)

  lu.assertEquals(resolved.choice, choice)
  lu.assertEquals(resolved.reason, "tick_timeout")
  lu.assertNil(resolved.action)
end

return TestChoiceTimeoutLifecycle
