-- test/busted_helper.lua 在原版 busted.runner 下的契约样本(#99)。
local busted = require("busted")
local check = require("luassert")
local order = {}
busted.subscribe({ "project", "case", "start" }, function()
  order[#order + 1] = "case_start"
  return nil, true
end)

describe("stock busted adapter", function()
  before_each(function() order[#order + 1] = "before_each" end)

  it("publishes the project case start before the before_each chain", function()
    check.same({ "case_start", "before_each" }, order)
  end)

  it("loads repo files under relative forward-slash chunk names", function()
    check.equal("@test/fixtures/stock_busted/test_adapter.lua", debug.getinfo(1, "S").source)
    check.equal("@tools/foundation/fs.lua", debug.getinfo(require("foundation.fs").read_raw, "S").source)
  end)
end)
