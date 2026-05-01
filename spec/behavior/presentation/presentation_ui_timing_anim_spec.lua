-- luacheck: ignore 211
local support = require("support.presentation_support")
local _new_game = support.new_game
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local turn_anim = support.turn_anim
local tick_timeout = support.tick_timeout
local constants = support.constants
local choice_resolver = support.choice_resolver
local turn_move = support.turn_move
local dispatch = require("src.turn.actions.action_dispatcher")
local runtime_port = require("src.ui.render.runtime_ui")
local move_anim = require("src.ui.render.move_anim")
local runtime_cls = require("src.turn.loop.scheduler_runtime")
local vec3 = require("fixtures.vec3")

describe("presentation_ui.timing_anim", function()
  it("_test_move_anim_callback_and_delay", function()
    local dispatched = {}
    local layer = { wait_move_anim = true }
    local game = {
      turn = {
        move_anim = { seq = 1 },
        phase = "wait_move_anim",
      },
      dispatch_action = function(_, action)
        table.insert(dispatched, action)
      end,
    }
    local delay_called = nil
    local function call_delay(delay, cb)
      delay_called = delay
      cb()
    end
    _with_patches({
      { key = "LuaAPI", value = { call_delay_time = call_delay } },
      { key = "SetTimeOut", value = call_delay },
    }, function()
      turn_anim.step_move_anim(game, layer, {
        on_move_anim = function(_, anim)
          _assert_eq(anim.seq, 1, "anim seq forwarded")
          return 0.2
        end,
      })
    end)
    _assert_eq(delay_called, 0.2, "delay requested")
    _assert_eq(#dispatched, 1, "move_anim_done dispatched")
    _assert_eq(dispatched[1].seq, 1, "move_anim_done seq")
  end)

  it("_test_popup_timeout_auto_confirm", function()
    local layer = {}
    layer.ui_modal_elapsed = 0
    layer.ui_modal_ref = nil
    local timeout = constants.action_timeout_seconds or 0
    if timeout <= 0 then
      return
    end
    local near_timeout = timeout * 0.9
    local popup = {
      active = true,
      confirm_called = 0,
      confirm = function(self)
        self.confirm_called = self.confirm_called + 1
        self.active = false
        return true
      end,
    }
    layer.modal = { active = popup }
    local timeout_opts = {
      is_active = function(l)
        return l.modal and l.modal.active and l.modal.active.active
      end,
      get_ref = function(l)
        return l.modal and l.modal.active
      end,
      on_timeout = function(l)
        l.modal.active:confirm()
      end,
    }
    tick_timeout.step_modal_timeout(layer, near_timeout, timeout_opts)
    _assert_eq(popup.confirm_called, 0, "popup should not auto confirm before timeout")
    tick_timeout.step_modal_timeout(layer, near_timeout + 1, timeout_opts)
    _assert_eq(popup.confirm_called, 1, "popup should auto confirm after timeout")
  end)

  it("_test_runtime_port_with_client_role_restores_nested_context", function()
    local role1 = { name = "r1" }
    local role2 = { name = "r2" }
    local original = { name = "origin" }
    local manager = { client_role = original }

    _with_patches({
      { key = "UIManager", value = manager },
    }, function()
      runtime_port.with_client_role(role1, function()
        assert(UIManager.client_role == role1, "outer with_client_role should set role1")
        runtime_port.with_client_role(role2, function()
          assert(UIManager.client_role == role2, "nested with_client_role should set role2")
        end)
        assert(UIManager.client_role == role1, "nested with_client_role should restore outer role")
      end)
      assert(UIManager.client_role == original, "with_client_role should restore original role")

      local ok = pcall(function()
        runtime_port.with_client_role(role1, function()
          error("boom")
        end)
      end)
      assert(ok == false, "with_client_role should rethrow callback error")
      assert(UIManager.client_role == original, "with_client_role should restore role after error")
    end)
  end)

  it("_test_runtime_port_native_size_prefers_native_method", function()
    local native_calls = 0
    local keep_calls = 0
    local node = {
      set_texture_native_size = function(_, image_key)
        native_calls = native_calls + 1
        _assert_eq(image_key, "IMG_NATIVE", "native path should forward image key")
      end,
      set_texture_keep_size = function()
        keep_calls = keep_calls + 1
      end,
    }

    runtime_port.set_node_texture_native_size(node, "IMG_NATIVE")

    _assert_eq(native_calls, 1, "native path should prefer set_texture_native_size")
    _assert_eq(keep_calls, 0, "native path should not fallback to keep-size when native exists")
  end)

  it("_test_runtime_port_native_size_fallback_keep_size", function()
    local keep_calls = 0
    local node = {
      set_texture_keep_size = function(_, image_key)
        keep_calls = keep_calls + 1
        _assert_eq(image_key, "IMG_KEEP", "keep-size fallback should forward image key")
      end,
    }

    runtime_port.set_node_texture_native_size(node, "IMG_KEEP")

    _assert_eq(keep_calls, 1, "native path should fallback to keep-size when native is missing")
  end)

  it("_test_runtime_port_native_size_fallback_image_texture", function()
    local node = {}

    runtime_port.set_node_texture_native_size(node, "IMG_TEXTURE")

    _assert_eq(node.image_texture, "IMG_TEXTURE", "native path should fallback to image_texture field")
  end)

  it("_test_choice_timeout_supports_explicit_timeout_strategy", function()
    local game = {
      players = { [1] = { id = 1 } },
      turn = {
        pending_choice = {
          id = 7,
          kind = "test",
          options = { { id = 11, label = "a" } },
        },
        current_player_index = 1,
      },
      current_player = function(self)
        return self.players[self.turn.current_player_index]
      end,
    }
    local state = {
      pending_choice = nil,
      pending_choice_elapsed = 0,
      pending_choice_id = nil,
    }
    local dispatched = nil
    _with_patches({
      { target = dispatch, key = "dispatch_action", value = function(_, _, action)
        dispatched = action
      end },
      { target = require("src.ui.coord.modal"), key = "close_choice_modal", value = function() end },
    }, function()
      tick_timeout.step_choice_timeout(game, state, 0.11, {
        on_pending_choice = function() end,
        is_choice_active = function()
          return true
        end,
        get_timeout_seconds = function()
          return 0.1
        end,
        build_action = function(_, _, choice)
          return {
            type = "choice_select",
            choice_id = choice.id,
            option_id = 11,
          }
        end,
      })
    end)
    assert(dispatched and dispatched.type == "choice_select", "explicit timeout strategy should dispatch action")
    assert(dispatched and dispatched.choice_id == 7, "explicit timeout strategy should use pending choice id")
  end)

  it("_test_tick_timeout_default_policy_isolation", function()
    local policy = tick_timeout.default_policy()
    policy.choice.get_timeout_seconds = function()
      return 999
    end
    local fresh_policy = tick_timeout.default_policy()
    local timeout = fresh_policy.choice.get_timeout_seconds()
    assert(timeout ~= 999, "default policy should not be mutated by external override")
  end)

  it("_test_invalid_choice_option_rejected", function()
    local g = _new_game()
    local choice = _open_choice(g, {
      kind = "market_buy",
      route_key = "market",
      owner_role_id = g:current_player().id,
      options = { { id = 1, label = "X" } },
      meta = { player_id = g:current_player().id },
    })
    choice_resolver.resolve(g, choice, { option_id = 999 })
    assert(_get_choice(g) ~= nil, "invalid option should keep choice")
  end)

  it("_test_move_anim_wait_and_resume", function()
    local g = _new_game()
    g.anim_gate_port = {
      wait_move_anim = true,
      wait_action_anim = false,
    }
    local player = g:current_player()
    g.last_turn = {
      player_id = player.id,
      player_name = player.name,
      skipped = false,
      rolls = nil,
      total = nil,
      move_result = nil,
      note = nil,
    }
    local phases = {
      start = function()
        return "move", { player = player, total = 1, raw_total = 1 }
      end,
      move = turn_move,
      landing = function()
        return nil
      end,
    }
    g.turn_engine = runtime_cls:new(g, phases, { experimental_coroutine_turn = true })

    local res = g.turn_engine:run_turn()
    assert(res == "wait_move_anim", "should wait for move anim")
    local seq = g.turn.move_anim and g.turn.move_anim.seq
    assert(seq, "move_anim seq should be set")

    g:dispatch_action({ type = "move_anim_done", seq = seq })

    assert(g.turn.move_anim == nil, "move_anim should be cleared")
    local phase = g.turn.phase
    assert(phase ~= "wait_move_anim", "should resume after move anim done")
  end)

  it("_test_move_anim_zero_distance_safe", function()
    local _vec3 = vec3.with_sub_length

    local start_move_called = 0
    local scene = {
      tiles = {
        [1] = { get_position = function() return _vec3(1, 2, 3) end },
        [2] = { get_position = function() return _vec3(1, 2, 3) end },
      },
      units_by_player_id = {
        [1] = {
          start_move_by_direction = function()
            start_move_called = start_move_called + 1
          end,
        },
      },
    }

    local total = move_anim.play_sequence(scene, {
      player_id = 1,
      from_index = 1,
      to_index = 2,
      direction = { x = 0, y = 0, z = 1 },
    })

    _assert_eq(total, 0, "zero distance should return zero duration")
    _assert_eq(start_move_called, 0, "zero distance should skip unit move")
  end)

  it("_test_move_anim_step_unlocks_and_relocks", function()
    local _vec3 = vec3.with_sub_length

    local calls = {}
    local scene = {
      tiles = {
        [1] = { get_position = function() return _vec3(0, 0, 0) end },
        [2] = { get_position = function() return _vec3(10, 0, 0) end },
      },
      units_by_player_id = {
        [1] = {
          start_move_by_direction = function() end,
        },
      },
    }

    _with_patches({
      { key = "SetTimeOut", value = function(_, cb) cb() end },
    }, function()
      local anim_ctx = {
        on_step_lock = function(enabled)
          table.insert(calls, enabled)
        end,
        direction = { x = 1, y = 0, z = 0 },
      }
      move_anim.one_step(scene, 1, 1, 2, anim_ctx)
    end)

    _assert_eq(calls[1], false, "step should unlock at begin")
    _assert_eq(calls[2], true, "step should relock at end")
  end)
end)
