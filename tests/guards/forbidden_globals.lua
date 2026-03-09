package.path = package.path .. ";./tests/?.lua"

local guard_support = require("support.guards.guard_support")

local forbidden = {
  { pattern = "%f[%w]tonumber%s*%(", name = "tonumber", replacement = "NumberUtils.to_integer()" },
  { pattern = "%f[%w_]rawget%s*%(", name = "rawget", replacement = "field access with nil-guard (_G and _G.key)" },
  { pattern = "%f[%w_]os%s*%.%s*clock%s*%(", name = "os.clock", replacement = "runtime port clock or injected now_fn" },
  { pattern = "%f[%w_]debug%s*%.%s*traceback%s*%(", name = "debug.traceback", replacement = "traceback() global" },
  { pattern = "type%s*%b()%s*==%s*[\"']number[\"']", name = "type(...) == \"number\"", replacement = "NumberUtils.is_numeric()/to_integer()" },
  { pattern = "type%s*%b()%s*~=%s*[\"']number[\"']", name = "type(...) ~= \"number\"", replacement = "NumberUtils.is_numeric()/to_integer()" },
}

local scan_roots = { "src", "tests", "scripts" }

local M = {}

function M.run(opts)
  opts = opts or {}
  local violations, err = guard_support.collect_line_violations({
    roots = opts.scan_roots or scan_roots,
    allow_empty_roots = true,
    find_violation = function(path, _, line, line_number)
      if guard_support.is_comment_line(line) then
        return nil
      end

      for _, rule in ipairs(opts.forbidden or forbidden) do
        if line:find(rule.pattern) then
          return {
            path = path,
            line = line_number,
            name = rule.name,
            replacement = rule.replacement,
            text = line,
          }
        end
      end

      return nil
    end,
  })

  if err then
    return { ok = false, error = err }
  end

  if #violations > 0 then
    return { ok = false, violations = violations }
  end

  return { ok = true, message = "forbidden_globals ok" }
end

function M.main()
  local result = M.run()
  if result.error then
    io.stderr:write("forbidden_globals error: ", result.error, "\n")
    os.exit(1)
  end
  if result.violations then
    for _, violation in ipairs(result.violations) do
      io.stderr:write(
        "forbidden_globals: ",
        violation.path,
        ":",
        tostring(violation.line),
        " uses ",
        violation.name,
        " (use ",
        violation.replacement,
        " instead)\n"
      )
      io.stderr:write("  ", violation.text, "\n")
    end
    os.exit(1)
  end

  print(result.message)
end

if ... == nil then
  M.main()
else
  return M
end
