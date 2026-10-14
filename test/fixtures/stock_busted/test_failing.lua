-- 反例样本:适配器不得吞掉失败断言,原版 busted.runner 仍须非零退出(#99)。
local check = require("luassert")

describe("stock busted adapter", function()
  it("reports a deliberately false assertion", function()
    check.is_true(false)
  end)
end)
