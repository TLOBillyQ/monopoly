---@diagnostic disable: undefined-global, undefined-field

local lu = require("luaunit")
local logger = require("src.foundation.log")

-- describe("contract.foundation.log") 拍平为文件级 TestContractFoundationLog,
-- before_each/after_each → setUp/tearDown,共享 fixture(original_print /
-- original_io_write / outputs)从 describe 级 local 提升为文件级 upvalue,
-- 用例数与改写前一一对应(4 例)。
TestContractFoundationLog = {}

local original_print
local original_io_write
local outputs

function TestContractFoundationLog:setUp()
  original_print = print
  original_io_write = io.write
  outputs = {}

  -- luacheck: push ignore 121 122
  rawset(_G, "print", function(...)
    local parts = { ... }
    outputs[#outputs + 1] = table.concat(parts, " ")
  end)

  rawset(io, "write", function(...)
    local parts = { ... }
    outputs[#outputs + 1] = table.concat(parts, "")
    return true
  end)
  -- luacheck: pop

  logger.reset_time_runtime()
  logger.set_info_per_turn_limit(nil)
  logger.set_info_turn_provider(nil)
end

function TestContractFoundationLog:tearDown()
  -- luacheck: push ignore 121 122
  rawset(_G, "print", original_print)
  rawset(io, "write", original_io_write)
  -- luacheck: pop
  logger.reset_time_runtime()
end

function TestContractFoundationLog:test_info_warn_info_unlimited_emit_formatted_output()
  logger.info("i")
  logger.warn("w")
  logger.info_unlimited("u")

  lu.assertTrue(#outputs >= 3)
  lu.assertEvalToTrue(outputs[1]:find("%[info%]"), "info should include level label")
  lu.assertEvalToTrue(outputs[1]:find("i"), "info should include message text")
  lu.assertEvalToTrue(outputs[2]:find("%[warn%]"), "warn should include level label")
  lu.assertEvalToTrue(outputs[3]:find("%[info%]"), "info_unlimited should include level label")
end

function TestContractFoundationLog:test_formats_lines_with_time_level_and_text()
  logger.set_time_formatter(function()
    return "12:34:56"
  end)
  logger.info("hello")

  lu.assertEquals(outputs[1], "12:34:56 [info] hello")
end

function TestContractFoundationLog:test_omits_the_time_prefix_when_the_formatter_yields_an_empty_string()
  logger.set_time_formatter(function()
    return ""
  end)
  logger.info("bare")

  lu.assertEquals(outputs[1], "[info] bare")
end

function TestContractFoundationLog:test_info_per_turn_limit_throttles_plain_info_but_not_unlimited()
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function()
    return 1
  end)

  logger.info("first")
  logger.info("second")
  logger.info_unlimited("unlimited")

  local text = table.concat(outputs, "\n")
  lu.assertEvalToTrue(text:find("first"))
  lu.assertEvalToFalse(text:find("second"), "second plain info should be throttled")
  lu.assertEvalToTrue(text:find("unlimited"), "unlimited info should bypass throttle")
end


return TestContractFoundationLog
