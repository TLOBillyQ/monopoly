local action_anim = require("src.ui.render.anim")
local pending_confirmation = require("src.state.pending_confirmation")
local anim_units = require("src.ui.render.anim.units")
local unit_overlay = require("src.ui.render.anim.unit_overlay")
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
local host_runtime = require("src.host")
local raycast = require("src.host.raycast")
local board_feedback = require("src.ui.render.board_feedback.service")
local event_names = require("src.foundation.events")
local landing_visual_hold = require("src.ui.visual_hold")
local pre_confirm = require("src.ui.input.pre_confirm")
local item_slot_confirm = require("src.ui.input.item_slot_confirm")
local choice_support = require("src.ui.view.choice_support")
local runtime_state = require("src.ui.state.runtime")
local assets = require("src.ui.render.assets")
local runtime_ui = require("src.ui.render.runtime_ui")
local node_ops = require("src.ui.render.node_ops")
local permanent_nodes = require("src.ui.schema.permanent")
local player_colors = require("src.ui.view.player_colors")
local item_slice = require("src.ui.view.item_slice")
local effect_track = require("src.ui.render.support.effect_track")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local sound = require("src.host.sound")
local entity_pool = require("src.host.entity_pool")
local unit_lifecycle = require("src.host.units")
local view_command = require("src.ui.ports.view_command")
local actor_context = require("src.ui.coord.actor_context")
local ui_event_state = require("src.ui.coord.event_state")
local event_log_view = require("src.ui.coord.event_log_view")
local canvas = require("src.ui.coord.canvas_coordinator")
local logger = require("src.foundation.log")
local canvas_store = require("src.ui.state.canvas_store")
local role_avatar = require("src.ui.view.role_avatar")
local placement = require("src.ui.render.board.placement")
local move_anim = require("src.ui.render.move_anim")
local debug_flags = require("src.config.gameplay.debug_flags")
local support = require("spec.support.ui_action_anim_support")

local _with_patches = support.with_patches

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed")
    .. " expected=" .. tostring(expected)
    .. " actual=" .. tostring(actual))
end

local function _ensure_vector3()
  if not math.Vector3 then
    function math.Vector3(x, y, z)
      return { x = x, y = y, z = z }
    end
  end
end

local function _reload_with(module_name, overrides, fn)
  local original_module = package.loaded[module_name]
  local originals = {}
  for key, value in pairs(overrides or {}) do
    originals[key] = package.loaded[key]
    package.loaded[key] = value
  end
  package.loaded[module_name] = nil

  local ok, result = pcall(function()
    return fn(require(module_name))
  end)

  package.loaded[module_name] = original_module
  for key, value in pairs(originals) do
    package.loaded[key] = value
  end
  if not ok then
    error(result)
  end
  return result
end

