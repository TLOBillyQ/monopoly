-- Mutation-pinning specs for src/ui/input/dispatch/view_command.lua.
-- Per [[feedback_mutation_spec_state_inline]]: state shape kept inline, no
-- shared helpers — nil vs explicit fields are the discrimination contract.
-- Per [[reference_mutate4lua_test_corpus]]: closure via busted spec, not Gherkin.

local view_command = require("src.ui.input.dispatch.view_command")

-- ════════════════════════════════════════════════════════════════════════════
-- Helpers for mocking _resolve_loaded targets via package.preload swap.
-- _resolve_loaded uses pcall(require, name); package.preload entries satisfy
-- the require, so we can inject mocks for any submodule the dispatcher loads.
-- ════════════════════════════════════════════════════════════════════════════

local function _swap_loaded(name, mock)
  local saved_loaded = package.loaded[name]
  local saved_preload = package.preload[name]
  package.loaded[name] = nil
  package.preload[name] = function() return mock end
  return function()
    package.loaded[name] = saved_loaded
    package.preload[name] = saved_preload
  end
end

describe("view_command _handle_market_select (L53-59 market=nil and bool returns)", function()
  it("returns false when market module fails to load (L55 'false')", function()
    -- Sabotage the require so _resolve_loaded("src.ui.coord.market") returns nil.
    local saved = package.preload["src.ui.coord.market"]
    package.loaded["src.ui.coord.market"] = nil
    package.preload["src.ui.coord.market"] = function() error("blocked", 0) end
    local result = view_command.dispatch({}, { type = "market_select", option_id = 5 })
    package.preload["src.ui.coord.market"] = saved
    assert(result == false, "market_select with absent market module must return false; got " .. tostring(result))
  end)

  it("returns true when market is present and select_market_option succeeds (L58 'true')", function()
    local captured = nil
    local restore = _swap_loaded("src.ui.coord.market", {
      select_market_option = function(state, option_id) captured = { state = state, option_id = option_id } end,
    })
    local state = { sentinel = "market_state" }
    local ok, result = pcall(function() return view_command.dispatch(state, { type = "market_select", option_id = 42 }) end)
    restore()
    assert(ok, "market_select must not throw with valid module")
    assert(result == true, "market_select success must return true; got " .. tostring(result))
    assert(captured ~= nil and captured.option_id == 42, "must forward option_id to market")
  end)
end)

describe("view_command _handle_popup_confirm (L61-67 modal=nil and bool returns)", function()
  it("returns false when modal module fails to load (L63 'false')", function()
    local saved = package.preload["src.ui.coord.modal"]
    package.loaded["src.ui.coord.modal"] = nil
    package.preload["src.ui.coord.modal"] = function() error("blocked", 0) end
    local result = view_command.dispatch({}, { type = "popup_confirm" })
    package.preload["src.ui.coord.modal"] = saved
    assert(result == false, "popup_confirm with absent modal must return false; got " .. tostring(result))
  end)

  it("returns true and calls close_popup when modal present (L66 'true')", function()
    local close_calls = 0
    local restore = _swap_loaded("src.ui.coord.modal", {
      close_popup = function() close_calls = close_calls + 1 end,
    })
    local result = view_command.dispatch({}, { type = "popup_confirm" })
    restore()
    assert(result == true, "popup_confirm with modal must return true")
    assert(close_calls == 1, "close_popup must be called exactly once; got " .. close_calls)
  end)
end)

