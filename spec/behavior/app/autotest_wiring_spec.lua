local support = require("spec.support.shared_support")
local with_patches = support.with_patches
local startup_policy = require("src.app.policy")
local startup_roster = require("src.app.roster")
local gameplay_start = require("src.app.gameplay_start")
local gameplay_loop = require("src.turn.loop")
local presentation_ports = require("src.ui.ports")

-- autotest 接入点的行为规约：policy 的 STARTUP_AUTOTEST 解析、
-- roster 的 auto_all 全员托管、gameplay_start 的 tick_observer 守护缝。
-- 编排器本体见 autotest_runner_spec，端到端见
-- spec/behavior/scenarios/autotest/run_all_profiles_spec.lua。

describe("autotest_wiring", function()
  describe("startup_policy", function()
    it("resolves_autotest_selector_from_global", function()
      local resolved = startup_policy.resolve({
        MONOPOLY_BUILD_MODE = "debug",
        STARTUP_AUTOTEST = "group:combat_obstacle",
      })
      assert.equals("group:combat_obstacle", resolved.autotest)
    end)

    it("defaults_autotest_to_nil_when_global_missing_or_empty", function()
      assert(startup_policy.resolve({}).autotest == nil, "missing global should stay nil")
      assert(startup_policy.resolve({ STARTUP_AUTOTEST = "" }).autotest == nil,
        "empty string should stay nil")
      assert(startup_policy.resolve(nil).autotest == nil, "nil globals should stay nil")
    end)
  end)

  describe("roster.build_game_factory", function()
    local function _build_players(opts)
      local state = { on_game_replaced = function() end }
      local game = startup_roster.build_game_factory(state, opts)()
      return game.players
    end

    it("auto_all_marks_every_player_auto", function()
      for _, player in ipairs(_build_players({
        build_mode = "debug",
        profile_name = "default",
        auto_all = true,
      })) do
        assert(player.auto == true, "auto_all should mark player auto: " .. tostring(player.id))
      end
    end)

    it("default_keeps_primary_player_manual", function()
      local players = _build_players({ build_mode = "debug", profile_name = "default" })
      assert(players[1].auto ~= true, "primary player stays manual without auto_all")
    end)
  end)

  describe("gameplay_start tick guard", function()
    local function _start_with_capture(state)
      local capture = { tick_callback = nil }
      local current_game_ref = {}
      with_patches({
        { target = package.loaded, key = "vendor.third_party.Utils", value = true },
        {
          key = "SetFrameOut",
          value = function(_, cb)
            capture.tick_callback = cb
            return {}
          end,
        },
        {
          target = presentation_ports,
          key = "build",
          value = function()
            return { clock = nil }
          end,
        },
        {
          target = gameplay_loop,
          key = "new_game",
          value = function()
            return { logger = { info = function() end } }
          end,
        },
        { target = gameplay_loop, key = "set_game", value = function() end },
        {
          target = gameplay_loop,
          key = "tick",
          value = function()
            error("tick exploded")
          end,
        },
      }, function()
        gameplay_start.start(state, current_game_ref)
        assert(capture.tick_callback ~= nil, "tick loop should be armed")
        capture.tick_callback()
      end)
      return capture
    end

    it("without_observer_tick_errors_propagate_to_host", function()
      local state = {}
      local ok, err = pcall(_start_with_capture, state)
      assert(ok == false, "unguarded tick error should escape the frame callback")
      assert(tostring(err):find("tick exploded", 1, true) ~= nil, "original error surfaces")
    end)

    it("with_observer_tick_errors_are_captured_not_raised", function()
      local seen = {}
      local state = {
        tick_observer = function(dt, ok, err)
          seen[#seen + 1] = { dt = dt, ok = ok, err = err }
        end,
      }
      _start_with_capture(state)
      assert.equals(1, #seen)
      assert(seen[1].ok == false, "observer should see the failure flag")
      assert(tostring(seen[1].err):find("tick exploded", 1, true) ~= nil,
        "observer should receive the error")
      assert(type(seen[1].dt) == "number", "observer should receive tick seconds")
    end)

    it("exposes_prime_first_turn_for_profile_swaps", function()
      local advanced = 0
      local game = {
        turn = { turn_count = 0, phase = "start", pending_choice = nil },
        advance_turn = function()
          advanced = advanced + 1
        end,
      }
      assert(gameplay_start.prime_first_turn(game) == true, "fresh game should prime")
      assert.equals(1, advanced)

      game.turn.turn_count = 3
      assert(gameplay_start.prime_first_turn(game) == false, "in-flight game must not re-prime")
      assert.equals(1, advanced)
    end)
  end)
end)