describe("refactorer_crap_coverage", function()
  before_each(function()
    _ensure_vector3()
  end)

  it("action anim zero timing config is preserved when module loads", function()
    local fake_registry = {
      register = function() end,
      resolve = function(kind)
        if kind == "roll" then
          return nil
        end
        return nil
      end,
    }

    _reload_with("src.ui.render.anim", {
      ["src.config.gameplay.timing"] = {
        action_anim_default_seconds = 1.0,
        demolish_effect_start_delay_seconds = 0,
        dice_spin_seconds = 1.0,
        dice_face_hold_seconds = 1.0,
      },
      ["src.ui.render.anim.registry"] = fake_registry,
    }, function(reloaded_action_anim)
      local duration = reloaded_action_anim.play(support.build_min_state(), {
        kind = "missile",
      }, {
        runtime_bundle = {
          runtime = {},
          ui_events = { show = {}, hide = {}, send_to_all = function() end },
          host_runtime = {
            enqueue_tip = function() end,
            schedule = function() error("zero start delay should not schedule") end,
          },
        },
      })

      _assert_eq(duration, 1.2, "zero demolish start delay should not fall back to 0.2")
    end)
  end)

  it("action anim zero roll timing is preserved in registered roll handler", function()
    local registered = {}
    local fake_registry = {
      register = function(kind, handler)
        registered[kind] = handler
      end,
      resolve = function(kind)
        return registered[kind]
      end,
    }
    local captured_spin = nil
    local captured_hold = nil

    _reload_with("src.ui.render.anim", {
      ["src.config.gameplay.timing"] = {
        action_anim_default_seconds = 1.0,
        demolish_effect_start_delay_seconds = 0.2,
        dice_spin_seconds = 0,
        dice_face_hold_seconds = 0,
      },
      ["src.ui.render.anim.registry"] = fake_registry,
    }, function(reloaded_action_anim)
      _with_patches({
        { target = require("src.ui.render.anim.handlers"), key = "play_roll_dice_screen", value = function(_, _, spin, hold)
          captured_spin = spin
          captured_hold = hold
        end },
      }, function()
        local duration = reloaded_action_anim.play(support.build_min_state(), {
          kind = "roll",
        }, {
          runtime_bundle = {
            runtime = {},
            ui_events = { show = {}, hide = {}, send_to_all = function() end },
            host_runtime = {},
          },
        })

        _assert_eq(duration, 0, "zero roll timings should make roll handler return zero duration")
      end)
    end)

    _assert_eq(captured_spin, 0, "zero dice spin should not fall back to 1.0")
    _assert_eq(captured_hold, 0, "zero dice hold should not fall back to 1.0")
  end)

  it("anim units zero mine snap delay uses immediate fallback path", function()
    _reload_with("src.ui.render.anim.units", {
      ["src.config.gameplay.timing"] = {
        mine_trigger_snap_delay_seconds = 0,
        demolish_effect_followup_delay_seconds = 0.35,
        teleport_effect_camera_hold_seconds = 1.0,
        roadblock_destroy_hold_seconds = 0,
      },
    }, function(reloaded_units)
      local scheduled = 0
      local snapped = 0
      local state = support.build_min_state()

      _with_patches({
        { target = board_feedback, key = "play_tile_cue", value = function() end },
        { target = board_feedback, key = "play_player_cue", value = function() end },
        { target = require("src.ui.render.move_anim"), key = "prepare_player_for_snap", value = function() end },
        { target = require("src.ui.render.move_anim"), key = "snap_player_to_index", value = function()
          snapped = snapped + 1
          return 0
        end },
      }, function()
        local duration = reloaded_units.play_mine_trigger(state, {
          player_id = 1,
          tile_index = 1,
          to_index = 1,
        }, 0.2, {
          clear_overlay = function() end,
          schedule = function()
            scheduled = scheduled + 1
          end,
        })

        _assert_eq(duration, 0.2, "zero snap delay should keep supplied duration")
      end)

      _assert_eq(scheduled, 0, "zero mine snap delay should not schedule")
      _assert_eq(snapped, 1, "zero mine snap delay should snap immediately")
    end)
  end)

  it("anim units roadblock destroy hold uses configured nonzero delay", function()
    _reload_with("src.ui.render.anim.units", {
      ["src.config.gameplay.timing"] = {
        mine_trigger_snap_delay_seconds = 0.6,
        demolish_effect_followup_delay_seconds = 0.35,
        teleport_effect_camera_hold_seconds = 1.0,
        roadblock_destroy_hold_seconds = 0.4,
      },
    }, function(reloaded_units)
      local scheduled_delay = nil
      local cleared = 0
      local state = support.build_min_state()

      local duration = reloaded_units.play_roadblock_trigger(state, {
        tile_index = 1,
      }, 0.1, {
        clear_overlay = function()
          cleared = cleared + 1
        end,
        schedule = function(delay, fn)
          scheduled_delay = delay
          fn()
        end,
      })

      _assert_eq(duration, 0.4, "roadblock hold should extend shorter duration")
      _assert_eq(scheduled_delay, 0.4, "roadblock hold should preserve configured delay")
      _assert_eq(cleared, 1, "scheduled roadblock clear should run")
    end)
  end)

  it("anim overlay clear delegates to runtime with board scene deps", function()
    local state = support.build_min_state()
    local calls = {}

    _with_patches({
      { target = overlay_runtime, key = "clear_overlay", value = function(board_scene, kind, tile_index, deps)
        calls[#calls + 1] = {
          board_scene = board_scene,
          kind = kind,
          tile_index = tile_index,
          deps = deps,
        }
      end },
    }, function()
      unit_overlay.clear_overlay(state, "mine", 1)
    end)

    _assert_eq(#calls, 1, "clear_overlay should call runtime once")
    _assert_eq(calls[1].board_scene, state.board_scene, "clear_overlay should pass board scene")
    _assert_eq(calls[1].kind, "mine", "clear_overlay should pass kind")
    _assert_eq(calls[1].tile_index, 1, "clear_overlay should pass tile index")
  end)

  it("anim units pan camera releases immediately without scheduler", function()
    local state = support.build_min_state()
    local pan_calls = 0
    local release_calls = 0
    local overlay_calls = 0

    _with_patches({
      { target = unit_overlay, key = "play_overlay", value = function()
        overlay_calls = overlay_calls + 1
      end },
    }, function()
      anim_units.play_overlay(state, { kind = "roadblock", tile_index = 1 }, 0.4, {
        pan_camera_to_position = function(_, pos)
          pan_calls = pan_calls + 1
          _assert_eq(pos.x, 0.0, "pan should receive resolved tile position")
          return true
        end,
        release_target_pan = function(release_state)
          release_calls = release_calls + 1
          _assert_eq(release_state, state, "release should receive state")
        end,
      })
    end)

    _assert_eq(pan_calls, 1, "roadblock should pan to tile")
    _assert_eq(release_calls, 1, "missing scheduler should release immediately")
    _assert_eq(overlay_calls, 1, "overlay handler should still run")
  end)

  it("anim units pan release normalizes invalid scheduled duration", function()
    local state = support.build_min_state()
    local scheduled_delay = nil
    local scheduled_fn = nil
    local release_calls = 0

    _with_patches({
      { target = unit_overlay, key = "play_overlay", value = function() end },
    }, function()
      anim_units.play_overlay(state, { kind = "roadblock", tile_index = 1 }, -1, {
        pan_camera_to_position = function()
          return true
        end,
        release_target_pan = function()
          release_calls = release_calls + 1
        end,
        schedule = function(delay, fn)
          scheduled_delay = delay
          scheduled_fn = fn
        end,
      })
    end)

    _assert_eq(scheduled_delay, 0, "negative release duration should clamp to zero")
    _assert_eq(release_calls, 0, "release should wait for scheduler callback")
    scheduled_fn()
    _assert_eq(release_calls, 1, "scheduled release callback should release pan")
  end)

  it("anim overlay destroy falls back to host destroy methods", function()
    local state = support.build_min_state()
    local destroy_unit_calls = 0
    local destroy_children_calls = 0

    _with_patches({
      { target = host_runtime, key = "acquire_unit", value = function()
        return { id = "robot" }
      end },
      { target = host_runtime, key = "release_unit", value = nil },
      { target = host_runtime, key = "destroy_unit", value = function()
        destroy_unit_calls = destroy_unit_calls + 1
      end },
      { target = host_runtime, key = "destroy_unit_with_children", value = function()
        destroy_children_calls = destroy_children_calls + 1
      end },
    }, function()
      unit_overlay.play_clear_obstacles(state, {
        player_id = 1,
        branches = {},
      }, 0.1, {
        clear_overlay = function() end,
      })
    end)

    _assert_eq(destroy_unit_calls, 1, "destroy_unit should be the first fallback")
    _assert_eq(destroy_children_calls, 0, "destroy_unit_with_children should not run after destroy_unit")

    _with_patches({
      { target = host_runtime, key = "acquire_unit", value = function()
        return { id = "robot" }
      end },
      { target = host_runtime, key = "release_unit", value = nil },
      { target = host_runtime, key = "destroy_unit", value = nil },
      { target = host_runtime, key = "destroy_unit_with_children", value = function(_, include_children)
        destroy_children_calls = destroy_children_calls + 1
        _assert_eq(include_children, true, "children fallback should request recursive destroy")
      end },
    }, function()
      unit_overlay.play_clear_obstacles(state, {
        player_id = 1,
        branches = {},
      }, 0.1, {
        clear_overlay = function() end,
      })
    end)

    _assert_eq(destroy_children_calls, 1, "destroy_unit_with_children should run when other fallbacks are missing")
  end)

  it("action anim default bundle and unknown kind still resolve duration", function()
    local state = support.build_min_state()
    local duration = action_anim.play(state, {
      kind = "unknown_kind",
      duration = -1,
    })

    _assert_eq(duration, 1.0, "invalid duration should fall back to default action duration")
  end)

  it("raycast camera ray falls back to controlled unit direction", function()
    local direction = { x = 0, y = 0, z = 1 }
    local ctrl_unit = {
      get_position = function()
        return { x = 1, y = 2, z = 3 }
      end,
      get_forward = function()
        return direction
      end,
    }
    local role = {
      get_ctrl_unit = function()
        return ctrl_unit
      end,
    }

    local ray = assert(raycast.build_camera_ray(role, {
      eye_offset_y = 2.0,
      ray_distance = 5.0,
    }))

    _assert_eq(ray.direction, direction, "raycast should use unit direction fallback")
    _assert_eq(ray.start_pos.x, 1, "ray start x should preserve unit position")
    _assert_eq(ray.start_pos.y, 4.0, "ray start y should include eye offset")
    _assert_eq(ray.end_pos.z, 8.0, "ray end should include scaled direction")
  end)

  it("anim units teleport pans to destination for at least hold duration", function()
    local state = support.build_min_state({
      mutate = function(target)
        target.board_scene.tiles[2] = {
          get_position = function()
            return math.Vector3(20.0, 0.0, 0.0)
          end,
        }
      end,
    })
    local scheduled_delay = nil
    local played = 0

    _with_patches({
      { target = require("src.ui.render.move_anim"), key = "play_teleport", value = function()
        played = played + 1
        return 0.25
      end },
    }, function()
      local duration = anim_units.play_teleport_effect(state, {
        player_id = 1,
        from_index = 1,
        to_index = 2,
      }, 0.1, {
        pan_camera_to_position = function(_, pos)
          _assert_eq(pos.x, 20.0, "teleport pan should target destination tile")
          return true
        end,
        release_target_pan = function() end,
        schedule = function(delay)
          scheduled_delay = delay
        end,
      })

      _assert_eq(duration, 0.25, "teleport should return move animation duration")
    end)

    _assert_eq(played, 1, "teleport move animation should play")
    _assert_eq(scheduled_delay, 1.0, "teleport pan should hold for configured minimum")
  end)

  it("event handler angel immune routes tile and player cues", function()
    local captured = {}
    local tile_calls = {}
    local player_calls = {}
    local state = { game = {} }

    _reload_with("src.ui.coord.event_handlers", {}, function(event_handlers)
      _with_patches({
        { target = host_runtime, key = "register_custom_event", value = function(event_name, handler)
          captured[event_name] = handler
        end },
        { target = landing_visual_hold, key = "run_or_defer", value = function(_, _, _, fn)
          return fn()
        end },
        { target = board_feedback, key = "play_tile_cue", value = function(_, cue_name, tile_index)
          tile_calls[#tile_calls + 1] = cue_name .. ":" .. tostring(tile_index)
        end },
        { target = board_feedback, key = "play_player_cue", value = function(_, cue_name, player_id)
          player_calls[#player_calls + 1] = cue_name .. ":" .. tostring(player_id)
        end },
      }, function()
        event_handlers.install(nil, {}, state)
        local handler = assert(captured[event_names.feedback.angel_immune_blocked])
        handler(nil, nil, { tile_index = 3, player_id = 4 })
        handler(nil, nil, { player_id = 4 })
      end)
    end)

    _assert_eq(tile_calls[1], "angel_deity:3", "tile event should prefer tile cue")
    _assert_eq(player_calls[1], "angel_deity:4", "player event should fall back to player cue")
  end)

  it("pre confirm cancel restores non-inline source screen", function()
    local state = {
      gameplay_loop_ports = {
        modal = {},
      },
    }
    pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, { source_screen = "market" })
    local open_calls = 0
    local close_calls = 0
    state.gameplay_loop_ports.modal.open_choice_modal = function(_, choice)
      open_calls = open_calls + 1
      _assert_eq(choice.id, "choice1", "cancel should restore current choice")
    end
    state.gameplay_loop_ports.modal.close_choice_modal = function()
      close_calls = close_calls + 1
    end
    runtime_state.set_ui_model(state, {
      choice = { id = "choice1" },
    })
    runtime_state.set_pending_choice_id(state, "choice1")

    pre_confirm.cancel(state)

    _assert_eq(pending_confirmation.is_active(state), false, "cancel should clear active record")
    _assert_eq(pending_confirmation.source_screen(state), nil, "cancel should clear source")
    _assert_eq(runtime_state.get_pending_choice_id(state), nil, "cancel should clear pending choice id")
    _assert_eq(open_calls, 1, "non-inline cancel should reopen prior modal")
    _assert_eq(close_calls, 0, "non-inline cancel should not close modal")
  end)

  it("item slot confirm dispatches stored intent and closes confirm state", function()
    local stored_intent = { type = "ui_button", id = "item_slot_1" }
    local state = {
      gameplay_loop_ports = {
        modal = {},
      },
    }
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_SLOT, { intent = stored_intent })
    state.gameplay_loop_ports.modal.close_choice_modal = function(close_state)
      _assert_eq(close_state, state, "close should receive state")
    end
    local dispatched = {}
    local action_port = {
      dispatch_action = function(game, dispatch_state, intent, opts)
        dispatched[#dispatched + 1] = {
          game = game,
          state = dispatch_state,
          intent = intent,
          opts = opts,
        }
      end,
    }
    local game = {}
    local opts = { source = "test" }

    local handled = item_slot_confirm.dispatch(state, game, { type = "choice_select" }, opts, action_port)

    _assert_eq(handled, true, "active slot confirm should handle choice_select")
    _assert_eq(pending_confirmation.is_active(state), false, "dispatch should clear active record")
    _assert_eq(pending_confirmation.stored_intent(state), nil, "dispatch should clear stored intent")
    _assert_eq(#dispatched, 1, "dispatch should replay stored intent")
    _assert_eq(dispatched[1].intent, stored_intent, "dispatch should replay original slot intent")
  end)

  it("assets init assigns all configured item slot icons", function()
    local slot_images = {}
    local role_iterations = 0
    local state = {}

    _with_patches({
      { target = runtime_ui, key = "for_each_role_or_global", value = function(fn)
        role_iterations = role_iterations + 1
        fn(nil)
      end },
      { target = runtime_ui, key = "set_client_role", value = function(role)
        _assert_eq(role, nil, "asset init should reset client role")
      end },
      { target = node_ops, key = "set_item_slot_image", value = function(node_name, image_key)
        slot_images[#slot_images + 1] = {
          node_name = node_name,
          image_key = image_key,
        }
      end },
    }, function()
      assets.init_ui_assets(state)
    end)

    _assert_eq(role_iterations, 1, "asset init should run for global role scope")
    _assert_eq(#slot_images, 5, "asset init should set five item slot images")
    _assert_eq(slot_images[1].node_name, permanent_nodes.item_slots[1], "first slot node should match schema")
    assert(state.ui_refs ~= nil, "asset init should store ui refs on state")
  end)

  it("player colors setter copies supplied owner colors", function()
    player_colors.set_owner_colors("invalid")
    player_colors.set_owner_colors({
      p1 = 101,
      p2 = 202,
    })

    _assert_eq(player_colors.resolve_owner_color("p1"), 101, "setter should keep p1 color")
    _assert_eq(player_colors.resolve_owner_color("p2"), 202, "setter should keep p2 color")
    _assert_eq(player_colors.resolve_owner_color("missing"), 0xcfcfcf, "missing owner should use default")
  end)

  it("ui events builds sorted canvas maps from UIManager nodes", function()
    _reload_with("src.ui.coord.ui_events", {
      ["Data.UIManagerNodes"] = {
        ignored = { "Ignored", "EText" },
        z_canvas = { "ZCanvas", "ECanvas" },
        a_canvas = { "ACanvas", "ECanvas" },
      },
    }, function(ui_events)
      _assert_eq(ui_events.canvas_names[1], "ACanvas", "canvas names should sort ascending")
      _assert_eq(ui_events.canvas_names[2], "ZCanvas", "canvas names should include second canvas")
      _assert_eq(ui_events.show.ACanvas, "显示ACanvas", "show event should be generated")
      _assert_eq(ui_events.hide.ZCanvas, "隐藏ZCanvas", "hide event should be generated")
    end)
  end)

  it("entity pool prewarm fills idle bucket and respects max idle", function()
    entity_pool.reset()
    local created = 0
    local hidden = 0
    local parked = 0

    _with_patches({
      { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
        created = created + 1
        return {
          set_model_visible = function(visible)
            if visible == false then
              hidden = hidden + 1
            end
          end,
          set_position = function()
            parked = parked + 1
          end,
        }
      end },
    }, function()
      entity_pool.prewarm("unit-a", 2, nil, nil, { x = 1, y = 2, z = 3 })
      entity_pool.prewarm(nil, 2)
      entity_pool.prewarm("unit-a", -1)
    end)

    local stats = entity_pool.stats()
    _assert_eq(created, 2, "prewarm should create requested idle units")
    _assert_eq(hidden, 2, "prewarm should hide created units")
    _assert_eq(parked, 2, "prewarm should park created units")
    _assert_eq(stats["unit-a"].idle, 2, "prewarm should fill idle bucket")
    entity_pool.reset()
  end)

  it("view command warns when enabling action log without role event channel", function()
    local warnings = {}
    local state = { ui = { debug_log_enabled_by_role = {} } }
    local ports = view_command.build()

    _with_patches({
      { target = actor_context, key = "resolve_role_by_id", value = function()
        return {}
      end },
      { target = ui_event_state, key = "resolve_event_log_enabled", value = function()
        return false
      end },
      { target = event_log_view, key = "set_event_log_visible_for_role", value = function(_, _, visible)
        _assert_eq(visible, true, "toggle should enable hidden action log")
      end },
      { target = canvas, key = "switch_for_role", value = function() end },
      { target = runtime_ui, key = "set_client_role", value = function() end },
      { target = logger, key = "warn", value = function(...)
        warnings[#warnings + 1] = table.concat({ ... }, " ")
      end },
    }, function()
      _assert_eq(ports.dispatch(state, { type = "toggle_action_log", actor_role_id = 9 }), true,
        "toggle action log command should be handled")
    end)

    assert((warnings[1] or ""):find("toggle_action_log missing role event channel", 1, true),
      "toggle should warn when active role cannot receive UI events")
  end)

  it("item slice standalone slots filters empty inventory entries", function()
    local slots = item_slice.build_item_slots_for_player({
      inventory = {
        items = {
          { id = 11 },
          {},
          { id = 22 },
          { id = 33 },
        },
      },
    }, 2)

    _assert_eq(slots[1], 11, "first valid item should fill first slot")
    _assert_eq(slots[2], 22, "second valid item should fill second slot")
    _assert_eq(slots[3], nil, "slot builder should trim beyond slot count")
  end)

  it("effect track pending await polls until idle then calls callback", function()
    local callbacks = {}
    local scheduled = {}
    effect_track.reset()

    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, fn)
        scheduled[#scheduled + 1] = {
          delay = delay,
          fn = fn,
        }
      end },
    }, function()
      effect_track.spawn("cue1", "kind", 0.1)
      local idle = effect_track.await_all(function()
        callbacks[#callbacks + 1] = "done"
      end)

      _assert_eq(idle, false, "await_all should report pending effects")
      _assert_eq(#callbacks, 0, "callback should wait while effects are active")
      assert(#scheduled >= 2, "spawn and await should schedule callbacks")

      scheduled[1].fn()
      scheduled[#scheduled].fn()
    end)

    _assert_eq(callbacks[1], "done", "await callback should run after effects drain")
    effect_track.reset()
  end)

  it("sound binding reports success and missing host function", function()
    local calls = 0
    local unit = {}

    _with_patches({
      { key = "GlobalAPI", value = {
        bind_sfx_to_unit = function(sfx_id, target_unit, socket_name, pos, bind_type)
          calls = calls + 1
          _assert_eq(sfx_id, 7, "sfx id should pass through")
          _assert_eq(target_unit, unit, "unit should pass through")
          _assert_eq(socket_name, "body", "socket should pass through")
          _assert_eq(pos.x, 1, "position should pass through")
          _assert_eq(bind_type, "follow", "bind type should pass through")
        end,
      } },
    }, function()
      _assert_eq(sound.bind_sfx_to_unit(7, unit, "body", { x = 1 }, "follow"), true,
        "bind should return true when host call succeeds")
    end)

    _assert_eq(calls, 1, "host bind should be called once")
    _with_patches({
      { key = "GlobalAPI", value = {} },
    }, function()
      _assert_eq(sound.bind_sfx_to_unit(7, unit), false, "missing host bind should return false")
    end)
  end)

  it("sound sfx key validates rate and routes valid host call", function()
    local calls = {}

    _with_patches({
      { key = "GameAPI", value = {
        play_sfx_by_key = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
          calls[#calls + 1] = {
            sfx_key = sfx_key,
            pos = pos,
            rot = rot,
            scale = scale,
            duration = duration,
            rate = rate,
            with_sound = with_sound,
          }
          return 77
        end,
      } },
    }, function()
      _assert_eq(sound.play_sfx_by_key(100, nil, nil, 2.0, nil, nil, true), 77,
        "valid sfx should return host id")
      _assert_eq(sound.play_sfx_by_key(101, nil, nil, 2.0, nil, "bad", false), 77,
        "invalid rate input should fall back to default rate")
    end)

    _assert_eq(#calls, 2, "valid sfx calls should reach host")
    _assert_eq(calls[1].sfx_key, 100, "sfx key should be integer")
    _assert_eq(calls[1].scale, 2.0, "scale should pass through")
    _assert_eq(calls[1].duration, 1.0, "duration should use default")
    _assert_eq(calls[1].rate, 1.0, "rate should use default")
    _assert_eq(calls[1].with_sound, true, "with_sound should pass true")
    _assert_eq(calls[2].rate, 1.0, "invalid rate input should use default")
  end)

  it("entity pool acquire reuses a parked idle handle and refreshes its transform", function()
    entity_pool.reset()
    local created = 0
    local calls = { position = 0, orientation = 0, scale = 0, visible = nil }
    local handle = {
      set_position = function()
        calls.position = calls.position + 1
      end,
      set_orientation = function()
        calls.orientation = calls.orientation + 1
      end,
      set_world_scale = function()
        calls.scale = calls.scale + 1
      end,
      set_model_visible = function(visible)
        calls.visible = visible
      end,
    }

    _with_patches({
      { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
        created = created + 1
        return handle
      end },
    }, function()
      entity_pool.prewarm("unit-reuse", 1, nil, nil, { x = 0, y = 0, z = 0 })
      local acquired = entity_pool.acquire("unit-reuse", { x = 1, y = 2, z = 3 }, nil, nil)
      _assert_eq(acquired, handle, "acquire should reuse the parked idle handle")
    end)

    _assert_eq(created, 1, "reuse path must not create a second unit")
    _assert_eq(calls.orientation, 1, "reused handle should be reoriented on acquire")
    _assert_eq(calls.scale, 1, "reused handle should be rescaled on acquire")
    _assert_eq(calls.visible, true, "reused handle should be made visible on acquire")
    local stats = entity_pool.stats()
    _assert_eq(stats["unit-reuse"].idle, 0, "acquire should drain the idle bucket")
    entity_pool.reset()
  end)

  it("play_sfx_by_key returns nil when the host call is missing or errors", function()
    _with_patches({
      { key = "GameAPI", value = {} },
    }, function()
      _assert_eq(sound.play_sfx_by_key(100, nil, nil, 2.0), nil,
        "missing GameAPI.play_sfx_by_key should skip and return nil")
    end)

    local raised = 0
    local warned = 0
    _with_patches({
      { key = "GameAPI", value = {
        play_sfx_by_key = function()
          raised = raised + 1
          error("host sfx boom")
        end,
      } },
      { target = logger, key = "warn", value = function()
        warned = warned + 1
      end },
    }, function()
      _assert_eq(sound.play_sfx_by_key(100, nil, nil, 2.0), nil,
        "a throwing host call should be swallowed and return nil")
    end)

    _assert_eq(raised, 1, "the host sfx call should have been attempted once")
    _assert_eq(warned, 1, "a swallowed host error should emit a skip warning")
  end)

  it("item slot confirm try_enter opens the pre-confirm screen only for a confirmable slot", function()
    _assert_eq(item_slot_confirm.try_enter({}, { type = "ui_button", id = "auto" }), false,
      "a non-slot button id should not enter slot confirm")
    _assert_eq(item_slot_confirm.try_enter({}, { type = "ui_button", id = "item_slot_9" }), false,
      "a slot index with no confirmable option should not enter")

    local choice = { slot_states = { [2] = { available = true, item_id = 55 } } }
    local opened = nil
    local modal = {
      open_pre_confirm_screen = function(_, _, item_id, title, body)
        opened = { item_id = item_id, title = title, body = body }
      end,
    }
    local state = { gameplay_loop_ports = { modal = modal } }
    runtime_state.set_ui_model(state, { choice = choice })

    _with_patches({
      { target = choice_support, key = "resolve_option_by_id", value = function(_, item_id)
        _assert_eq(item_id, 55, "option lookup should use the confirmable slot item id")
        return { confirm_title = "使用？", confirm_body = "确认使用" }
      end },
    }, function()
      _assert_eq(item_slot_confirm.try_enter(state, { type = "ui_button", id = "item_slot_2" }), true,
        "a confirmable slot should enter pre-confirm")
    end)

    _assert_eq(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_SLOT), true, "try_enter should mark slot confirm active")
    _assert_eq(opened.item_id, 55, "pre-confirm should open for the slot item")
    _assert_eq(opened.title, "使用？", "pre-confirm should pass the resolved confirm title")

    local state2 = { gameplay_loop_ports = { modal = {} } }
    runtime_state.set_ui_model(state2, { choice = choice })
    _with_patches({
      { target = choice_support, key = "resolve_option_by_id", value = function()
        return { confirm_title = "使用？" }
      end },
    }, function()
      _assert_eq(item_slot_confirm.try_enter(state2, { type = "ui_button", id = "item_slot_2" }), false,
        "a host without open_pre_confirm_screen should abort the entry")
    end)
    _assert_eq(pending_confirmation.is_active(state2), false, "an aborted try_enter should not leave an active record")
  end)

  it("ui event state resolves explicit and current role action-log flags", function()
    local role = { id = "role-a" }
    local state = {
      ui = {
        debug_log_enabled_by_role = {
          ["role-a"] = true,
          ["9"] = false,
        },
      },
    }

    _with_patches({
      { target = runtime_ui, key = "get_client_role", value = function()
        return role
      end },
      { target = runtime_ui, key = "resolve_role_id", value = function(value)
        return value and value.id or nil
      end },
    }, function()
      _assert_eq(ui_event_state.resolve_event_log_enabled(state, nil), true,
        "nil role should resolve current client role")
      _assert_eq(ui_event_state.resolve_event_log_enabled(state, 9), false,
        "explicit role should read by normalized id")
      _assert_eq(ui_event_state.resolve_event_log_enabled(state, nil), true,
        "current role should remain enabled")
    end)
  end)

  it("canvas store patch_slice handles nil, table, function, and invalid patches", function()
    local state = { ui = {} }

    -- nil patch: marks dirty and returns the slice without mutation.
    local slice = canvas_store.patch_slice(state, "board", nil)
    assert(type(slice) == "table", "patch_slice should return the slice table")
    _assert_eq(state.ui.canvas_store.dirty.board, true, "nil patch should still mark the key dirty")

    -- table patch: shallow-copies keys onto the slice.
    canvas_store.patch_slice(state, "board", { zoom = 3, mode = "fit" })
    local board = canvas_store.get_slice(state, "board")
    _assert_eq(board.zoom, 3, "table patch should copy numeric field")
    _assert_eq(board.mode, "fit", "table patch should copy string field")

    -- function patch: receives (slice, ui, state_or_ui) and mutates in place.
    local seen_ui, seen_state = nil, nil
    canvas_store.patch_slice(state, "board", function(target, ui, raw)
      target.flag = true
      seen_ui, seen_state = ui, raw
    end)
    _assert_eq(canvas_store.get_slice(state, "board").flag, true, "function patch should mutate the slice")
    _assert_eq(seen_ui, state.ui, "function patch should receive the resolved ui")
    _assert_eq(seen_state, state, "function patch should receive the original state arg")

    -- invalid patch type: raises a descriptive error.
    local ok, err = pcall(canvas_store.patch_slice, state, "board", 42)
    _assert_eq(ok, false, "a non-table/function patch must raise")
    assert(tostring(err):find("expects table/function patch", 1, true),
      "invalid patch error should name the contract")
  end)

  it("role avatar sanitize_image_key covers nil, invalid, non-positive, and valid keys", function()
    local warns = 0
    _with_patches({
      { target = logger, key = "warn", value = function() warns = warns + 1 end },
    }, function()
      _assert_eq(role_avatar.sanitize_image_key(nil), nil, "nil key resolves to nil without warning")
      _assert_eq(role_avatar.sanitize_image_key({}), nil, "non-integer key resolves to nil")
      _assert_eq(role_avatar.sanitize_image_key(-3), nil, "negative key resolves to nil")
      _assert_eq(role_avatar.sanitize_image_key(0), nil, "zero key resolves to nil without warning")
      _assert_eq(role_avatar.sanitize_image_key(5), 5, "positive integer key passes through")
    end)
    assert(warns >= 2, "non-integer and negative keys should each warn (got " .. warns .. ")")
  end)

  it("role avatar resolve_from_role guards missing role, missing getter, and getter errors", function()
    _assert_eq(role_avatar.resolve_from_role(nil), nil, "nil role resolves to nil")
    _assert_eq(role_avatar.resolve_from_role({}), nil, "role without get_head_icon resolves to nil")
    _assert_eq(role_avatar.resolve_from_role({ get_head_icon = function() error("boom") end }), nil,
      "a throwing getter is swallowed to nil")
    _assert_eq(role_avatar.resolve_from_role({ get_head_icon = function() return 9 end }), 9,
      "a valid getter resolves the sanitized key")
  end)

  it("board feedback catalog resolves numeric cue fields and rejects non-numeric ones", function()
    local warns = 0
    _reload_with("src.ui.render.board_feedback.catalog", {
      ["src.config.content.runtime_refs"] = {
        board_feedback = {
          my_cue = {
            scale = 2,
            rate = { x = 1 },          -- vector-like: rejected with a warning
            duration = "abc",          -- non-numeric: rejected with a warning
            volume = nil,              -- absent: stays nil, no warning
            delay = 3,
            followup_sounds = { { delay = "nope" } }, -- nested non-numeric: warns
          },
        },
      },
      ["src.foundation.log"] = {
        warn = function() warns = warns + 1 end,
        info = function() end,
        error = function() end,
      },
    }, function(reloaded_catalog)
      _assert_eq(reloaded_catalog.get(nil), nil, "nil cue name resolves to nil")
      _assert_eq(reloaded_catalog.get("unknown"), nil, "an unknown cue resolves to nil")

      local cue = reloaded_catalog.get("my_cue")
      _assert_eq(cue.scale, 2, "numeric field passes through")
      _assert_eq(cue.delay, 3, "numeric field passes through")
      _assert_eq(cue.rate, nil, "vector-like field is rejected")
      _assert_eq(cue.duration, nil, "non-numeric string field is rejected")
    end)
    assert(warns >= 3, "vector, non-numeric, and nested non-numeric fields should warn (got " .. warns .. ")")
  end)

  it("choice support resolves option ids, labels, and lookups across shapes", function()
    _assert_eq(choice_support.resolve_option_id({ id = 5 }), 5, "table option resolves its id")
    _assert_eq(choice_support.resolve_option_id("scalar"), "scalar", "scalar option resolves to itself")

    _assert_eq(choice_support.resolve_option_label({ label = "L" }), "L", "table label wins")
    _assert_eq(choice_support.resolve_option_label({ id = 7 }), "7", "id falls back to its string")
    _assert_eq(choice_support.resolve_option_label("z"), "z", "scalar label is its string")

    local choice = { options = { { id = 1, label = "one" }, { id = 2, label = "two" } } }
    _assert_eq(choice_support.resolve_option_by_id(nil, 1), nil, "nil choice resolves to nil")
    _assert_eq(choice_support.resolve_option_by_id(choice, nil), nil, "nil id resolves to nil")
    _assert_eq(choice_support.resolve_option_by_id({ options = "bad" }, 1), nil, "non-table options resolve to nil")
    _assert_eq(choice_support.resolve_option_by_id(choice, 2).label, "two", "matching id returns its option")
    _assert_eq(choice_support.resolve_option_by_id(choice, 9), nil, "missing id resolves to nil")

    _assert_eq(choice_support.resolve_option_label_by_id(choice, 1), "one", "label-by-id returns table label")
    _assert_eq(choice_support.resolve_option_label_by_id(choice, 9), nil, "missing id label resolves to nil")
    _assert_eq(choice_support.resolve_option_label_by_id({ options = { 3 } }, 3), "3",
      "scalar option falls back to the matched id string")
  end)

  it("choice support secondary confirm body falls back through option and choice text", function()
    _assert_eq(choice_support.resolve_secondary_confirm_body(nil, nil, nil, nil, ""),
      "请再确认一次", "no choice and empty label uses the generic fallback")
    _assert_eq(choice_support.resolve_secondary_confirm_body(nil, nil, nil, nil, "金牌"),
      "你选的是：金牌", "no choice with a label echoes the label")

    local choice = { options = { { id = 1, confirm_body = "确认买入" } }, confirm_body = "通用确认" }
    _assert_eq(choice_support.resolve_secondary_confirm_body(choice, nil, nil, 1), "确认买入",
      "option confirm_body wins when present")
    _assert_eq(choice_support.resolve_secondary_confirm_body({ confirm_body = "通用确认" }, nil, nil, 1),
      "通用确认", "choice confirm_body is the next fallback")
  end)

  it("board placement offsets cover grid, single-slot, zero-spacing, and y-lift paths", function()
    local saved_vector3 = math.Vector3
    -- Give the base position an __add so the real placement path can offset it
    -- with a plain math.Vector3 delta without depending on a host vector type.
    local function based(x, y, z)
      return setmetatable({ x = x, y = y, z = z }, {
        __add = function(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end,
      })
    end
    function math.Vector3(x, y, z) return { x = x, y = y, z = z } end

    local placed = {}
    local function unit_for(pid)
      return { set_position = function(pos) placed[pid] = pos end }
    end

    _with_patches({
      { target = runtime_state, key = "set_follow_target_position", value = function() end },
      { target = move_anim, key = "stop_player_presentation", value = function() return {} end },
    }, function()
      -- Two players sharing one tile: count=2, spacing>0 -> grid offsets diverge;
      -- base_y >= min_player_y -> y_offset 0.
      local state = {
        tile_positions = { [3] = based(0.0, 5.0, 0.0) },
        player_units = { [1] = unit_for(1), [2] = unit_for(2) },
      }
      placement.place_players(state,
        { { id = 1, position = 3 }, { id = 2, position = 3 } },
        { [3] = { 1, 2 } }, 2.0, 0.0)
      assert(placed[1].x ~= placed[2].x, "two-occupant grid should separate slot x")
      _assert_eq(placed[1].y, 5.0, "y_offset 0 should keep base y when base is above the floor")

      -- Single occupant: count<=1 -> zero offset; base_y < min -> y lifted.
      local state2 = {
        tile_positions = { [4] = based(1.0, 1.0, 1.0) },
        player_units = { [1] = unit_for(1) },
      }
      placed = {}
      placement.place_players(state2, { { id = 1, position = 4 } }, { [4] = { 1 } }, 2.0, 10.0)
      _assert_eq(placed[1].x, 1.0, "single occupant should not be offset on x")
      _assert_eq(placed[1].y, 10.0, "y_offset should lift base up to the floor (1 + 9)")

      -- Zero spacing with multiple occupants: spacing<=0 -> zero offset.
      local state3 = {
        tile_positions = { [5] = based(2.0, 8.0, 2.0) },
        player_units = { [1] = unit_for(1), [2] = unit_for(2) },
      }
      placed = {}
      placement.place_players(state3,
        { { id = 1, position = 5 }, { id = 2, position = 5 } },
        { [5] = { 1, 2 } }, 0.0, 0.0)
      _assert_eq(placed[1].x, 2.0, "zero spacing should collapse offsets to base x")
      _assert_eq(placed[2].x, 2.0, "zero spacing should collapse both occupants to base x")
    end)
    math.Vector3 = saved_vector3
  end)

  it("board placement debug log writes the stop-and-snap line when move-anim debug logging is enabled", function()
    local saved_vector3 = math.Vector3
    function math.Vector3(x, y, z) return { x = x, y = y, z = z } end
    local function based(x, y, z)
      return setmetatable({ x = x, y = y, z = z }, {
        __add = function(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end,
      })
    end

    logger.clear()
    _with_patches({
      { target = runtime_state, key = "set_follow_target_position", value = function() end },
      { target = move_anim, key = "stop_player_presentation", value = function() return { motion_stop_path = "forced" } end },
      { target = debug_flags, key = "move_anim_debug_log_enabled", value = true },
    }, function()
      local state = {
        tile_positions = { [3] = based(0.0, 5.0, 0.0) },
        player_units = { [1] = { set_position = function() end } },
      }
      placement.place_players(state, { { id = 1, position = 3 } }, { [3] = { 1 } }, 2.0, 0.0)
    end)

    local text = logger.get_text()
    assert(string.find(text, "board_refresh_stop_and_snap", 1, true) ~= nil,
      "debug log should record the stop-and-snap event")
    assert(string.find(text, "motion_stop=forced", 1, true) ~= nil,
      "debug log should include the motion stop path")
    math.Vector3 = saved_vector3
  end)

  it("event log view open/close/is_open guard ui, role id, and visibility recording", function()
    local recorded = {}
    local ui = { set_event_log_visible = function(_, value) recorded[#recorded + 1] = value end }
    local state = { ui = ui }

    -- open: records role visibility and drives the host setter to true.
    _assert_eq(event_log_view.open(state, 7), true, "open should record and return true")
    _assert_eq(recorded[1], true, "open should drive the host visibility setter to true")
    _assert_eq(event_log_view.is_open(state, 7), true, "an opened role reads back as open")

    -- close: records false; the role no longer reads as open.
    _assert_eq(event_log_view.close(state, 7), true, "close should record and return true")
    _assert_eq(recorded[2], false, "close should drive the host visibility setter to false")
    _assert_eq(event_log_view.is_open(state, 7), false, "a closed role reads back as not open")

    -- guards: missing state/ui and an un-normalizable role id all short-circuit.
    _assert_eq(event_log_view.open(nil, 7), false, "nil state cannot open")
    _assert_eq(event_log_view.open({}, 7), false, "state without ui cannot open")
    _assert_eq(event_log_view.open(state, nil), false, "an un-normalizable role id cannot open")

    -- ui without the host setter still records visibility and returns true.
    local bare_state = { ui = {} }
    _assert_eq(event_log_view.open(bare_state, 3), true, "open should succeed without a host setter")
    _assert_eq(event_log_view.is_open(bare_state, 3), true, "recorded role reads as open without a setter")

    -- is_open guards a missing visibility table.
    _assert_eq(event_log_view.is_open({ ui = {} }, 9), false, "no visibility table reads as not open")
  end)

  it("overlay compute resolves tile, building, and zero vector positions", function()
    local overlay_compute = require("src.ui.render.anim.overlay_compute")
    local state = {
      board_scene = {
        tiles = {
          [1] = { get_position = function() return math.Vector3(1.0, 2.0, 3.0) end },
          [2] = {},
          [3] = nil,
        },
        buildings = {
          [2] = { get_position = function() return math.Vector3(4.0, 5.0, 6.0) end },
        },
      },
    }

    local tile_pos = overlay_compute.resolve_tile_pos(state, 1)
    _assert_eq(tile_pos.x, 1.0, "tile position should be read from tiles")

    local building_pos = overlay_compute.resolve_tile_pos(state, 2)
    _assert_eq(building_pos.x, 4.0, "building position should be used as fallback")

    local zero_pos = overlay_compute.resolve_tile_pos(state, 3)
    _assert_eq(zero_pos.x, 0.0, "missing tile/building should fall back to zero vector")

    local ok, err = pcall(function() overlay_compute.resolve_tile_pos(nil, 1) end)
    _assert_eq(ok, false, "missing state should assert")
    assert(tostring(err):find("missing state", 1, true), "assert message should mention state")

    ok, err = pcall(function() overlay_compute.resolve_tile_pos(state, nil) end)
    _assert_eq(ok, false, "missing tile_index should assert")
    assert(tostring(err):find("missing tile_index", 1, true), "assert message should mention tile_index")
  end)

  it("contiguous count builds owner count and rent maps", function()
    local contiguous_count = require("src.ui.view.contiguous_count")
    local board = {
      path = {
        { id = 1, type = "land" },
        { id = 2, type = "land" },
        { id = 3, type = "land" },
      },
      tile_lookup = {
        [1] = { type = "land", owner_id = "p1" },
        [2] = { type = "land", owner_id = "p1" },
        [3] = { type = "land", owner_id = "p2" },
      },
      map = {
        neighbors = {
          [1] = { 2 },
          [2] = { 1 },
          [3] = {},
        },
      },
    }
    board.get_tile_by_id = function(_, tile_id)
      return board.tile_lookup[tile_id]
    end

    local counts = contiguous_count.build_for_owner(board, "p1")
    _assert_eq(counts[1], 2, "p1 contiguous count should include connected tile 1")
    _assert_eq(counts[2], 2, "p1 contiguous count should include connected tile 2")
    _assert_eq(counts[3], nil, "p2 tile should not appear in p1 count map")

    local rents = contiguous_count.build_rent_for_owner(board, "p1", function(tile)
      return tile and 10 or 0
    end)
    _assert_eq(rents[1], 20, "p1 rent should sum both connected tiles")
    _assert_eq(rents[2], 20, "p1 rent should be identical across the component")
    _assert_eq(rents[3], nil, "p2 tile should not appear in p1 rent map")

    local empty = contiguous_count.build_for_owner({}, "p1")
    _assert_eq(next(empty), nil, "missing board should return empty table")
    empty = contiguous_count.build_rent_for_owner(board, "p1", nil)
    _assert_eq(next(empty), nil, "non-function rent callback should return empty table")
  end)

  it("board slice projects contiguous counts and rents per owner", function()
    local board_slice = require("src.ui.view.board_slice")
    local game = {
      board = {
        path = {
          { id = 1, type = "land" },
          { id = 2, type = "land" },
        },
        tile_lookup = {
          [1] = { type = "land", owner_id = "p1", level = 0, price = 100 },
          [2] = { type = "land", owner_id = "p1", level = 0, price = 100 },
        },
        map = {
          neighbors = {
            [1] = { 2 },
            [2] = { 1 },
          },
        },
        get_overlays = function() return {} end,
      },
      players = {},
    }
    game.board.get_tile_by_id = function(_, tile_id)
      return game.board.tile_lookup[tile_id]
    end
    local env = { game = game }
    local turn = { phase = "pre_action" }

    local result = board_slice.build(game, env, turn)
    _assert_eq(result.tile_states[1].contiguous_count, 2, "p1 tile 1 should see count 2")
    _assert_eq(result.tile_states[2].contiguous_count, 2, "p1 tile 2 should see count 2")
    _assert_eq(result.tile_states[1].contiguous_rent, 100, "p1 tile 1 should see summed contiguous rent")
    _assert_eq(result.tile_states[2].contiguous_rent, 100, "p1 tile 2 should see summed contiguous rent")

    local game2 = {
      board = {
        path = { { id = 1, type = "land" } },
        tile_lookup = { [1] = { type = "land", owner_id = nil, level = 0 } },
        map = { neighbors = { [1] = {} } },
        get_overlays = function() return {} end,
      },
      players = {},
    }
    game2.board.get_tile_by_id = function(_, tile_id)
      return game2.board.tile_lookup[tile_id]
    end
    local result2 = board_slice.build(game2, { game = game2 }, turn)
    _assert_eq(result2.tile_states[1].contiguous_count, nil, "unowned tile should have nil count")
    _assert_eq(result2.tile_states[1].contiguous_rent, nil, "unowned tile should have nil rent")
  end)

  it("callbacks install sets popup owner on successful push", function()
    local state_callback_ports = require("src.ui.ports.callbacks")
    local modal = require("src.ui.coord.modal")
    local calls = {}
    local state = { ui = {} }
    local game_with_turn = {
      turn = { current_player_index = 3 },
    }

    _with_patches({
      { target = modal, key = "push_popup", value = function(_, s, payload, opts)
        calls[#calls + 1] = { payload = payload, opts = opts }
        return true
      end },
    }, function()
      state_callback_ports.install(state, function() return game_with_turn end)
      local ok = state.push_popup(nil, "hello", {})
      _assert_eq(ok, true, "push_popup should return modal success")
      _assert_eq(state.ui.popup_owner_index, 3, "successful popup should record current player index")
    end)

    local state2 = { ui = {} }
    _with_patches({
      { target = modal, key = "push_popup", value = function() return false end },
    }, function()
      state_callback_ports.install(state2, function() return game_with_turn end)
      local ok = state2.push_popup(nil, "hello", {})
      _assert_eq(ok, false, "push_popup should return modal failure")
      _assert_eq(state2.ui.popup_owner_index, nil, "failed popup should clear owner index")
    end)

    local state3 = {}
    _with_patches({
      { target = modal, key = "push_popup", value = function() return true end },
    }, function()
      state_callback_ports.install(state3, function() return nil end)
      local ok = state3.push_popup(nil, "hello", {})
      _assert_eq(ok, true, "push_popup should succeed even without ui table")
    end)
  end)

  it("item phase auto dispatch animation branches", function()
    local fake_strategy = {
      auto_pre_action = function()
        return nil
      end,
    }
    local fake_intent = {
      dispatch = function(_, pre)
        return pre
      end,
    }
    local fake_dirty = {
      mark = function() end,
      mark_turn = function() end,
    }
    local fake_chain = {
      resolve_after_action_anim = function(args_in, _)
        return args_in.next_state, args_in.next_args
      end,
    }

    local function make_game(anim_state)
      return {
        dirty = { turn = false },
        auto_play_port = { is_auto_player = function() return true end },
        turn = {
          item_phase = {},
          item_phase_active = "",
          action_anim = anim_state,
          move_followup_pending = false,
        },
      }
    end

    local function sequenced_pre(first, second)
      local calls = 0
      return function()
        calls = calls + 1
        if calls == 1 then
          return first
        end
        return second
      end
    end

    local player = { id = "p1" }
    local args = { player = player, next_state = "next", next_args = {} }
    local move_followup_args = { player = player, next_state = "move_followup", next_args = {} }

    _reload_with("src.rules.items.phase", {
      ["src.config.gameplay.timing"] = { item_phase_queue = { "pre_action", "post_action", "custom_phase" } },
      ["src.rules.items.strategy"] = fake_strategy,
      ["src.rules.ports.intent_output"] = fake_intent,
      ["src.state.dirty_tracker"] = fake_dirty,
      ["src.foundation.chain_args"] = fake_chain,
    }, function(reloaded_phase)
      -- pre.after_action_anim table -> wait for action anim and finish phase
      local game = make_game({ kind = "test" })
      fake_strategy.auto_pre_action = function()
        return { after_action_anim = {} }
      end
      local res = reloaded_phase.run({ game = game }, "pre_action", args)
      _assert_eq(res.waiting, true, "after_action_anim should wait")
      _assert_eq(res.wait_action_anim, true, "after_action_anim should set wait flag")

      -- post_action with after_action_anim should not finish the phase
      game = make_game({ kind = "test" })
      fake_strategy.auto_pre_action = function()
        return { after_action_anim = {} }
      end
      res = reloaded_phase.run({ game = game }, "post_action", args)
      _assert_eq(res.waiting, true, "post_action after_action_anim should wait")
      _assert_eq(game.turn.item_phase.post_action, nil, "post_action should not be finished yet")

      -- action_anim present, repeatable phase, pre returns empty then nil -> wait after loop
      game = make_game({ kind = "test" })
      fake_strategy.auto_pre_action = sequenced_pre({}, nil)
      res = reloaded_phase.run({ game = game }, "pre_action", args)
      _assert_eq(res.waiting, true, "repeatable phase with action_anim should wait after loop")

      -- non-repeatable custom phase with action_anim and empty pre -> wait and finish
      game = make_game({ kind = "test" })
      fake_strategy.auto_pre_action = sequenced_pre({}, nil)
      res = reloaded_phase.run({ game = game }, "custom_phase", args)
      _assert_eq(res.waiting, true, "non-repeatable phase with action_anim should wait")
      _assert_eq(game.turn.item_phase.custom_phase.done, true, "non-repeatable phase should be finished")

      -- non-repeatable custom phase without action_anim -> finish and return nil
      game = make_game(nil)
      fake_strategy.auto_pre_action = sequenced_pre({}, nil)
      res = reloaded_phase.run({ game = game }, "custom_phase", args)
      _assert_eq(res, nil, "non-repeatable phase without action_anim should finish and return nil")
      _assert_eq(game.turn.item_phase.custom_phase.done, true, "non-repeatable phase should be finished")

      -- move_followup pending flag is set when after_action_anim resolves to move_followup
      game = make_game({ kind = "test" })
      fake_strategy.auto_pre_action = function()
        return { after_action_anim = {} }
      end
      res = reloaded_phase.run({ game = game }, "pre_action", move_followup_args)
      _assert_eq(res.waiting, true, "move_followup after_action_anim should wait")
      _assert_eq(game.turn.move_followup_pending, true, "move_followup should be marked pending")
    end)
  end)
end)
