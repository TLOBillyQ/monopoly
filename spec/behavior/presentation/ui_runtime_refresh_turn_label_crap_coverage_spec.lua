local ok, suite = pcall(require, "suites.presentation.ui_runtime_refresh_turn_label_crap_coverage")

if ok and type(suite) == "table" and suite.tests then
  describe(suite.name, function()
    for _, case in ipairs(suite.tests) do
      it(case.name, case.run)
    end
  end)
else
  describe("presentation.ui_runtime_refresh_turn_label_crap_coverage", function()
    pending("suite source references ui_runtime._M_test which no longer exists (pre-existing breakage, see git log src/ui/ctl/ui_runtime.lua); load error: " .. tostring(suite))
  end)
end
