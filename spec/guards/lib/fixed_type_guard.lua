require("spec.bootstrap").install_package_paths()

local guard_support = require("spec.support.guards.guard_support")

local scan_roots = { "src" }

local function _trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function _is_bare_int(value)
  return _trim(value):match("^%-?%d+$") ~= nil
end

local function _split_args(args_str)
  local args = {}
  for arg in (tostring(args_str or "") .. ","):gmatch("([^,]*),") do
    args[#args + 1] = _trim(arg)
  end
  return args
end

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

      local set_camera_args = line:match("set_camera_property%s*%((.-)%)")
      if set_camera_args then
        local args = _split_args(set_camera_args)
        if _is_bare_int(args[2]) then
          return {
            path = path,
            line = line_number,
            name = "set_camera_property(value as fixed)",
            replacement = "pass float literal (e.g. 30.0) for value arg",
            text = line,
          }
        end
      end

      local vector3_args = line:match("math%s*%.%s*Vector3%s*%((.-)%)")
      if vector3_args then
        for _, arg in ipairs(_split_args(vector3_args)) do
          if _is_bare_int(arg) then
            return {
              path = path,
              line = line_number,
              name = "math.Vector3(component as fixed)",
              replacement = "use float literals for components (e.g. 0.0)",
              text = line,
            }
          end
        end
      end

      local quaternion_args = line:match("math%s*%.%s*Quaternion%s*%((.-)%)")
      if quaternion_args then
        for _, arg in ipairs(_split_args(quaternion_args)) do
          if _is_bare_int(arg) then
            return {
              path = path,
              line = line_number,
              name = "math.Quaternion(component as fixed)",
              replacement = "use float literals for components (e.g. 90.0)",
              text = line,
            }
          end
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

  return { ok = true, message = "fixed_type_guard ok" }
end

function M.main()
  local result = M.run()
  if result.error then
    io.stderr:write("fixed_type_guard error: ", result.error, "\n")
    os.exit(1)
  end
  if result.violations then
    for _, violation in ipairs(result.violations) do
      io.stderr:write(
        "fixed_type_guard: ",
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