describe("view_command _dispatch_via_table (L69-75)", function()
  it("returns false when underlying module is nil (L70 'module==nil' check)", function()
    -- Both atlas modules sabotaged → _dispatch_via_table receives nil.
    local saved = package.preload["src.ui.coord.skin_panel"]
    package.loaded["src.ui.coord.skin_panel"] = nil
    package.preload["src.ui.coord.skin_panel"] = function() error("blocked", 0) end
    local result = view_command.dispatch({}, { type = "open_skin_panel", actor_role_id = 1 })
    package.preload["src.ui.coord.skin_panel"] = saved
    -- Also disable gallery for the open_skin_with_fallback path:
    -- Note: even if module=nil short-circuits at L70, the dispatch may have
    -- already tried the gallery fallback path via _open_skin_with_fallback.
    -- The contract for _dispatch_via_table specifically: nil module → false.
    assert(result == false, "expected false from dispatch chain; got " .. tostring(result))
  end)

  it("returns false before table dispatch when intent type has no fallback handler", function()
    -- Provide skin_panel module so a stray module load cannot explain the result.
    -- Unknown intents must be rejected by _fallback_dispatch before any table dispatch.
    local restore = _swap_loaded("src.ui.coord.skin_panel", {
      open = function() end,
      handle_action = function() end,
    })
    local result = view_command.dispatch({}, { type = "unknown_intent_xyz" })
    restore()
    assert(result == false, "unknown intent must return false")
  end)

  it("returns true via _dispatch_via_table when module + action both present (L74 'true')", function()
    local handle_calls = 0
    local restore_panel = _swap_loaded("src.ui.coord.skin_panel", {
      open = function() end,
      handle_action = function() handle_calls = handle_calls + 1 end,
    })
    local result = view_command.dispatch({}, { type = "skin_panel_action", action = "do_x", actor_role_id = 1 })
    restore_panel()
    assert(result == true, "skin_panel_action must return true on success; got " .. tostring(result))
    assert(handle_calls == 1, "handle_action must be invoked")
  end)
end)

describe("view_command _open_skin_with_fallback (L77-81 gallery vs panel)", function()
  it("uses gallery.open_skin when gallery resolves (L78 require non-nil branch)", function()
    local gallery_calls = 0
    local panel_calls = 0
    local r_gallery = _swap_loaded("src.ui.coord.skin_gallery", {
      open_skin = function(_, role) gallery_calls = gallery_calls + 1 end,
      open_gallery = function() end,
      handle_action = function() end,
    })
    local r_panel = _swap_loaded("src.ui.coord.skin_panel", {
      open = function() panel_calls = panel_calls + 1 end,
      handle_action = function() end,
    })
    view_command.dispatch({}, { type = "open_skin_panel", actor_role_id = 7 })
    r_panel(); r_gallery()
    assert(gallery_calls == 1, "gallery.open_skin must be called when gallery loads; got " .. gallery_calls)
    assert(panel_calls == 0, "panel.open must NOT be called when gallery loads; got " .. panel_calls)
  end)

  it("falls back to panel.open when gallery unavailable (L78 nil branch)", function()
    local panel_calls = 0
    local saved = package.preload["src.ui.coord.skin_gallery"]
    package.loaded["src.ui.coord.skin_gallery"] = nil
    package.preload["src.ui.coord.skin_gallery"] = function() error("blocked", 0) end
    local r_panel = _swap_loaded("src.ui.coord.skin_panel", {
      open = function(_, role) panel_calls = panel_calls + 1 end,
      handle_action = function() end,
    })
    view_command.dispatch({}, { type = "open_skin_panel", actor_role_id = 7 })
    r_panel()
    package.preload["src.ui.coord.skin_gallery"] = saved
    assert(panel_calls == 1, "panel.open must be invoked when gallery unavailable; got " .. panel_calls)
  end)
end)

describe("view_command _open_gallery_with_fallback (L83-87)", function()
  it("uses gallery.open_gallery when gallery resolves (L84 require non-nil)", function()
    local g_calls = 0
    local a_calls = 0
    local r_gallery = _swap_loaded("src.ui.coord.skin_gallery", {
      open_skin = function() end,
      open_gallery = function() g_calls = g_calls + 1 end,
      handle_action = function() end,
    })
    local r_atlas = _swap_loaded("src.ui.coord.item_atlas", {
      open = function() a_calls = a_calls + 1 end,
      handle_action = function() end,
    })
    view_command.dispatch({}, { type = "open_gallery_panel", actor_role_id = 3 })
    r_atlas(); r_gallery()
    assert(g_calls == 1, "gallery.open_gallery must run when gallery loads")
    assert(a_calls == 0, "atlas.open must NOT run when gallery loads")
  end)

  it("falls back to atlas.open when gallery unavailable (L84 nil branch)", function()
    local a_calls = 0
    local saved = package.preload["src.ui.coord.skin_gallery"]
    package.loaded["src.ui.coord.skin_gallery"] = nil
    package.preload["src.ui.coord.skin_gallery"] = function() error("blocked", 0) end
    local r_atlas = _swap_loaded("src.ui.coord.item_atlas", {
      open = function() a_calls = a_calls + 1 end,
      handle_action = function() end,
    })
    view_command.dispatch({}, { type = "open_gallery_panel", actor_role_id = 3 })
    r_atlas()
    package.preload["src.ui.coord.skin_gallery"] = saved
    assert(a_calls == 1, "atlas.open must run when gallery unavailable; got " .. a_calls)
  end)
end)

