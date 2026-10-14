-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- luacheck: ignore 211
local support = require("test.support.shared_support")
local _new_game = support.new_game
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local function _assert_eq(actual, expected, message) luassert.is.equal(expected, actual, message) end
local _with_patches = support.with_patches
local turn_anim = require("src.turn.output.anim")
local modal_timeout = require("src.turn.waits.modal_timeout")
local tick_choice_timeout = require("test.support.choice_timeout")
local constants = require("src.config.content.constants")
local choice_resolver = require("src.rules.choice.resolver")
local turn_move = require("src.turn.phases.move")
local dispatch = require("src.turn.actions.action_dispatcher")
local runtime_port = require("src.ui.render.support.runtime_ui")
local move_anim = require("src.ui.render.move_anim")
local runtime_cls = require("src.turn.scheduler")
local vec3 = require("test.fixtures.vec3")

describe("TestTimingAnim", function()

  it("test_move_anim_callback_and_delay", function()
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

  it("test_popup_timeout_auto_confirm", function()
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
    modal_timeout.step(layer, near_timeout, timeout_opts)
    _assert_eq(popup.confirm_called, 0, "popup should not auto confirm before timeout")
    modal_timeout.step(layer, near_timeout + 1, timeout_opts)
    _assert_eq(popup.confirm_called, 1, "popup should auto confirm after timeout")
  end)

  it("test_runtime_port_with_client_role_restores_nested_context", function()
    local role1 = { name = "r1" }
    local role2 = { name = "r2" }
    local original = { name = "origin" }
    local manager = { client_role = original }

    _with_patches({
      { key = "UIManager", value = manager },
    }, function()
      runtime_port.with_client_role(role1, function()
        luassert.truthy(UIManager.client_role == role1, "outer with_client_role should set role1")
        runtime_port.with_client_role(role2, function()
          luassert.truthy(UIManager.client_role == role2, "nested with_client_role should set role2")
        end)
        luassert.truthy(UIManager.client_role == role1, "nested with_client_role should restore outer role")
      end)
      luassert.truthy(UIManager.client_role == original, "with_client_role should restore original role")

      local ok = pcall(function()
        runtime_port.with_client_role(role1, function()
          error("boom")
        end)
      end)
      luassert.truthy(ok == false, "with_client_role should rethrow callback error")
      luassert.truthy(UIManager.client_role == original, "with_client_role should restore role after error")
    end)
  end)

  it("test_runtime_port_native_size_prefers_native_method", function()
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

  it("test_runtime_port_native_size_fallback_keep_size", function()
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

  it("test_runtime_port_native_size_fallback_image_texture", function()
    local node = {}

    runtime_port.set_node_texture_native_size(node, "IMG_TEXTURE")

    _assert_eq(node.image_texture, "IMG_TEXTURE", "native path should fallback to image_texture field")
  end)

  it("test_choice_timeout_supports_explicit_timeout_strategy", function()
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
      tick_choice_timeout.new({
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
      }).step(game, state, 0.11)
    end)
    luassert.truthy(dispatched and dispatched.type == "choice_select", "explicit timeout strategy should dispatch action")
    luassert.truthy(dispatched and dispatched.choice_id == 7, "explicit timeout strategy should use pending choice id")
  end)

  it("test_invalid_choice_option_rejected", function()
    local g = _new_game()
    local choice = _open_choice(g, {
      kind = "market_buy",
      route_key = "market",
      owner_role_id = g:current_player().id,
      options = { { id = 1, label = "X" } },
      meta = { player_id = g:current_player().id },
    })
    choice_resolver.resolve(g, choice, { option_id = 999 })
    luassert.truthy(_get_choice(g) ~= nil, "invalid option should keep choice")
  end)

  it("test_move_anim_wait_and_resume", function()
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
    g.turn_runtime = runtime_cls:new(g, phases)

    local res = g.turn_runtime:run_turn()
    luassert.truthy(res == "wait_move_anim", "should wait for move anim")
    local seq = g.turn.move_anim and g.turn.move_anim.seq
    luassert.truthy(seq, "move_anim seq should be set")

    g:dispatch_action({ type = "move_anim_done", seq = seq })

    luassert.truthy(g.turn.move_anim == nil, "move_anim should be cleared")
    local phase = g.turn.phase
    luassert.truthy(phase ~= "wait_move_anim", "should resume after move anim done")
  end)

  it("test_move_anim_zero_distance_safe", function()
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

  it("test_move_anim_step_unlocks_and_relocks", function()
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

  it("test_move_anim_with_zero_delay_dispatches_immediately", function()
    -- #293:L57 `delay > 0`(→ `>=` 变异)与 `ok and delay and delay > 0`(→ or 变异)
    -- 在 delay=0 时会把立即 dispatch 误转成 schedule(0)。
    local dispatched = {}
    local layer = { wait_move_anim = true }
    local game = {
      turn = {
        move_anim = { seq = 2 },
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
        on_move_anim = function()
          return 0
        end,
      })
    end)
    luassert.truthy(delay_called == nil, "zero delay must not go through schedule; got " .. tostring(delay_called))
    _assert_eq(#dispatched, 1, "zero-delay anim still dispatches done once")
  end)

  it("test_move_anim_on_error_still_dispatches_done", function()
    -- #293:L57 `ok and delay and delay > 0`(→ or 变异)在 on_anim 抛错时会把
    -- 立即 dispatch 误转成对 nil delay 的比较崩溃。
    local dispatched = {}
    local layer = { wait_move_anim = true }
    local game = {
      turn = {
        move_anim = { seq = 3 },
        phase = "wait_move_anim",
      },
      dispatch_action = function(_, action)
        table.insert(dispatched, action)
      end,
    }
    local ok, err = pcall(function()
      turn_anim.step_move_anim(game, layer, {
        on_move_anim = function()
          error("boom")
        end,
      })
    end)
    luassert.truthy(ok, "on_anim failure must not crash the step; " .. tostring(err))
    _assert_eq(#dispatched, 1, "done is dispatched even when on_anim errored")
  end)

  it("test_move_anim_on_error_leaves_a_warn_trail", function()
    -- #339 留痕(ADR 0046):on_anim 异常不得零留痕进入 done 分支——
    -- warn 必须带 on_anim 标识与错误信息。
    local lines = {}
    local original_print = _G.print
    _G.print = function(...)
      local parts = {}
      for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
      end
      lines[#lines + 1] = table.concat(parts, " ")
    end
    local layer = { wait_move_anim = true }
    local game = {
      turn = { move_anim = { seq = 3 }, phase = "wait_move_anim" },
      dispatch_action = function() end,
    }
    local ok, err = pcall(function()
      turn_anim.step_move_anim(game, layer, {
        on_move_anim = function()
          error("boom")
        end,
      })
    end)
    _G.print = original_print
    luassert.truthy(ok, "step must not crash; " .. tostring(err))
    local output = table.concat(lines, "\n")
    luassert.truthy(output:find("[turn.anim]", 1, true) ~= nil, "failed on_anim must warn under [turn.anim]; got: " .. output)
    luassert.truthy(output:find("on_anim failed", 1, true) ~= nil, "warn must carry the on_anim failure marker; got: " .. output)
    luassert.truthy(output:find("move_anim", 1, true) ~= nil, "warn must identify the anim kind; got: " .. output)
    luassert.truthy(output:find("boom", 1, true) ~= nil, "warn must carry the error text; got: " .. output)
  end)


end)
