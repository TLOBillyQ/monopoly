local base_suite = require("suites.architecture.script_tools_contract")

local names = {
  common_handles_unicode_paths_for_file_ops = true,
  arch_common_reuses_unicode_safe_file_ops = true,
  cli_help_text_is_bilingual = true,
  arch_view_viewer_supports_unicode_output_path = true,
  scrap_viewer_supports_unicode_output_path = true,
}

local tests = {}

for _, test in ipairs(base_suite.tooling_tests or {}) do
  if names[test.name] == true then
    tests[#tests + 1] = test
  end
end

return {
  name = "script_tools_io_tooling_contract",
  tests = tests,
}