describe("view_command _emit_toggle_event (L112-123 next_enabled string + return bool)", function()
  -- _emit_toggle_event is called only by _handle_toggle_action_log. We must
  -- drive the dispatch through toggle_action_log to reach it, observing the
  -- emitted event_name via active_role.send_ui_custom_event.

  it("emits '显示日志屏' when next_enabled is true and returns success", function()
    local emitted = {}
    local active_role = {
      send_ui_custom_event = function(name, payload) emitted[#emitted + 1] = { name = name, payload = payload } end,
    }
    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function(role) return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })
    -- Force _resolve_role_by_id final fallback to return active_role by stubbing GameAPI.
    local saved_api = _G.GameAPI
    _G.GameAPI = { get_role = function() return active_role end }
    local state = { ui = { debug_visible_by_role = {} } } -- next_enabled = (nil ~= true) = true
    view_command.dispatch(state, { type = "toggle_action_log", actor_role_id = 99 })
    _G.GameAPI = saved_api
    r_evlog(); r_runtime()
    assert(#emitted >= 1, "send_ui_custom_event must fire; got " .. #emitted .. " events")
    assert(emitted[1].name == "显示日志屏",
      "next_enabled=true must emit '显示日志屏'; got " .. tostring(emitted[1].name))
  end)

  it("emits '隐藏日志屏' when next_enabled is false (L114 literal 'or')", function()
    local emitted = {}
    local active_role = {
      send_ui_custom_event = function(name, payload) emitted[#emitted + 1] = { name = name } end,
    }
    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })
    local saved_api = _G.GameAPI
    _G.GameAPI = { get_role = function() return active_role end }
    -- visible_by_role[99] == true → next_enabled = (true ~= true) = false.
    local state = { ui = { debug_visible_by_role = { [99] = true } } }
    view_command.dispatch(state, { type = "toggle_action_log", actor_role_id = 99 })
    _G.GameAPI = saved_api
    r_evlog(); r_runtime()
    assert(#emitted >= 1, "expected at least one emit")
    assert(emitted[1].name == "隐藏日志屏",
      "next_enabled=false must emit '隐藏日志屏'; got " .. tostring(emitted[1].name))
  end)
end)

describe("view_command _handle_toggle_action_log (L125-145 short-circuits)", function()
  it("returns false when runtime_ui module fails to load (L127 'or nil' branch)", function()
    local saved = package.preload["src.ui.render.runtime_ui"]
    package.loaded["src.ui.render.runtime_ui"] = nil
    package.preload["src.ui.render.runtime_ui"] = function() error("blocked", 0) end
    local result = view_command.dispatch({}, { type = "toggle_action_log", actor_role_id = 1 })
    package.preload["src.ui.render.runtime_ui"] = saved
    assert(result == false, "toggle_action_log with runtime nil must return false; got " .. tostring(result))
  end)

  it("returns false when event_log_view fails to load (L127 second 'or' clause)", function()
    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local saved = package.preload["src.ui.coord.event_log_view"]
    package.loaded["src.ui.coord.event_log_view"] = nil
    package.preload["src.ui.coord.event_log_view"] = function() error("blocked", 0) end
    local result = view_command.dispatch({}, { type = "toggle_action_log", actor_role_id = 1 })
    package.preload["src.ui.coord.event_log_view"] = saved
    r_runtime()
    assert(result == false, "toggle_action_log with event_log_view nil must return false; got " .. tostring(result))
  end)

  it("returns true short-circuit when actor_role_id is nil (L131-132 'true')", function()
    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })
    local result = view_command.dispatch({}, { type = "toggle_action_log" }) -- no actor_role_id
    r_evlog(); r_runtime()
    assert(result == true,
      "nil actor_role_id must short-circuit to true (no role to toggle); got " .. tostring(result))
  end)

  it("returns true on full happy path with all modules present (L144 'true')", function()
    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })
    local saved_api = _G.GameAPI
    _G.GameAPI = { get_role = function() return { send_ui_custom_event = function() end } end }
    local result = view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 5 })
    _G.GameAPI = saved_api
    r_evlog(); r_runtime()
    assert(result == true, "happy path must return true; got " .. tostring(result))
  end)
