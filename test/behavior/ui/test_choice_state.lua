local lu = require("luaunit")
local support = require("test.support.shared_support")
local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local control = require("src.player.control")
local player_control_snapshot = require("src.turn.output.player_control_snapshot")

local function _make_player(id, opts)
  opts = opts or {}
  local player = { id = id, is_ai = opts.is_ai == true }
  control.initialize(player)
  if opts.delegated == true then
    control.toggle_manual_delegation(player)
  end
  return player
end

local function _make_game(overrides)
  overrides = overrides or {}
  local game = {
    turn = {
      phase = overrides.phase or "wait_choice",
      current_player_index = overrides.current_player_index or 1,
    },
    players = overrides.players or {
      _make_player(1),
    },
    find_player_by_id = overrides.find_player_by_id,
  }
  player_control_snapshot.install(game)
  return game
end

local function _make_state(overrides)
  overrides = overrides or {}
  return {
    ui = overrides.ui or {},
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

-- client_role 与席位名册(#341 后,#444 收敛):门控判定改走 resolve_roles 房间席位名册,
-- client_role 只在渲染作用域内表达「这块屏幕是谁」、不再参与判定。这里把
-- 单人房(名册只坐 role_id)与 client_role 一并铺好,fn 在该窗口内执行。
-- 单字段 patch 而非 runtime_ports.configure:configure 是整表替换
-- (runtime_ports.lua:25),会连带清空 rng_next_int / schedule 等同表端口。
local function _with_client_and_seats(role_id, fn)
  return support.with_patches({
    {
      target = runtime_ui,
      key = "get_client_role",
      value = function()
        return _make_role(role_id)
      end,
    },
    {
      target = runtime_ports,
      key = "resolve_roles",
      value = function()
        return { _make_role(role_id) }
      end,
    },
  }, fn)
end

-- 原生 LuaUnit 迁移(busted → LuaUnit):describe 拍平为 TestChoiceState,
-- 顶层 after_each → tearDown,断言 assert.equals(e, a) → lu.assertIs(a, e),
-- 用例数与改写前一一对应(9 例)。

TestChoiceState = {}

function TestChoiceState:tearDown()
  runtime_ports.reset_for_tests()
  -- 上面的 reset 把共享端口基线拆到未配置态,必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)。
  support.restore_runtime_services()
end

function TestChoiceState:test_keeps_inline_routes_open_without_expecting_modal_ui()
  _with_client_and_seats(1, function()
    local game = _make_game()
    local state = _make_state()
    local base_gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("base_inline", 1))

    lu.assertIs(base_gate.expects_ui, false, "base_inline should not expect modal UI")
    lu.assertIs(base_gate.open, true, "base_inline should be treated as open")
    lu.assertIs(base_gate.should_warn, false, "base_inline should not warn")

    local passive_gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("item_phase_passive", 1))
    lu.assertIs(passive_gate.expects_ui, true, "item_phase_passive still belongs to a served owner")
    lu.assertIs(passive_gate.open, true, "item_phase_passive should be treated as open")
    lu.assertIs(choice_ui_state.should_reconcile(game, state, _make_choice("item_phase_passive", 1)), false,
      "item_phase_passive should not reconcile")
  end)
end

function TestChoiceState:test_does_not_expect_choice_ui_during_blocked_turn_phases()
  local game = _make_game({ phase = "wait_move_anim" })
  local state = _make_state({ local_role_id = 1 })
  local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 1))

  lu.assertIs(gate.expects_ui, false, "animation phase should suppress modal expectation")
  lu.assertIs(gate.should_warn, false, "blocked phase should not warn about missing UI")
  lu.assertIs(choice_ui_state.should_reconcile(game, state, _make_choice("target", 1)), false,
    "blocked phase should not reopen modal")
end

function TestChoiceState:test_resolves_owner_automation_from_the_player_control_snapshot()
  local game = _make_game({
    players = { _make_player(2, { is_ai = true }) },
    find_player_by_id = function(_, role_id)
      if role_id == 2 then
        return _make_player(2, { is_ai = false })
      end
      return nil
    end,
  })
  local state = _make_state({ local_role_id = 2 })
  local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 2))

  lu.assertIs(gate.owner_computer_controlled, true, "the snapshot should decide owner automation")
  lu.assertIs(gate.expects_ui, false, "AI owner should not expect served choice UI")
end

