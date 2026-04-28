local base_suite = require("suites.architecture.script_tools_contract")

local names = {
  loc_scan_counts_worktree_with_go_engine = true,
  loc_scan_counts_history_across_git_diff_shapes = true,
}

local tests = {}

for _, test in ipairs(base_suite.tooling_tests or {}) do
  if names[test.name] == true then
    tests[#tests + 1] = test
  end
end

return {
  name = "loc_scan_tooling_contract",
  tests = tests,
}