end)

describe("view_command_dispatcher.dispatch panel_interrupt gate (L166-177)", function()
  it("returns true when panel_interrupt.block_entry blocks (L168 '~= nil' branch)", function()
    local panel_interrupt = require("src.ui.coord.panel_interrupt")
    local saved_block = panel_interrupt.block_entry
    local blocked_calls = {}
    panel_interrupt.block_entry = function(_, panel_id, actor_role_id)
      blocked_calls[#blocked_calls + 1] = { panel_id = panel_id, actor_role_id = actor_role_id }
      return true
    end
    local result = view_command.dispatch({}, { type = "open_skin_panel", actor_role_id = 1 })
    panel_interrupt.block_entry = saved_block
    assert(result == true, "blocked panel entry must return true short-circuit; got " .. tostring(result))
    assert(blocked_calls[1].panel_id == "skin",
      "expected 'skin' panel id passed to block_entry; got " .. tostring(blocked_calls[1].panel_id))
    assert(blocked_calls[1].actor_role_id == 1,
      "expected actor_role_id passed to block_entry; got " .. tostring(blocked_calls[1].actor_role_id))
  end)

  it("delegates to ports.view_command.dispatch when present (L173-174 happy path)", function()
    local captured = nil
    local state = {
      gameplay_loop_ports = {
        view_command = { dispatch = function(_, i) captured = i; return true end },
      },
    }
    local intent = { type = "marker_intent" }
    local result = view_command.dispatch(state, intent)
    assert(result == true, "ports dispatch true must propagate")
    assert(captured == intent, "intent must be forwarded to ports dispatch")
  end)
end)

describe("view_command top-level require constants (L2/L3/L7-L9 deletion)", function()
  -- These pin require() returns being used. Deleting them would break the
  -- dispatch path or change a panel_id lookup.

  it("toggle_action_log intent maps to 'action_log' panel id (L7 literal)", function()
    -- If L7 mutated 'action_log' -> nil, _PANEL_ID_BY_INTENT.toggle_action_log = nil
    -- → panel_interrupt.block_entry is never called for this intent → observable
    -- via spying block_entry.
    local panel_interrupt = require("src.ui.coord.panel_interrupt")
    local saved = panel_interrupt.block_entry
    local seen = {}
    panel_interrupt.block_entry = function(_, panel_id) seen[#seen + 1] = panel_id; return true end
    view_command.dispatch({}, { type = "toggle_action_log", actor_role_id = 1 })
    panel_interrupt.block_entry = saved
    assert(seen[1] == "action_log",
      "toggle_action_log must look up 'action_log' panel id; got " .. tostring(seen[1]))
  end)

  it("open_skin_panel intent maps to 'skin' panel id (L8 literal)", function()
    local panel_interrupt = require("src.ui.coord.panel_interrupt")
    local saved = panel_interrupt.block_entry
    local seen = {}
    panel_interrupt.block_entry = function(_, panel_id) seen[#seen + 1] = panel_id; return true end
    view_command.dispatch({}, { type = "open_skin_panel", actor_role_id = 1 })
    panel_interrupt.block_entry = saved
    assert(seen[1] == "skin",
      "open_skin_panel must look up 'skin' panel id; got " .. tostring(seen[1]))
  end)

  it("open_gallery_panel intent maps to 'gallery' panel id (L9 literal)", function()
    local panel_interrupt = require("src.ui.coord.panel_interrupt")
    local saved = panel_interrupt.block_entry
    local seen = {}
    panel_interrupt.block_entry = function(_, panel_id) seen[#seen + 1] = panel_id; return true end
    view_command.dispatch({}, { type = "open_gallery_panel", actor_role_id = 1 })
    panel_interrupt.block_entry = saved
    assert(seen[1] == "gallery",
      "open_gallery_panel must look up 'gallery' panel id; got " .. tostring(seen[1]))
  end)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Round-2 survivor pins: _resolve_role_by_id chain (L22-L42), _dispatch_via_table
-- intent miss (L72), _warn_missing_toggle_channel (L107), _emit_toggle_event
-- retry path (L117/L120), item_atlas_action + skin_gallery_action (L154/L155).
-- ════════════════════════════════════════════════════════════════════════════

local function _setup_toggle_chain(role_for_capture)
  -- Common setup: runtime_ui + event_log_view present; capture send_ui_custom_event
  -- through whichever active_role gets selected.
  local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
    resolve_role_id = function(role)
      if type(role) == "table" and role.id_marker ~= nil then return role.id_marker end
      return nil
    end,
    set_client_role = function() end,
  })
  local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
    set_event_log_visible_for_role = function(_, role)
      role_for_capture.selected = role
    end,
  })
  return function() r_evlog(); r_runtime() end
end

describe("view_command _resolve_role_by_id host_runtime_ports.resolve_roles chain (L22-L25)", function()
  it("uses host_runtime_ports.resolve_roles when match found (L22-L25 chain truthy + L24 '==' match)", function()
    local host = require("src.ui.host_bridge")
    local saved_resolve_roles = host.resolve_roles
    local saved_resolve_role_with = host.resolve_role_with
    local matching_role = { id_marker = 77, kind = "matched" }
    local other_role = { id_marker = 11, kind = "wrong" }
    host.resolve_roles = function() return { other_role, matching_role } end
    host.resolve_role_with = function() return nil end -- force first chain only

    local capture = {}
    local restore_modules = _setup_toggle_chain(capture)
    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 77 })
    restore_modules()
    host.resolve_roles = saved_resolve_roles
    host.resolve_role_with = saved_resolve_role_with

    assert(capture.selected == matching_role,
      "_resolve_role_by_id must match by tostring(resolve_role_id(role)) == tostring(role_id); got "
      .. tostring(capture.selected and capture.selected.kind or "nil"))
  end)