function TestChoiceState:test_falls_back_to_players_when_find_player_by_id_is_unavailable()
  local game = _make_game({
    players = { _make_player(2, { delegated = true }) },
    find_player_by_id = nil,
  })
  local state = _make_state({ local_role_id = 2 })
  local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 2))

  lu.assertIs(gate.owner_computer_controlled, true, "the snapshot fallback should resolve owner automation")
  lu.assertIs(gate.expects_ui, false, "auto owner should not expect modal UI")
end

function TestChoiceState:test_uses_the_single_runtime_role_as_served_owner_fallback()
  runtime_ports.configure({
    resolve_roles = function()
      return { _make_role(3) }
    end,
  })
  local game = _make_game({ players = { _make_player(3) } })
  local gate = choice_ui_state.resolve_gate_state(game, _make_state(), _make_choice("target", 3))

  lu.assertIs(gate.served_owner, true, "single runtime role should be served owner")
  lu.assertIs(gate.expects_ui, true, "served human owner should expect modal UI")
  lu.assertIs(gate.should_warn, true, "missing modal should warn when UI is expected")
end

function TestChoiceState:test_handles_nil_game_while_preserving_explicit_owner()
  _with_client_and_seats(1, function()
    local state = _make_state()
    local gate = choice_ui_state.resolve_gate_state(nil, state, _make_choice("target", 1))

    lu.assertIs(gate.owner_role_id, 1, "explicit owner should not require game")
    lu.assertIs(gate.served_owner, true, "explicit served owner should still resolve")
  end)
end

function TestChoiceState:test_does_not_infer_served_owner_from_invalid_or_missing_runtime_roles()
  runtime_ports.configure({
    resolve_roles = function()
      return function() end
    end,
  })
  local invalid_roles_gate = choice_ui_state.resolve_gate_state(
    _make_game({ players = { _make_player(4) } }),
    _make_state(),
    _make_choice("target", 4)
  )

  runtime_ports.configure({
    resolve_roles = function()
      return {}
    end,
  })
  local missing_roles_gate = choice_ui_state.resolve_gate_state(
    _make_game({ players = { _make_player(4) } }),
    _make_state(),
    _make_choice("target", 4)
  )

  lu.assertIs(invalid_roles_gate.served_owner, false, "non-table roles should not be served owner")
  lu.assertIs(invalid_roles_gate.expects_ui, false, "non-table roles should not expect UI")
  lu.assertIs(missing_roles_gate.served_owner, false, "empty roles should not be served owner")
  lu.assertIs(missing_roles_gate.expects_ui, false, "empty roles should not expect UI")
end

function TestChoiceState:test_matches_non_market_choices_against_the_active_screen_key()
  _with_client_and_seats(1, function()
    local game = _make_game()
    local open_state = _make_state({
      ui = { choice_active = true, active_choice_screen_key = "target" },
    })
    local wrong_screen_state = _make_state({
      ui = { choice_active = true, active_choice_screen_key = "other" },
    })
    local closed_state = _make_state({
      ui = { choice_active = false, active_choice_screen_key = "target" },
    })

    lu.assertIs(choice_ui_state.resolve_gate_state(game, open_state, _make_choice("target", 1)).open, true,
      "matching active screen should be open")
    lu.assertIs(choice_ui_state.should_reconcile(game, open_state, _make_choice("target", 1)), false,
      "open modal should not reconcile")
    lu.assertIs(choice_ui_state.resolve_gate_state(game, wrong_screen_state, _make_choice("target", 1)).open, false,
      "wrong active screen should not be open")
    lu.assertIs(choice_ui_state.should_reconcile(game, wrong_screen_state, _make_choice("target", 1)), true,
      "wrong active screen should reconcile")
    lu.assertIs(choice_ui_state.resolve_gate_state(game, closed_state, _make_choice("target", 1)).open, false,
      "inactive choice UI should not be open")
  end)
end

function TestChoiceState:test_uses_current_player_as_owner_when_choice_has_no_owner()
  _with_client_and_seats(2, function()
    local game = _make_game({
      current_player_index = 2,
      players = {
        _make_player(1),
        _make_player(2),
      },
    })
    local state = _make_state()
    local choice = _make_choice("target", nil)
    local gate = choice_ui_state.resolve_gate_state(game, state, choice)

    lu.assertIs(gate.owner_role_id, 2, "owner should fall back to current player")
    lu.assertIs(gate.served_owner, true, "current player fallback should be served")
  end)
end


return TestChoiceState
