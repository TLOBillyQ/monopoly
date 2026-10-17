-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert

local function _with_loaded_modules(overrides, fn)
  local previous = {}
  local names = {}
  for name, module in pairs(overrides) do
    names[#names + 1] = name
    previous[name] = package.loaded[name]
    package.loaded[name] = module
  end
  package.loaded["src.ui.render.anim.defaults"] = nil
  local ok, err = pcall(fn)
  for _, name in ipairs(names) do
    package.loaded[name] = previous[name]
  end
  package.loaded["src.ui.render.anim.defaults"] = nil
  if not ok then
    error(err, 0)
  end
end

describe("TestActionAnimDefaults", function()

  it("test_does_not_re_register_defaults_when_roll_handler_already_exists", function()
    local existing_roll = function() end
    local resolved = { roll = existing_roll }
    local fake_registry = {
      resolve = function(kind)
        return resolved[kind]
      end,
      register = function(kind, handler)
        resolved[kind] = handler
      end,
    }

    _with_loaded_modules({
      ["src.ui.render.anim.registry"] = fake_registry,
    }, function()
      require("src.ui.render.anim.defaults").register()
    end)

    luassert.is.equal(existing_roll, fake_registry.resolve("roll"))
    local other_default_kinds = {
      "roadblock",
      "mine",
      "move_effect",
      "teleport_effect",
      "forced_relocation",
      "mine_trigger",
      "roadblock_trigger",
      "upgrade_land",
      "cash_receive",
      "missile",
      "monster",
      "clear_obstacles",
    }
    for _, kind in ipairs(other_default_kinds) do
      luassert.is_nil(fake_registry.resolve(kind), "existing roll handler should stop registration of " .. kind)
    end
  end)

  it("test_preserves_an_explicit_move_effect_direction_without_requiring_steps", function()
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

    luassert.is.equal("custom_direction", captured_anim.direction)
  end)


end)
