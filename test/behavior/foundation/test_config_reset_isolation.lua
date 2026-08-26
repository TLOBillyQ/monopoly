local lu = require("luaunit")
local constants = require("src.config.content.constants")

-- 原生 LuaUnit 迁移:describe 带 before_each → setUp(无 after_each),describe 级
-- local _config_reset 提升为文件级,用例数与改写前一一对应(2 例)。
local _config_reset = require("test.support.config_reset")

TestConfigResetIsolation = {}

function TestConfigResetIsolation:setUp()
  _config_reset.reset_all()
end

function TestConfigResetIsolation:test_mutation_case_changes_timeout()
  constants.action_timeout_seconds = 1
  lu.assertIs(constants.action_timeout_seconds, 1,
    "mutation case should be able to override timeout")
end

function TestConfigResetIsolation:test_next_case_sees_default_timeout()
  lu.assertIs(constants.action_timeout_seconds, 15,
    "reset hook should restore config defaults before the next case")
end


return TestConfigResetIsolation
