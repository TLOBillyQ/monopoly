-- Mutation-pinning specs for src/ui/input/view_command.lua, plus the
-- before-game terminal branch of src/ui/input/intent_dispatcher.lua.
-- The dispatcher is a thin adapter: panel_interrupt gate → ports.view_command.
-- Per [[feedback_mutation_spec_state_inline]]: state shape kept inline, no
-- shared helpers — nil vs explicit fields are the discrimination contract.

local view_command = require("src.ui.input.view_command")
local intent_dispatcher = require("src.ui.input.intent_dispatcher")
local game_action_dispatcher = require("src.ui.input.game_action")
local panel_interrupt = require("src.ui.coord.panel_interrupt")
local logger = require("src.foundation.log")

local function _with_block_entry(stub, body)
  local saved = panel_interrupt.block_entry
  panel_interrupt.block_entry = stub
  local ok, err = pcall(body)
  panel_interrupt.block_entry = saved
  assert(ok, err)
end

local function _with_warn_capture(body)
  local warn_calls = {}
  local saved = logger.warn
  logger.warn = function(...) warn_calls[#warn_calls + 1] = { ... } end
  local ok, err = pcall(body, warn_calls)
  logger.warn = saved
  assert(ok, err)
  return warn_calls
end

local function _ports_state(dispatch_fn)
  return {
    gameplay_loop_ports = {
      view_command = { dispatch = dispatch_fn },
    },
  }
end

describe("view_command panel_interrupt gate", function()
  it("returns true short-circuit when block_entry blocks, without touching ports", function()
    local blocked_calls = {}
    local port_calls = 0
    local state = _ports_state(function() port_calls = port_calls + 1; return true end)
    local result
    _with_block_entry(function(_, panel_id, actor_role_id)
      blocked_calls[#blocked_calls + 1] = { panel_id = panel_id, actor_role_id = actor_role_id }
      return true
    end, function()
      result = view_command.dispatch(state, { type = "open_skin_panel", actor_role_id = 1 })
    end)
    assert(result == true, "blocked panel entry must return true short-circuit; got " .. tostring(result))
    assert(port_calls == 0, "blocked entry must not reach ports dispatch; got " .. port_calls)
    assert(blocked_calls[1].panel_id == "skin",
      "expected 'skin' panel id passed to block_entry; got " .. tostring(blocked_calls[1].panel_id))
    assert(blocked_calls[1].actor_role_id == 1,
      "expected actor_role_id passed to block_entry; got " .. tostring(blocked_calls[1].actor_role_id))
  end)

  it("proceeds to ports when block_entry returns false", function()
    local port_calls = 0
    local state = _ports_state(function() port_calls = port_calls + 1; return true end)
    local result
    _with_block_entry(function() return false end, function()
      result = view_command.dispatch(state, { type = "open_skin_panel", actor_role_id = 1 })
    end)
    assert(result == true, "unblocked entry must delegate to ports; got " .. tostring(result))
    assert(port_calls == 1, "ports dispatch must run when entry is not blocked; got " .. port_calls)
  end)

  it("treats truthy-but-not-true block_entry result as not blocked ('== true' pin)", function()
    local port_calls = 0
    local state = _ports_state(function() port_calls = port_calls + 1; return true end)
    _with_block_entry(function() return 1 end, function()
      view_command.dispatch(state, { type = "open_skin_panel", actor_role_id = 1 })
    end)
    assert(port_calls == 1, "block_entry returning non-true must not block; got " .. port_calls .. " port call(s)")
  end)

  it("never consults block_entry for intents without a panel id", function()
    local block_calls = 0
    local port_calls = 0
    local state = _ports_state(function() port_calls = port_calls + 1; return true end)
    local result
    _with_block_entry(function() block_calls = block_calls + 1; return true end, function()
      result = view_command.dispatch(state, { type = "market_select", option_id = 3 })
    end)
    assert(block_calls == 0, "market_select has no panel id → gate must be skipped; got " .. block_calls)
    assert(result == true, "gate skip must still delegate to ports; got " .. tostring(result))
    assert(port_calls == 1, "ports dispatch must run for panel-less intents; got " .. port_calls)
  end)
end)

describe("view_command panel id literals", function()
  local function _seen_panel_id(intent)
    local seen = {}
    _with_block_entry(function(_, panel_id) seen[#seen + 1] = panel_id; return true end, function()
      view_command.dispatch({}, intent)
    end)
    return seen[1]
  end

  it("toggle_action_log intent maps to 'action_log' panel id", function()
    local seen = _seen_panel_id({ type = "toggle_action_log", actor_role_id = 1 })
    assert(seen == "action_log",
      "toggle_action_log must look up 'action_log' panel id; got " .. tostring(seen))
  end)

  it("open_skin_panel intent maps to 'skin' panel id", function()
    local seen = _seen_panel_id({ type = "open_skin_panel", actor_role_id = 1 })
    assert(seen == "skin",
      "open_skin_panel must look up 'skin' panel id; got " .. tostring(seen))
  end)

  it("open_gallery_panel intent maps to 'gallery' panel id", function()
    local seen = _seen_panel_id({ type = "open_gallery_panel", actor_role_id = 1 })
    assert(seen == "gallery",
      "open_gallery_panel must look up 'gallery' panel id; got " .. tostring(seen))
  end)
end)

describe("view_command ports delegation", function()
  it("forwards state and intent to ports.view_command.dispatch and propagates true", function()
    local captured = nil
    local state
    state = _ports_state(function(s, i) captured = { state = s, intent = i }; return true end)
    local intent = { type = "marker_intent" }
    local warn_calls = _with_warn_capture(function()
      local result = view_command.dispatch(state, intent)
      assert(result == true, "ports dispatch true must propagate; got " .. tostring(result))
    end)
    assert(captured.state == state, "state must be forwarded to ports dispatch")
    assert(captured.intent == intent, "intent must be forwarded to ports dispatch")
    assert(#warn_calls == 0, "healthy port dispatch must not warn; got " .. #warn_calls)
  end)

  it("returns false when ports dispatch returns false", function()
    local result = view_command.dispatch(_ports_state(function() return false end), { type = "x" })
    assert(result == false, "ports false must propagate as false; got " .. tostring(result))
  end)

  it("returns false when ports dispatch returns nil ('== true' coercion pin)", function()
    local result = view_command.dispatch(_ports_state(function() return nil end), { type = "x" })
    assert(result == false, "ports nil must coerce to false; got " .. tostring(result))
  end)

  it("returns false when ports dispatch returns truthy non-true ('== true' coercion pin)", function()
    local result = view_command.dispatch(_ports_state(function() return 1 end), { type = "x" })
    assert(result == false, "ports truthy non-true must coerce to false; got " .. tostring(result))
  end)
end)

describe("view_command missing-port warn path", function()
  it("warns with the intent type and returns false when state carries no ports", function()
    local result
    local warn_calls = _with_warn_capture(function()
      result = view_command.dispatch({}, { type = "popup_confirm" })
    end)
    assert(result == false, "missing port must return false; got " .. tostring(result))
    assert(#warn_calls == 1, "missing port must warn exactly once; got " .. #warn_calls)
    local found = false
    for _, arg in ipairs(warn_calls[1]) do
      if tostring(arg):find("popup_confirm", 1, true) then found = true end
    end
    assert(found, "warn must carry intent.type 'popup_confirm' for diagnostics")
  end)

  it("warns and returns false when ports table lacks view_command", function()
    local result
    local warn_calls = _with_warn_capture(function()
      result = view_command.dispatch({ gameplay_loop_ports = {} }, { type = "market_select" })
    end)
    assert(result == false, "ports without view_command must return false; got " .. tostring(result))
    assert(#warn_calls == 1, "expected exactly one warn; got " .. #warn_calls)
  end)

  it("warns and returns false when port dispatch is not a function", function()
    local state = {
      gameplay_loop_ports = {
        view_command = { dispatch = "not_callable" },
      },
    }
    local result
    local warn_calls = _with_warn_capture(function()
      result = view_command.dispatch(state, { type = "toggle_action_log", actor_role_id = 1 })
    end)
    assert(result == false, "malformed port dispatch must return false; got " .. tostring(result))
    assert(#warn_calls == 1, "malformed port must warn exactly once; got " .. #warn_calls)
  end)

  it("survives nil state without crashing and returns false", function()
    local result
    local warn_calls = _with_warn_capture(function()
      result = view_command.dispatch(nil, { type = "market_select" })
    end)
    assert(result == false, "nil state must return false; got " .. tostring(result))
    assert(#warn_calls == 1, "nil state must warn once; got " .. #warn_calls)
  end)

  it("survives nil intent without crashing and returns false", function()
    local result
    local warn_calls = _with_warn_capture(function()
      result = view_command.dispatch({}, nil)
    end)
    assert(result == false, "nil intent must return false; got " .. tostring(result))
    assert(#warn_calls == 1, "nil intent must still warn once; got " .. #warn_calls)
  end)
end)

describe("intent_dispatcher before-game view command terminal branch", function()
  local function _with_game_action_capture(body)
    local game_action_calls = 0
    local saved = game_action_dispatcher.dispatch
    game_action_dispatcher.dispatch = function() game_action_calls = game_action_calls + 1; return true end
    local ok, err = pcall(body)
    game_action_dispatcher.dispatch = saved
    assert(ok, err)
    return game_action_calls
  end

  it("consumes a before-game intent on missing port: exactly one warn, no game-path fallthrough", function()
    local warn_calls
    local game_action_calls = _with_game_action_capture(function()
      warn_calls = _with_warn_capture(function()
        _with_block_entry(function() return false end, function()
          intent_dispatcher.dispatch({}, nil, { type = "open_skin_panel", actor_role_id = 1 })
        end)
      end)
    end)
    assert(#warn_calls == 1, "missing port via intent_dispatcher must warn exactly once; got " .. #warn_calls)
    local message = tostring(warn_calls[1][1])
    assert(message:find("view_command port missing", 1, true) ~= nil,
      "the single warn must be the port-missing diagnostic, not 'ui intent without game'; got " .. message)
    assert(game_action_calls == 0,
      "before-game view command must never fall through to game action; got " .. game_action_calls)
  end)

  it("stays terminal even when the port dispatch returns false (no second dispatch)", function()
    local port_calls = 0
    local state = _ports_state(function() port_calls = port_calls + 1; return false end)
    local game_action_calls = _with_game_action_capture(function()
      _with_block_entry(function() return false end, function()
        intent_dispatcher.dispatch(state, {}, { type = "open_skin_panel", actor_role_id = 1 })
      end)
    end)
    assert(port_calls == 1, "port dispatch must run exactly once; got " .. port_calls)
    assert(game_action_calls == 0,
      "port returning false must not re-enter the game/view fallthrough path; got " .. game_action_calls)
  end)

  it("still routes non-before-game view commands through the game-first path", function()
    local port_calls = 0
    local state = _ports_state(function() port_calls = port_calls + 1; return true end)
    local game_action_calls = _with_game_action_capture(function()
      _with_block_entry(function() return false end, function()
        intent_dispatcher.dispatch(state, {}, { type = "market_select", option_id = 1 })
      end)
    end)
    assert(game_action_calls == 1, "market_select must hit the game action path first; got " .. game_action_calls)
    assert(port_calls == 0, "game action consuming the intent must skip the trailing view dispatch; got " .. port_calls)
  end)
end)
