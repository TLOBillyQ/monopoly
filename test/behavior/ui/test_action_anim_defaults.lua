local lu = require("luaunit")

local function _with_loaded_modules(overrides, fn)
  local previous = {}
  for name, module in pairs(overrides) do
    previous[name] = package.loaded[name]
    package.loaded[name] = module
  end
  package.loaded["src.ui.render.anim.defaults"] = nil
  local ok, err = pcall(fn)
  for name, module in pairs(previous) do
    package.loaded[name] = module
  end
  package.loaded["src.ui.render.anim.defaults"] = nil
  if not ok then
    error(err, 0)
  end
end

TestActionAnimDefaults = {}

function TestActionAnimDefaults:test_does_not_re_register_defaults_when_roll_handler_already_exists()
  local register_count = 0
  local fake_registry = {
    resolve = function(kind)
      if kind == "roll" then
        return function() end
      end
      return nil
    end,
    register = function()
      register_count = register_count + 1
    end,
  }

  _with_loaded_modules({
    ["src.ui.render.anim.registry"] = fake_registry,
  }, function()
    require("src.ui.render.anim.defaults").register()
  end)

  lu.assertIs(register_count, 0)
end

function TestActionAnimDefaults:test_preserves_an_explicit_move_effect_direction_without_requiring_steps()
  local registered = {}
  local captured_anim = nil
  local fake_registry = {
    resolve = function()
      return nil
    end,
    register = function(kind, handler)
      registered[kind] = handler
    end,
  }
  local fake_handlers = {
    clear_overlay = function() end,
    play_move_effect = function(_, anim)
      captured_anim = anim
      return 0
    end,
    play_roll_dice_screen = function() end,
    play_overlay = function() end,
    play_teleport_effect = function() end,
    play_forced_relocation = function() end,
    play_mine_trigger = function() end,
    play_roadblock_trigger = function() end,
    play_missile = function() end,
    play_monster = function() end,
    play_clear_obstacles = function() end,
  }

  _with_loaded_modules({
    ["src.ui.render.anim.registry"] = fake_registry,
    ["src.ui.render.anim.handlers"] = fake_handlers,
  }, function()
    local defaults = require("src.ui.render.anim.defaults")
    defaults.register()
    registered.move_effect({}, { kind = "move_effect", direction = "custom_direction" }, 1.0, {})
  end)

  lu.assertIs(captured_anim.direction, "custom_direction")
end


return TestActionAnimDefaults
