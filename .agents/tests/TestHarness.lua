local function collect_tests(suites)
  local tests = {}
  for _, suite in ipairs(suites) do
    for _, test in ipairs(suite) do
      table.insert(tests, test)
    end
  end
  return tests
end

local function run_all(suites)
  local tests = collect_tests(suites)
  for _, fn in ipairs(tests) do
    math.randomseed(1)
    fn()
    io.stdout:write(".")
  end
  print("\nAll regression checks passed (" .. #tests .. ")")
end

return {
  run_all = run_all,
}
