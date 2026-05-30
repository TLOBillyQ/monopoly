require("spec.bootstrap").install_package_paths()

local guard_support = require("spec.support.guards.guard_support")

local function _scan_rule(rule)
  return guard_support.find_line_violation({
    roots = rule.roots,
    find_violation = function(path, relpath, line, line_number)
      for _, token in ipairs(rule.forbidden or {}) do
        if line:find(token, 1, true) then
          return {
            path = relpath,
            line = line_number,
            token = token,
            text = line,
            description = rule.description,
          }
        end
      end

      for _, pattern in ipairs(rule.forbidden_patterns or {}) do
        if line:find(pattern) then
          return {
            path = relpath,
            line = line_number,
            token = pattern,
            text = line,
            description = rule.description,
          }
        end
      end

      return nil
    end,
  })
end

local function _check_forbidden_files(paths)
  for _, path in ipairs(paths or {}) do
    local file = io.open(path, "r")
    if file then
      file:close()
      return {
        path = path,
        line = 1,
        token = "forbidden_file",
        text = path,
        description = "forbidden file exists",
      }
    end
  end
  return nil
end

local M = {}

function M.run(opts)
  opts = opts or {}
  for _, rule in ipairs(opts.rules or {}) do
    local hit, err = _scan_rule(rule)
    if err and not tostring(err):find("no lua files found under", 1, true) then
      return { ok = false, error = err }
    end
    if hit then
      return { ok = false, violation = hit }
    end
  end

  local forbidden_file_hit = _check_forbidden_files(opts.forbidden_files)
  if forbidden_file_hit then
    return { ok = false, violation = forbidden_file_hit }
  end

  return { ok = true, message = "dep_rules ok" }
end

return M
