local function _run_dep_rules_check()
  dofile("tests/internal/dep_rules.lua")
end

return {
  layer = "integration",
  domain = "internal_dep_rules",
  cases = {
    {
      id = "given_repo_when_run_dep_rules_then_no_forbidden_import_paths",
      desc = "dep_rules script must pass",
      run = _run_dep_rules_check,
    },
  },
}