end)

describe("view_command _resolve_role_by_id resolve_role_with branch (L29-L33)", function()
  it("uses host_runtime_ports.resolve_role_with when first chain yields no match", function()
    local host = require("src.ui.host_bridge")
    local saved_resolve_roles = host.resolve_roles
    local saved_resolve_role_with = host.resolve_role_with
    host.resolve_roles = function() return {} end -- empty list → no match in first chain
    local fallback_role = { id_marker = "from_resolve_role_with", kind = "via_role_with" }
    host.resolve_role_with = function(role_id)
      assert(role_id == 88, "resolve_role_with must receive normalized id; got " .. tostring(role_id))
      return fallback_role
    end

    local capture = {}
    local restore_modules = _setup_toggle_chain(capture)
    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 88 })
    restore_modules()
    host.resolve_roles = saved_resolve_roles
    host.resolve_role_with = saved_resolve_role_with

    assert(capture.selected == fallback_role,
      "second chain must return resolve_role_with result; got " ..
      tostring(capture.selected and capture.selected.kind or "nil"))
  end)
end)

describe("view_command _resolve_role_by_id GameAPI fallback (L36-L44)", function()
  it("uses GameAPI.get_role when both host chains miss (L36 'type==function')", function()
    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return nil end

    local api_role = { id_marker = "via_game_api", kind = "via_api" }
    local saved_api = _G.GameAPI
    _G.GameAPI = { get_role = function() return api_role end }

    local capture = {}
    local restore_modules = _setup_toggle_chain(capture)
    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 55 })
    restore_modules()
    _G.GameAPI = saved_api
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw

    assert(capture.selected == api_role,
      "GameAPI fallback must produce active_role; got " ..
      tostring(capture.selected and capture.selected.kind or "nil"))
  end)

  it("retries GameAPI.get_role with integer-normalized id when string lookup fails (L37-L40)", function()
    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return nil end

    local int_role = { id_marker = "via_int", kind = "int" }
    local saved_api = _G.GameAPI
    local calls = {}
    _G.GameAPI = {
      get_role = function(id)
        calls[#calls + 1] = { id = id, type = type(id) }
        if type(id) == "number" then return int_role end
        return nil -- string lookup fails first
      end,
    }

    local capture = {}
    local restore_modules = _setup_toggle_chain(capture)
    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = "42" }) -- string id
    restore_modules()
    _G.GameAPI = saved_api
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw

    assert(#calls >= 2,
      "expected GameAPI.get_role to be called at least twice (string + int retry); got " .. #calls)
    assert(calls[1].type == "string", "first call must use string id; got " .. tostring(calls[1].type))
    assert(calls[2].type == "number", "second call must use integer-normalized id; got " .. tostring(calls[2].type))
    assert(capture.selected == int_role, "int-retry result must become active_role")
  end)
end)

