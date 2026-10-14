require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- 玩家控制模块公开接口契约(#588):控制模式迁移矩阵、派生查询与无副作用边界。
-- 本 spec 全部经公开命令/查询驱动;唯一的例外是「非法控制模式」用例,需要先
-- 手工把内部状态写成损坏值,再验证两条公开命令都保持幂等并返回原因。
local control = require("src.player.control")

local function _player(is_ai)
  local player = { id = 1, name = "P1", is_ai = is_ai == true }
  control.initialize(player)
  return player
end

local function _result(result, changed, enabled, source, reason)
  luassert.is.equal(changed, result.changed, "changed")
  luassert.is.equal(enabled, result.enabled, "enabled")
  luassert.is.equal(source, result.source, "source")
  luassert.is.equal(reason, result.reason, "reason")
end

describe("TestPlayerControl", function()

  it("test_initialize_puts_humans_and_computers_into_direct_control", function()
    local human = _player(false)
    local computer = _player(true)
    luassert.is.equal(false, control.is_delegated(human))
    luassert.is.equal(false, control.is_afk_delegated(human))
    luassert.is.equal(false, control.is_computer_controlled(human))
    luassert.is.equal(false, control.is_delegated(computer))
    luassert.is.equal(false, control.is_afk_delegated(computer))
    luassert.is.equal(true, control.is_computer_controlled(computer))
  end)

  it("test_queries_distinguish_identity_manual_delegation_and_afk_delegation", function()
    local human = _player(false)
    luassert.is.equal(false, control.is_replacement_computer(human))

    _result(control.toggle_manual_delegation(human), true, true, "manual", nil)
    luassert.is.equal(true, control.is_delegated(human))
    luassert.is.equal(false, control.is_afk_delegated(human))
    luassert.is.equal(true, control.is_computer_controlled(human))

    _result(control.toggle_manual_delegation(human), true, false, "manual", nil)
    _result(control.enable_afk_delegation(human), true, true, "afk", nil)
    luassert.is.equal(true, control.is_delegated(human))
    luassert.is.equal(true, control.is_afk_delegated(human))
    luassert.is.equal(true, control.is_computer_controlled(human))

    local computer = _player(true)
    luassert.is.equal(true, control.is_replacement_computer(computer))
    luassert.is.equal(false, control.is_delegated(computer))
    luassert.is.equal(true, control.is_computer_controlled(computer))
  end)

  it("test_manual_toggle_recovers_an_afk_delegated_player_to_direct", function()
    local player = _player(false)
    _result(control.enable_afk_delegation(player), true, true, "afk", nil)
    _result(control.toggle_manual_delegation(player), true, false, "manual", nil)
    luassert.is.equal(false, control.is_delegated(player))
    luassert.is.equal(false, control.is_afk_delegated(player))
    luassert.is.equal(false, control.is_computer_controlled(player))
  end)

  it("test_repeated_manual_toggle_is_not_idempotent_but_stays_reversible", function()
    local player = _player(false)
    _result(control.toggle_manual_delegation(player), true, true, "manual", nil)
    _result(control.toggle_manual_delegation(player), true, false, "manual", nil)
    _result(control.toggle_manual_delegation(player), true, true, "manual", nil)
    luassert.is.equal(true, control.is_delegated(player))
    luassert.is.equal(false, control.is_afk_delegated(player))
  end)

  it("test_repeated_afk_enable_is_idempotent_and_reports_the_reason", function()
    local player = _player(false)
    _result(control.enable_afk_delegation(player), true, true, "afk", nil)
    _result(control.enable_afk_delegation(player), false, true, nil, "already_afk_delegated")
  end)

  it("test_afk_enable_cannot_replace_manual_delegation", function()
    local player = _player(false)
    _result(control.toggle_manual_delegation(player), true, true, "manual", nil)
    _result(control.enable_afk_delegation(player), false, true, nil, "already_manual_delegated")
    luassert.is.equal(false, control.is_afk_delegated(player))
    luassert.is.equal(true, control.is_delegated(player))
  end)

  it("test_manual_command_cannot_turn_a_replacement_computer_into_a_delegated_human", function()
    local player = _player(true)
    _result(control.toggle_manual_delegation(player), false, false, nil, "replacement_computer")
    luassert.is.equal(false, control.is_delegated(player))
    luassert.is.equal(true, control.is_computer_controlled(player))
  end)

  it("test_afk_command_cannot_turn_a_replacement_computer_into_a_delegated_human", function()
    local player = _player(true)
    _result(control.enable_afk_delegation(player), false, false, nil, "replacement_computer")
    luassert.is.equal(false, control.is_delegated(player))
    luassert.is.equal(true, control.is_computer_controlled(player))
  end)

  it("test_missing_player_commands_are_ignored_with_reason", function()
    _result(control.toggle_manual_delegation(nil), false, false, nil, "missing_player")
    _result(control.enable_afk_delegation(nil), false, false, nil, "missing_player")
  end)

  it("test_invalid_control_mode_commands_are_ignored_with_reason", function()
    local player = _player(false)
    player.control_mode = "corrupted"
    _result(control.toggle_manual_delegation(player), false, false, nil, "invalid_control_mode")
    _result(control.enable_afk_delegation(player), false, false, nil, "invalid_control_mode")
    luassert.is.equal(false, control.is_delegated(player))
    luassert.is.equal(false, control.is_computer_controlled(player))
  end)

  it("test_commands_do_not_execute_any_side_effect", function()
    local player = _player(false)
    local before = control.is_delegated(player)
    local result = control.toggle_manual_delegation(player)
    luassert.is.equal(not before, control.is_delegated(player))
    luassert.is_nil(result.game)
    luassert.is_nil(result.share_panel)
    luassert.is_nil(result.broadcast)
  end)

end)
