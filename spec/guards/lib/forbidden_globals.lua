require("spec.bootstrap").install_package_paths()

local guard_support = require("spec.support.guards.guard_support")

local src_path_pattern = "^src/"

local forbidden = {
  {
    pattern = "%f[%w_]package%s*%.",
    name = "package.*",
    replacement = "deps injection, state.presentation_runtime, or seam require",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "%f[%w]tonumber%s*%(",
    name = "tonumber",
    replacement = "NumberUtils.to_integer()",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "%f[%w_]rawget%s*%(",
    name = "rawget",
    replacement = "field access with nil-guard (_G and _G.key)",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "%f[%w_]os%s*%.%s*clock%s*%(",
    name = "os.clock",
    replacement = "runtime port clock or injected now_fn",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "%f[%w_]debug%s*%.%s*traceback%s*%(",
    name = "debug.traceback",
    replacement = "traceback() global",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "type%s*%b()%s*==%s*[\"']number[\"']",
    name = "type(...) == \"number\"",
    replacement = "NumberUtils.is_numeric()/to_integer()",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "type%s*%b()%s*~=%s*[\"']number[\"']",
    name = "type(...) ~= \"number\"",
    replacement = "NumberUtils.is_numeric()/to_integer()",
    path_pattern = src_path_pattern,
  },
}

local scan_roots = { "src", "tests", "tools" }

local M = {}

function M.run(opts)
  opts = opts or {}
  local skip_path = opts.skip_path
  if skip_path == nil and opts.scan_roots == nil then
    skip_path = guard_support.skip_fixture_path
  end
  local violations, err = guard_support.collect_line_violations({
    roots = opts.scan_roots or scan_roots,
    allow_empty_roots = true,
    skip_path = skip_path,
    find_violation = function(path, relpath, line, line_number)
      if guard_support.is_comment_line(line) then
        return nil
      end

      for _, rule in ipairs(opts.forbidden or forbidden) do
        local path_allowed = rule.path_pattern == nil
          or tostring(relpath):find(rule.path_pattern) ~= nil
        if path_allowed and line:find(rule.pattern) then
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