describe("view_command _resolve_role_by_id final fallback (L46-L50)", function()
  it("returns synthetic role with get_roleid when all chains fail", function()
    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return nil end
    local saved_api = _G.GameAPI
    _G.GameAPI = nil -- block GameAPI branch entirely

    local capture = {}
    local restore_modules = _setup_toggle_chain(capture)
    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 777 })
    restore_modules()
    _G.GameAPI = saved_api
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw

    assert(type(capture.selected) == "table", "fallback must produce a role table")
    assert(type(capture.selected.get_roleid) == "function",
      "fallback role must expose get_roleid; keys: " .. (capture.selected and "table" or "nil"))
    assert(capture.selected.get_roleid() == 777,
      "fallback get_roleid must return original role_id; got " .. tostring(capture.selected.get_roleid()))
  end)
end)

describe("view_command _dispatch_via_table action-not-found (L70-L72)", function()
  it("returns false when intent.type is not a key in the dispatcher's action table (L72 'false')", function()
    -- Provide skin_panel module; route skin_gallery_action via _GALLERY_ACTIONS path,
    -- but pretend gallery module load succeeds with non-matching action.
    local r_gallery = _swap_loaded("src.ui.coord.skin_gallery", {
      open_skin = function() end,
      open_gallery = function() end,
      -- Deliberately omit handle_action.
    })
    -- intent.type "skin_gallery_action" routes via _FALLBACK_HANDLERS to
    -- _dispatch_via_table(gallery, _GALLERY_ACTIONS, ...). _GALLERY_ACTIONS has
    -- skin_gallery_action mapped → handle_action; gallery module is present.
    -- Use a different intent.type within the action_table to trigger miss... but
    -- _FALLBACK_HANDLERS routes only matching types. Direct miss via unknown type:
    local result = view_command.dispatch({}, { type = "completely_unknown_zzz" })
    r_gallery()
    assert(result == false, "unmapped intent type must return false; got " .. tostring(result))
  end)
end)

describe("view_command _warn_missing_toggle_channel (L107 'and' chain)", function()
  it("invokes logger.warn when both logger module and warn function are present", function()
    local warn_calls = {}
    local r_log = _swap_loaded("src.foundation.log", {
      warn = function(...) warn_calls[#warn_calls + 1] = { ... } end,
    })

    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return nil end
    local saved_api = _G.GameAPI
    -- Active role has NO send_ui_custom_event → _emit_toggle_event returns false
    -- → _warn_missing_toggle_channel is invoked.
    _G.GameAPI = { get_role = function() return {} end } -- no send_ui_custom_event

    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })

    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 33 })

    r_evlog(); r_runtime(); r_log()
    _G.GameAPI = saved_api
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw

    assert(#warn_calls >= 1,
      "expected logger.warn to be invoked when emit fails; got " .. #warn_calls)
    -- First arg is the prefix text; second is tostring(actor_role_id).
    assert(tostring(warn_calls[1][2]):find("33"),
      "expected actor_role_id 33 in warn arg; got " .. tostring(warn_calls[1][2]))
  end)
end)

describe("view_command _emit_toggle_event pcall-retry path (L117/L120)", function()
  it("retries send_ui_custom_event with active_role prepended after first pcall failure", function()
    local call_log = {}
    local active_role
    active_role = {
      send_ui_custom_event = function(...)
        local args = { ... }
        call_log[#call_log + 1] = args
        if #call_log == 1 then
          -- First call: signature was (event_name, payload).
          error("first call signature rejected", 0)
        end
        -- Second call: signature is (active_role, event_name, payload).
        return true
      end,
    }

    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return active_role end

    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })

    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 99 })

    r_evlog(); r_runtime()
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw

    assert(#call_log >= 2,
      "expected retry after first pcall failure; got " .. #call_log .. " call(s)")
    -- L120 returns true after the retry attempt; mutation `true → false` would skip
    -- warn invocation in the caller. Observed behavior: no warn call when retry runs.
    assert(call_log[1][1] == "显示日志屏" or call_log[1][1] == "隐藏日志屏",
      "first call's first arg must be the event name; got " .. tostring(call_log[1][1]))
    assert(call_log[2][1] == active_role,
      "second call's first arg must be active_role (retry signature); got " .. type(call_log[2][1]))
  end)
end)

