local tests = {}
local parts = {
  require("suites.presentation.presentation_ui_action_status_part1"),
  require("suites.presentation.presentation_ui_action_status_part2"),
  require("suites.presentation.presentation_ui_action_status_part3"),
}

for _, part in ipairs(parts) do
  for _, test in ipairs(part) do
    tests[#tests + 1] = test
  end
end

return {
  name = "presentation_ui.action_status",
  tests = tests,
}
