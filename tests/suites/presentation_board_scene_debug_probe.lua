local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local probe = require("src.presentation.render.BoardSceneDebugProbe")

local function _test_apply_startup_player_models_success()
  local source_unit = {
    get_unit_type = function()
      return 4
    end,
    is_creature = function()
      return true
    end,
  }

  local calls = {}
  local function _new_player_unit(player_id)
    return {
      set_model_by_creature = function(self, creature, include_custom_model, inherit_scale, inherit_capsule_size)
        calls[#calls + 1] = {
          self_ref = self,
          player_id = player_id,
          creature = creature,
          include_custom_model = include_custom_model,
          inherit_scale = inherit_scale,
          inherit_capsule_size = inherit_capsule_size,
        }
      end,
    }
  end

  _with_patches({
    {
      key = "LuaAPI",
      value = {
        query_unit = function(name)
          if name == "角色形象-海绵宝宝" then
            return source_unit
          end
          return nil
        end,
      },
    },
    { key = "print", value = function() end },
  }, function()
    probe.apply_startup_player_models({
      [1001] = _new_player_unit(1001),
      [1002] = _new_player_unit(1002),
    })
  end)

  _assert_eq(#calls, 2, "both players should receive set_model_by_creature")
  for _, entry in ipairs(calls) do
    _assert_eq(entry.creature, source_unit, "source creature should be forwarded")
    _assert_eq(entry.include_custom_model, true, "include_custom_model should be true")
    _assert_eq(entry.inherit_scale, false, "inherit_scale should be false")
    _assert_eq(entry.inherit_capsule_size, false, "inherit_capsule_size should be false")
  end
end

local function _test_apply_startup_player_models_source_missing_noop()
  local calls = 0

  _with_patches({
    {
      key = "LuaAPI",
      value = {
        query_unit = function()
          return nil
        end,
      },
    },
    { key = "print", value = function() end },
  }, function()
    probe.apply_startup_player_models({
      [1001] = {
        set_model_by_creature = function()
          calls = calls + 1
        end,
      },
    })
  end)

  _assert_eq(calls, 0, "source missing should not call player set_model_by_creature")
end

local function _test_apply_startup_player_models_missing_player_api_isolated()
  local source_unit = {
    get_unit_type = function()
      return 4
    end,
    is_creature = function()
      return true
    end,
  }
  local calls = 0

  _with_patches({
    {
      key = "LuaAPI",
      value = {
        query_unit = function()
          return source_unit
        end,
      },
    },
    { key = "print", value = function() end },
  }, function()
    probe.apply_startup_player_models({
      [1001] = {
        set_model_by_creature = function()
          calls = calls + 1
        end,
      },
      [1002] = {},
    })
  end)

  _assert_eq(calls, 1, "units missing set_model_by_creature should not block others")
end

local function _test_apply_startup_player_models_single_player_error_isolated()
  local source_unit = {
    get_unit_type = function()
      return 4
    end,
    is_creature = function()
      return true
    end,
  }
  local ok = false
  local calls = 0

  _with_patches({
    {
      key = "LuaAPI",
      value = {
        query_unit = function()
          return source_unit
        end,
      },
    },
    { key = "print", value = function() end },
  }, function()
    ok = pcall(function()
      probe.apply_startup_player_models({
        [1001] = {
          set_model_by_creature = function()
            error("boom")
          end,
        },
        [1002] = {
          set_model_by_creature = function()
            calls = calls + 1
          end,
        },
      })
    end)
  end)

  _assert_eq(ok, true, "single player error should not escape apply_startup_player_models")
  _assert_eq(calls, 1, "single player error should not block other players")
end

return {
  name = "presentation_board_scene_debug_probe",
  tests = {
    { name = "apply_startup_player_models_success", run = _test_apply_startup_player_models_success },
    { name = "apply_startup_player_models_source_missing_noop", run = _test_apply_startup_player_models_source_missing_noop },
    {
      name = "apply_startup_player_models_missing_player_api_isolated",
      run = _test_apply_startup_player_models_missing_player_api_isolated,
    },
    {
      name = "apply_startup_player_models_single_player_error_isolated",
      run = _test_apply_startup_player_models_single_player_error_isolated,
    },
  },
}