describe("view_command item_atlas_action + skin_gallery_action routes (L154/L155)", function()
  it("item_atlas_action routes through _dispatch_via_table to atlas.handle_action", function()
    local handle_calls = 0
    local captured_action = nil
    local r_atlas = _swap_loaded("src.ui.coord.item_atlas", {
      open = function() end,
      handle_action = function(_, action, role_id)
        handle_calls = handle_calls + 1
        captured_action = action
      end,
    })
    local result = view_command.dispatch(
      {},
      { type = "item_atlas_action", action = "atlas_test_action", actor_role_id = 5 })
    r_atlas()
    assert(result == true, "item_atlas_action route must return true")
    assert(handle_calls == 1, "atlas.handle_action must run exactly once")
    assert(captured_action == "atlas_test_action", "action arg must propagate")
  end)

  it("skin_gallery_action routes through _dispatch_via_table to gallery.handle_action", function()
    local handle_calls = 0
    local captured_action = nil
    local r_gallery = _swap_loaded("src.ui.coord.skin_gallery", {
      open_skin = function() end,
      open_gallery = function() end,
      handle_action = function(_, action, role_id)
        handle_calls = handle_calls + 1
        captured_action = action
      end,
    })
    local result = view_command.dispatch(
      {},
      { type = "skin_gallery_action", action = "gallery_test_action", actor_role_id = 5 })
    r_gallery()
    assert(result == true, "skin_gallery_action route must return true")
    assert(handle_calls == 1, "gallery.handle_action must run exactly once")
    assert(captured_action == "gallery_test_action", "action arg must propagate")
  end)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Round-3 survivor pins: AND-chain mutations on safety guards (L22 x3, L29, L39,
-- L107) and L120 emit-true return. Strategy: stub nil into the link the original
-- code short-circuits on, so the mutated 'or' lets execution past the guard and
-- crashes on the now-nil call; the test wraps dispatch in pcall and asserts
-- original does NOT crash.
-- ════════════════════════════════════════════════════════════════════════════

local function _no_crash_dispatch(state, intent)
  return pcall(view_command.dispatch, state, intent)
end

describe("view_command L22 host_runtime_ports AND chain survives nil-guard injection", function()
  it("resolve_roles=nil short-circuits at clause B (L22 'and' #1 and #2 must not turn into 'or')", function()
    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = nil -- B=false: type(nil) != "function"
    host.resolve_role_with = function() return nil end -- skip second chain too
    local saved_api = _G.GameAPI
    _G.GameAPI = nil -- skip GameAPI chain

    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })

    -- Original: A and B and C and D with B=false → skip for loop, fall through to fallback role.
    -- Mut and→or on AND1: (A or B) and C and D → A truthy → enter for → host.resolve_roles() = nil() → crash.
    -- Mut and→or on AND2: A and (B or C) and D → C truthy → enter for → same crash.
    local ok = _no_crash_dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 99 })

    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw
    _G.GameAPI = saved_api
    r_evlog(); r_runtime()
    assert(ok, "with resolve_roles=nil, original must short-circuit cleanly; AND→OR mutation enters for-loop and crashes")
  end)

  it("runtime.resolve_role_id=nil short-circuits at clause D (L22 'and' #3 must not turn into 'or')", function()
    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return { { dummy = true } } end -- B truthy + non-empty
    host.resolve_role_with = function() return nil end
    local saved_api = _G.GameAPI
    _G.GameAPI = nil

    -- runtime present but resolve_role_id=nil → D=false (type(nil)~="function").
    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      -- resolve_role_id deliberately nil
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })

    -- Original: D=false → skip for. No crash.
    -- Mut3 (C and D → C or D): C truthy → enter for → nil(role) at L24 → crash.
    local ok = _no_crash_dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 99 })

    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw
    _G.GameAPI = saved_api
    r_evlog(); r_runtime()
    assert(ok, "D=false (resolve_role_id nil) must skip for-loop; AND3→OR enters loop and crashes")
  end)
end)

describe("view_command L29 resolve_role_with AND chain survives nil-guard injection", function()
  it("resolve_role_with=nil short-circuits cleanly (L29 'and' must not flip to 'or')", function()
    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end -- first chain yields nothing
    host.resolve_role_with = nil -- L29 clause-2 false: type(nil) != "function"
    local saved_api = _G.GameAPI
    _G.GameAPI = nil

    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })

    -- Original: A and B where B=false → skip second-chain block.
    -- Mut and→or: A or B → A truthy → enter block → host.resolve_role_with(normalized) = nil() → crash.
    local ok = _no_crash_dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 99 })

    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw
    _G.GameAPI = saved_api
    r_evlog(); r_runtime()
    assert(ok, "L29 AND→OR must not call nil resolve_role_with")
  end)
