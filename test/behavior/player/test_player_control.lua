-- 玩家控制模块公开接口契约(#588):控制模式迁移矩阵、派生查询与无副作用边界。
-- 本 spec 全部经公开命令/查询驱动;唯一的例外是「非法控制模式」用例,需要先
-- 手工把内部状态写成损坏值,再验证两条公开命令都保持幂等并返回原因。
local lu = require("luaunit")
local control = require("src.player.control")

local function _player(is_ai)
  local player = { id = 1, name = "P1", is_ai = is_ai == true }
  control.initialize(player)
  return player
end

local function _result(result, changed, enabled, source, reason)
  lu.assertEquals(result.changed, changed, "changed")
  lu.assertEquals(result.enabled, enabled, "enabled")
  lu.assertEquals(result.source, source, "source")
  lu.assertEquals(result.reason, reason, "reason")
end

TestPlayerControl = {}

function TestPlayerControl:test_initialize_puts_humans_and_computers_into_direct_control()
  local human = _player(false)
  local computer = _player(true)
  lu.assertIs(control.is_delegated(human), false)
  lu.assertIs(control.is_afk_delegated(human), false)
  lu.assertIs(control.is_computer_controlled(human), false)
  lu.assertIs(control.is_delegated(computer), false)
  lu.assertIs(control.is_afk_delegated(computer), false)
  lu.assertIs(control.is_computer_controlled(computer), true)
end

function TestPlayerControl:test_queries_distinguish_identity_manual_delegation_and_afk_delegation()
  local human = _player(false)
  lu.assertIs(control.is_replacement_computer(human), false)

  _result(control.toggle_manual_delegation(human), true, true, "manual", nil)
  lu.assertIs(control.is_delegated(human), true)
  lu.assertIs(control.is_afk_delegated(human), false)
  lu.assertIs(control.is_computer_controlled(human), true)

  _result(control.toggle_manual_delegation(human), true, false, "manual", nil)
  _result(control.enable_afk_delegation(human), true, true, "afk", nil)
  lu.assertIs(control.is_delegated(human), true)
  lu.assertIs(control.is_afk_delegated(human), true)
  lu.assertIs(control.is_computer_controlled(human), true)

  local computer = _player(true)
  lu.assertIs(control.is_replacement_computer(computer), true)
  lu.assertIs(control.is_delegated(computer), false)
  lu.assertIs(control.is_computer_controlled(computer), true)
end

function TestPlayerControl:test_manual_toggle_recovers_an_afk_delegated_player_to_direct()
  local player = _player(false)
  _result(control.enable_afk_delegation(player), true, true, "afk", nil)
  _result(control.toggle_manual_delegation(player), true, false, "manual", nil)
  lu.assertIs(control.is_delegated(player), false)
  lu.assertIs(control.is_afk_delegated(player), false)
  lu.assertIs(control.is_computer_controlled(player), false)
end

function TestPlayerControl:test_repeated_manual_toggle_is_not_idempotent_but_stays_reversible()
  local player = _player(false)
  _result(control.toggle_manual_delegation(player), true, true, "manual", nil)
  _result(control.toggle_manual_delegation(player), true, false, "manual", nil)
  _result(control.toggle_manual_delegation(player), true, true, "manual", nil)
  lu.assertIs(control.is_delegated(player), true)
  lu.assertIs(control.is_afk_delegated(player), false)
end

function TestPlayerControl:test_repeated_afk_enable_is_idempotent_and_reports_the_reason()
  local player = _player(false)
  _result(control.enable_afk_delegation(player), true, true, "afk", nil)
  _result(control.enable_afk_delegation(player), false, true, nil, "already_afk_delegated")
end

function TestPlayerControl:test_afk_enable_cannot_replace_manual_delegation()
  local player = _player(false)
  _result(control.toggle_manual_delegation(player), true, true, "manual", nil)
  _result(control.enable_afk_delegation(player), false, true, nil, "already_manual_delegated")
  lu.assertIs(control.is_afk_delegated(player), false)
  lu.assertIs(control.is_delegated(player), true)
end

function TestPlayerControl:test_manual_command_cannot_turn_a_replacement_computer_into_a_delegated_human()
  local player = _player(true)
  _result(control.toggle_manual_delegation(player), false, false, nil, "replacement_computer")
  lu.assertIs(control.is_delegated(player), false)
  lu.assertIs(control.is_computer_controlled(player), true)
end

function TestPlayerControl:test_afk_command_cannot_turn_a_replacement_computer_into_a_delegated_human()
  local player = _player(true)
  _result(control.enable_afk_delegation(player), false, false, nil, "replacement_computer")
  lu.assertIs(control.is_delegated(player), false)
  lu.assertIs(control.is_computer_controlled(player), true)
end

function TestPlayerControl:test_missing_player_commands_are_ignored_with_reason()
  _result(control.toggle_manual_delegation(nil), false, false, nil, "missing_player")
  _result(control.enable_afk_delegation(nil), false, false, nil, "missing_player")
end

function TestPlayerControl:test_invalid_control_mode_commands_are_ignored_with_reason()
  local player = _player(false)
  player.control_mode = "corrupted"
  _result(control.toggle_manual_delegation(player), false, false, nil, "invalid_control_mode")
  _result(control.enable_afk_delegation(player), false, false, nil, "invalid_control_mode")
  lu.assertIs(control.is_delegated(player), false)
  lu.assertIs(control.is_computer_controlled(player), false)
end

function TestPlayerControl:test_commands_do_not_execute_any_side_effect()
  local player = _player(false)
  local before = control.is_delegated(player)
  local result = control.toggle_manual_delegation(player)
  lu.assertEquals(control.is_delegated(player), not before)
  lu.assertIsNil(result.game)
  lu.assertIsNil(result.share_panel)
  lu.assertIsNil(result.broadcast)
end

return TestPlayerControl
