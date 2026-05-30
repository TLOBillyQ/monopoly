local function _force_reload_alias()
  package.loaded["src.ui.render.move_anim.debug"] = nil
  return require("src.ui.render.move_anim.debug")
end

local move_anim_debug = require("src.foundation.move_anim_debug")

describe("ui.render.move_anim.debug alias", function()
  it("re-exports enabled as the foundation function reference", function()
    local debug_mod = _force_reload_alias()
    assert(debug_mod.enabled == move_anim_debug.enabled,
      "debug_mod.enabled should be the same function value as move_anim_debug.enabled")
  end)

  it("re-exports debug_log as the foundation log function reference", function()
    local debug_mod = _force_reload_alias()
    assert(debug_mod.debug_log == move_anim_debug.log,
      "debug_mod.debug_log should be the same function value as move_anim_debug.log")
  end)

  it("exposes exactly enabled and debug_log fields", function()
    local debug_mod = _force_reload_alias()
    local keys = {}
    for k in pairs(debug_mod) do keys[#keys + 1] = k end
    table.sort(keys)
    assert(#keys == 2, "expected 2 keys, got " .. tostring(#keys) .. ": " .. table.concat(keys, ","))
    assert(keys[1] == "debug_log", "expected key debug_log first, got " .. tostring(keys[1]))
    assert(keys[2] == "enabled", "expected key enabled second, got " .. tostring(keys[2]))
  end)
end)