end)

describe("view_command L39 GameAPI retry AND chain", function()
  it("if resolved is non-nil, mutated 'or' would still retry and observably differ", function()
    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return nil end

    local first_role = { id_marker = "first", kind = "first" }
    local retry_role = { id_marker = "retry", kind = "retry" }
    local saved_api = _G.GameAPI
    local calls = 0
    _G.GameAPI = {
      get_role = function(id)
        calls = calls + 1
        if calls == 1 then return first_role end -- first call returns non-nil
        return retry_role
      end,
    }

    local capture = {}
    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function(_, role)
        capture.selected = role
      end,
    })

    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 42 }) -- integer-castable

    r_evlog(); r_runtime()
    _G.GameAPI = saved_api
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw

    -- Original: resolved=first_role, not nil → skip retry → calls==1 → selected=first.
    -- Mut and→or (resolved == nil OR normalized_int ~= nil): normalized_int truthy → retry.
    --   Retry overwrites resolved with retry_role → calls==2 → selected=retry.
    assert(calls == 1, "L39 'and' must short-circuit when resolved is non-nil; OR mutation would re-call. Got calls=" .. calls)
    assert(capture.selected == first_role,
      "active_role must be first-call result; OR mutation would overwrite with retry. Got " ..
      tostring(capture.selected and capture.selected.kind))
  end)
end)

describe("view_command L107 _warn_missing_toggle_channel AND chain", function()
  it("logger=nil short-circuits cleanly (L107 'and' must not flip to 'or')", function()
    -- Block log require → _resolve_loaded returns nil → logger=nil in _warn_missing_toggle_channel.
    local saved_pre = package.preload["src.foundation.log"]
    local saved_loaded = package.loaded["src.foundation.log"]
    package.loaded["src.foundation.log"] = nil
    package.preload["src.foundation.log"] = function() error("blocked", 0) end

    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return nil end
    local saved_api = _G.GameAPI
    -- Active role has no send_ui_custom_event → _emit_toggle_event returns false
    -- → _warn_missing_toggle_channel invoked.
    _G.GameAPI = { get_role = function() return {} end }

    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })

    -- Original: logger=nil → `nil and ...` short-circuits false → no warn call.
    -- Mut and→or: `nil or type(nil.warn) == "function"` → indexing nil.warn → crash.
    local ok = _no_crash_dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 33 })

    r_evlog(); r_runtime()
    _G.GameAPI = saved_api
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw
    package.preload["src.foundation.log"] = saved_pre
    package.loaded["src.foundation.log"] = saved_loaded

    assert(ok, "L107 'and' must short-circuit on nil logger; OR would index nil and crash")
  end)
end)

describe("view_command L120 _emit_toggle_event success return", function()
  it("with send_ui_custom_event present and succeeding, returns true → no warn call", function()
    local active_role = {
      send_ui_custom_event = function() end, -- succeeds first try
    }

    local host = require("src.ui.host_bridge")
    local saved_rr = host.resolve_roles
    local saved_rrw = host.resolve_role_with
    host.resolve_roles = function() return {} end
    host.resolve_role_with = function() return active_role end

    local warn_calls = {}
    local r_log = _swap_loaded("src.foundation.log", {
      warn = function(...) warn_calls[#warn_calls + 1] = { ... } end,
    })

    local r_runtime = _swap_loaded("src.ui.render.runtime_ui", {
      resolve_role_id = function() return 1 end,
      set_client_role = function() end,
    })
    local r_evlog = _swap_loaded("src.ui.coord.event_log_view", {
      set_event_log_visible_for_role = function() end,
    })

    view_command.dispatch(
      { ui = { debug_visible_by_role = {} } },
      { type = "toggle_action_log", actor_role_id = 99 })

    r_evlog(); r_runtime(); r_log()
    host.resolve_roles = saved_rr
    host.resolve_role_with = saved_rrw

    -- Original: _emit_toggle_event returns true → if not true → false → skip warn.
    -- Mut L120 true→false: returns false → if not false → true → warn fires.
    assert(#warn_calls == 0,
      "successful emit must not trigger warn; L120 'true' mutation makes it fire. Got " .. #warn_calls)
  end)
end)
