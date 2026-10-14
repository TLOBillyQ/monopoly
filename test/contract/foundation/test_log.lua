local luassert = assert

---@diagnostic disable: undefined-global, undefined-field
local logger = require("src.foundation.log")

describe("TestContractFoundationLog", function()

local original_print
local original_io_write
local outputs

before_each(function()
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
end)

after_each(function()
  -- luacheck: push ignore 121 122
  rawset(_G, "print", original_print)
  rawset(io, "write", original_io_write)
  -- luacheck: pop
  logger.reset_time_runtime()
end)

it("test_info_warn_info_unlimited_emit_formatted_output", function()
  logger.info("i")
  logger.warn("w")
  logger.info_unlimited("u")

  luassert.is_true(#outputs >= 3)
  luassert.truthy(outputs[1]:find("%[info%]"), "info should include level label")
  luassert.truthy(outputs[1]:find("i"), "info should include message text")
  luassert.truthy(outputs[2]:find("%[warn%]"), "warn should include level label")
  luassert.truthy(outputs[3]:find("%[info%]"), "info_unlimited should include level label")
end)

it("test_formats_lines_with_time_level_and_text", function()
  logger.set_time_formatter(function()
    return "12:34:56"
  end)
  logger.info("hello")

  luassert.is.equal("12:34:56 [info] hello", outputs[1])
end)

it("test_omits_the_time_prefix_when_the_formatter_yields_an_empty_string", function()
  logger.set_time_formatter(function()
    return ""
  end)
  logger.info("bare")

  luassert.is.equal("[info] bare", outputs[1])
end)

it("test_info_per_turn_limit_throttles_plain_info_but_not_unlimited", function()
  logger.set_info_per_turn_limit(1)
  logger.set_info_turn_provider(function()
    return 1
  end)

  logger.info("first")
  logger.info("second")
  logger.info_unlimited("unlimited")

  local text = table.concat(outputs, "\n")
  luassert.truthy(text:find("first"))
  luassert.falsy(text:find("second"), "second plain info should be throttled")
  luassert.truthy(text:find("unlimited"), "unlimited info should bypass throttle")
end)

end)
