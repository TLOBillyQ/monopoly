local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _make_game(overrides)
  overrides = overrides or {}
  return {
    turn = {
      phase = overrides.phase or "wait_choice",
      current_player_index = overrides.current_player_index or 1,
    },
    players = overrides.players or {
      { id = 1, is_ai = false, auto = false },
    },
    find_player_by_id = overrides.find_player_by_id,
  }
end

local function _make_state(overrides)
  overrides = overrides or {}
  return {
    ui = overrides.ui or {},
    ui_runtime = overrides.local_role_id and { local_actor_role_id = overrides.local_role_id } or nil,
  }
end

local function _make_choice(route_key, owner_role_id)
  return {
    id = "choice-" .. tostring(route_key),
    kind = route_key,
    route_key = route_key,
    owner_role_id = owner_role_id,
  }
end

local function _make_role(role_id)
  return {
    get_roleid = function()
      return role_id
    end,
  }
end

describe("choice_ui_state behavior", function()
  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("keeps inline routes open without expecting modal UI", function()
    local game = _make_game()
    local state = _make_state({ local_role_id = 1 })
    local base_gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("base_inline", 1))

    assert.equals(false, base_gate.expects_ui, "base_inline should not expect modal UI")
    assert.equals(true, base_gate.open, "base_inline should be treated as open")
    assert.equals(false, base_gate.should_warn, "base_inline should not warn")

    local passive_gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("item_phase_passive", 1))
    assert.equals(true, passive_gate.expects_ui, "item_phase_passive still belongs to local owner")
    assert.equals(true, passive_gate.open, "item_phase_passive should be treated as open")
    assert.equals(false, choice_ui_state.should_reconcile(game, state, _make_choice("item_phase_passive", 1)),
      "item_phase_passive should not reconcile")
  end)

  it("does not expect choice UI during blocked turn phases", function()
    local game = _make_game({ phase = "wait_move_anim" })
    local state = _make_state({ local_role_id = 1 })
    local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 1))

    assert.equals(false, gate.expects_ui, "animation phase should suppress modal expectation")
    assert.equals(false, gate.should_warn, "blocked phase should not warn about missing UI")
    assert.equals(false, choice_ui_state.should_reconcile(game, state, _make_choice("target", 1)),
      "blocked phase should not reopen modal")
  end)

  it("uses game find_player_by_id when resolving owner automation", function()
    local game = _make_game({
      players = { { id = 2, is_ai = false, auto = false } },
      find_player_by_id = function(_, role_id)
        if role_id == 2 then
          return { id = 2, is_ai = true, auto = false }
        end
        return nil
      end,
    })
    local state = _make_state({ local_role_id = 2 })
    local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 2))

    assert.equals(true, gate.owner_auto, "find_player_by_id should decide owner automation")
    assert.equals(false, gate.expects_ui, "AI owner should not expect local choice UI")
  end)

  it("falls back to players when find_player_by_id is unavailable", function()
    local game = _make_game({
      players = { { id = 2, is_ai = false, auto = true } },
      find_player_by_id = nil,
    })
    local state = _make_state({ local_role_id = 2 })
    local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 2))

    assert.equals(true, gate.owner_auto, "players fallback should resolve owner automation")
    assert.equals(false, gate.expects_ui, "auto owner should not expect modal UI")
  end)

  it("uses the single runtime role as local owner fallback", function()
    runtime_ports.configure({
      resolve_roles = function()
        return { _make_role(3) }
      end,
    })
    local game = _make_game({ players = { { id = 3, is_ai = false, auto = false } } })
    local gate = choice_ui_state.resolve_gate_state(game, _make_state(), _make_choice("target", 3))

    assert.equals(true, gate.local_owner, "single runtime role should be local owner")
    assert.equals(true, gate.expects_ui, "local human owner should expect modal UI")
    assert.equals(true, gate.should_warn, "missing modal should warn when UI is expected")
  end)

  it("handles nil game while preserving explicit owner", function()
    local state = _make_state({ local_role_id = 1 })
    local gate = choice_ui_state.resolve_gate_state(nil, state, _make_choice("target", 1))

    assert.equals(1, gate.owner_role_id, "explicit owner should not require game")
    assert.equals(true, gate.local_owner, "explicit local owner should still resolve")
  end)

  it("does not infer local owner from invalid or missing runtime roles", function()
    runtime_ports.configure({
      resolve_roles = function()
        return function() end
      end,
    })
    local invalid_roles_gate = choice_ui_state.resolve_gate_state(
      _make_game({ players = { { id = 4, is_ai = false, auto = false } } }),
      _make_state(),
      _make_choice("target", 4)
    )

    runtime_ports.configure({
      resolve_roles = function()
        return {}
      end,
    })
    local missing_roles_gate = choice_ui_state.resolve_gate_state(
      _make_game({ players = { { id = 4, is_ai = false, auto = false } } }),
      _make_state(),
      _make_choice("target", 4)
    )

    assert.equals(false, invalid_roles_gate.local_owner, "non-table roles should not be local owner")
    assert.equals(false, invalid_roles_gate.expects_ui, "non-table roles should not expect UI")
    assert.equals(false, missing_roles_gate.local_owner, "empty roles should not be local owner")
    assert.equals(false, missing_roles_gate.expects_ui, "empty roles should not expect UI")
  end)

  it("matches non-market choices against the active screen key", function()
    local game = _make_game()
    local open_state = _make_state({
      local_role_id = 1,
      ui = { choice_active = true, active_choice_screen_key = "target" },
    })
    local wrong_screen_state = _make_state({
      local_role_id = 1,
      ui = { choice_active = true, active_choice_screen_key = "other" },
    })
    local closed_state = _make_state({
      local_role_id = 1,
      ui = { choice_active = false, active_choice_screen_key = "target" },
    })

    assert.equals(true, choice_ui_state.resolve_gate_state(game, open_state, _make_choice("target", 1)).open,
      "matching active screen should be open")
    assert.equals(false, choice_ui_state.should_reconcile(game, open_state, _make_choice("target", 1)),
      "open modal should not reconcile")
    assert.equals(false, choice_ui_state.resolve_gate_state(game, wrong_screen_state, _make_choice("target", 1)).open,
      "wrong active screen should not be open")
    assert.equals(true, choice_ui_state.should_reconcile(game, wrong_screen_state, _make_choice("target", 1)),
      "wrong active screen should reconcile")
    assert.equals(false, choice_ui_state.resolve_gate_state(game, closed_state, _make_choice("target", 1)).open,
      "inactive choice UI should not be open")
  end)

  it("uses current player as owner when choice has no owner", function()
    local game = _make_game({
      current_player_index = 2,
      players = {
        { id = 1, is_ai = false },
        { id = 2, is_ai = false },
      },
    })
    local state = _make_state({ local_role_id = 2 })
    local choice = _make_choice("target", nil)
    local gate = choice_ui_state.resolve_gate_state(game, state, choice)

    assert.equals(2, gate.owner_role_id, "owner should fall back to current player")
    assert.equals(true, gate.local_owner, "current player fallback should be local")
  end)
end)
