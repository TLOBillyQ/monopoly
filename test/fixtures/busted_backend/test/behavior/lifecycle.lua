local env = require("test.support.env")
local ports = require("src.foundation.ports.runtime_ports")
local shared = ports
local logger = require("src.foundation.log")
local original_warn = logger.warn
math.randomseed(env.DEFAULT_SEED)
local expected = math.random()
describe("nested lifecycle", function()
  before_each(function()
    assert.equals(expected, math.random())
    assert.is_true(ports.is_configured())
  end)
  describe("child", function()
    after_each(function()
      logger.warn = original_warn
      ports.reset_for_tests()
      require("test.support.runtime_baseline_guard").restore()
    end)
    it("contaminates the RNG", function()
      logger.warn = function() end
      for _ = 1, 37 do math.random() end
      assert.equals(shared, require("src.foundation.ports.runtime_ports"))
    end)
    it("receives the replayed RNG and restored shared ports", function()
      assert.equals(original_warn, require("src.foundation.log").warn)
      assert.equals(shared, require("src.foundation.ports.runtime_ports"))
    end)
  end)
end)
