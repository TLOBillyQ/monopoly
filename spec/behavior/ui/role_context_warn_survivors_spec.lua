local function _eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- role_context captures `logger` at require time, so the logger spy must be installed BEFORE
-- requiring the module. Reloading it per run also resets the module-private warn-once table.
local function _with_role_context(body)
  local warn_calls = {}
  local prev_log = package.loaded["src.foundation.log"]
  package.loaded["src.foundation.log"] = {
    warn = function(...) warn_calls[#warn_calls + 1] = { ... } end,
    info = function() end,
    error = function() end,
  }
  package.loaded["src.ui.view.role_context"] = nil
  local role_context = require("src.ui.view.role_context")
  local ok, err = pcall(body, role_context, warn_calls)
  package.loaded["src.foundation.log"] = prev_log
  package.loaded["src.ui.view.role_context"] = nil
  if not ok then error(err) end
end

local function _deps(resolve_fn)
  return { runtime = { resolve_role_id = resolve_fn } }
end

describe("role_context.resolve unmapped warn-once guard survivors", function()
  it("L10: role_id + ui_model present and unseen → warns once (kills ~=→==, not-removal)", function()
    -- role resolves to an id that is NOT in item_slots → unmapped fallback with a fresh warn table.
    _with_role_context(function(role_context, warn_calls)
      local ui_model = { current_player_id = 1, item_slots_by_player_id = {} }
      local ctx = role_context.resolve("roleA", ui_model, _deps(function() return "player_7" end))
      _eq(#warn_calls, 1, "unmapped role with ui_model, first time, must warn exactly once")
      _eq(ctx.can_operate, false, "L20: unmapped context must NOT be operable")
      _eq(ctx.is_player_role, false, "unmapped context is not a player role")
    end)
  end)

  it("L10: ui_model nil suppresses warn even with a role_id (kills and→or)", function()
    -- ui_model nil makes the middle conjunct false; the whole guard must stay false → no warn.
    _with_role_context(function(role_context, warn_calls)
      local ctx = role_context.resolve("roleB", nil, _deps(function() return "player_9" end))
      _eq(#warn_calls, 0, "unmapped role with nil ui_model must NOT warn")
      _eq(ctx.can_operate, false, "L20: unmapped context must NOT be operable")
    end)
  end)

  it("L11: second unmapped resolve of same role_id is suppressed (kills warned=true→false)", function()
    _with_role_context(function(role_context, warn_calls)
      local ui_model = { current_player_id = 1, item_slots_by_player_id = {} }
      role_context.resolve("roleC", ui_model, _deps(function() return "player_3" end))
      role_context.resolve("roleC", ui_model, _deps(function() return "player_3" end))
      _eq(#warn_calls, 1, "same unmapped role_id must warn only once across repeated resolves")
    end)
  end)

  it("L61: role present but role_id nil → unmapped, not self (kills and→or)", function()
    -- role is non-nil while resolve_role_id yields nil: only ONE side of `role_id==nil and role==nil`
    -- is nil, so the self branch must NOT fire; result must be the non-operable unmapped context.
    _with_role_context(function(role_context)
      local ui_model = { current_player_id = 5, item_slots_by_player_id = {} }
      local ctx = role_context.resolve("spectator", ui_model, _deps(function() return nil end))
      _eq(ctx.can_operate, false, "L61: single-nil case must yield unmapped (non-operable), not self")
      _eq(ctx.is_player_role, false, "L61: single-nil case must NOT be treated as the self player role")
      _eq(ctx.role_id, nil, "unmapped role_id here is nil (resolve returned nil)")
    end)
  end)
end)
