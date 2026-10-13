require("test.bootstrap").install_package_paths()
local luassert = assert(require("test.support.luassert_loader").load())
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
-- 顶层 after_each → tearDown,断言 assert.equals(e, a) → luassert.is.equal(e, a),
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

    luassert.is.equal(false, base_gate.expects_ui, "base_inline should not expect modal UI")
    luassert.is.equal(true, base_gate.open, "base_inline should be treated as open")
    luassert.is.equal(false, base_gate.should_warn, "base_inline should not warn")

    local passive_gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("item_phase_passive", 1))
    luassert.is.equal(true, passive_gate.expects_ui, "item_phase_passive still belongs to a served owner")
    luassert.is.equal(true, passive_gate.open, "item_phase_passive should be treated as open")
    luassert.is.equal(false, choice_ui_state.should_reconcile(game, state, _make_choice("item_phase_passive", 1)),
      "item_phase_passive should not reconcile")
  end)
end

function TestChoiceState:test_does_not_expect_choice_ui_during_blocked_turn_phases()
  local game = _make_game({ phase = "wait_move_anim" })
  local state = _make_state({ local_role_id = 1 })
  local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 1))

  luassert.is.equal(false, gate.expects_ui, "animation phase should suppress modal expectation")
  luassert.is.equal(false, gate.should_warn, "blocked phase should not warn about missing UI")
  luassert.is.equal(false, choice_ui_state.should_reconcile(game, state, _make_choice("target", 1)),
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

  luassert.is.equal(true, gate.owner_computer_controlled, "the snapshot should decide owner automation")
  luassert.is.equal(false, gate.expects_ui, "AI owner should not expect served choice UI")
end

function TestChoiceState:test_falls_back_to_players_when_find_player_by_id_is_unavailable()
  local game = _make_game({
    players = { _make_player(2, { delegated = true }) },
    find_player_by_id = nil,
  })
  local state = _make_state({ local_role_id = 2 })
  local gate = choice_ui_state.resolve_gate_state(game, state, _make_choice("target", 2))

  luassert.is.equal(true, gate.owner_computer_controlled, "the snapshot fallback should resolve owner automation")
  luassert.is.equal(false, gate.expects_ui, "auto owner should not expect modal UI")
end

function TestChoiceState:test_uses_the_single_runtime_role_as_served_owner_fallback()
  runtime_ports.configure({
    resolve_roles = function()
      return { _make_role(3) }
    end,
  })
  local game = _make_game({ players = { _make_player(3) } })
  local gate = choice_ui_state.resolve_gate_state(game, _make_state(), _make_choice("target", 3))

  luassert.is.equal(true, gate.served_owner, "single runtime role should be served owner")
  luassert.is.equal(true, gate.expects_ui, "served human owner should expect modal UI")
  luassert.is.equal(true, gate.should_warn, "missing modal should warn when UI is expected")
end

function TestChoiceState:test_handles_nil_game_while_preserving_explicit_owner()
  _with_client_and_seats(1, function()
    local state = _make_state()
    local gate = choice_ui_state.resolve_gate_state(nil, state, _make_choice("target", 1))

    luassert.is.equal(1, gate.owner_role_id, "explicit owner should not require game")
    luassert.is.equal(true, gate.served_owner, "explicit served owner should still resolve")
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

  luassert.is.equal(false, invalid_roles_gate.served_owner, "non-table roles should not be served owner")
  luassert.is.equal(false, invalid_roles_gate.expects_ui, "non-table roles should not expect UI")
  luassert.is.equal(false, missing_roles_gate.served_owner, "empty roles should not be served owner")
  luassert.is.equal(false, missing_roles_gate.expects_ui, "empty roles should not expect UI")
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

    luassert.is.equal(true, choice_ui_state.resolve_gate_state(game, open_state, _make_choice("target", 1)).open,
      "matching active screen should be open")
    luassert.is.equal(false, choice_ui_state.should_reconcile(game, open_state, _make_choice("target", 1)),
      "open modal should not reconcile")
    luassert.is.equal(false, choice_ui_state.resolve_gate_state(game, wrong_screen_state, _make_choice("target", 1)).open,
      "wrong active screen should not be open")
    luassert.is.equal(true, choice_ui_state.should_reconcile(game, wrong_screen_state, _make_choice("target", 1)),
      "wrong active screen should reconcile")
    luassert.is.equal(false, choice_ui_state.resolve_gate_state(game, closed_state, _make_choice("target", 1)).open,
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

    luassert.is.equal(2, gate.owner_role_id, "owner should fall back to current player")
    luassert.is.equal(true, gate.served_owner, "current player fallback should be served")
  end)
end


return TestChoiceState
