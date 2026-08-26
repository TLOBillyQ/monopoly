require("test.bootstrap").install_package_paths()

local guard_support = require("test.support.guards.guard_support")
local config = require("test.guards.config.forbidden_globals")

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
  {
    pattern = "math%.huge%f[^%w_]",
    name = "math.huge",
    replacement = "nil-check sentinel (best==nil or x>best) — math.huge is nil in Eggy runtime",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "math%.maxinteger%f[^%w_]",
    name = "math.maxinteger",
    replacement = "explicit limit or nil-check — math.maxinteger is nil in Eggy runtime",
    path_pattern = src_path_pattern,
  },
  {
    pattern = "math%.mininteger%f[^%w_]",
    name = "math.mininteger",
    replacement = "explicit limit or nil-check — math.mininteger is nil in Eggy runtime",
    path_pattern = src_path_pattern,
  },
}

local scan_roots = { "src", "tests", "tools" }

-- Issue #83: host global direct-call interception for src/ui.
-- UI business code must route host interactions through seams.
-- 豁免面(allowlist / transitional exemptions)是本仓佐料,住 test/guards/config/forbidden_globals.lua(#176)。
local host_globals_allowlist = config.host_globals_allowlist
local host_globals_transitional_exemptions = config.host_globals_transitional_exemptions

local host_globals_tokens = {
  { pattern = "%f[%w_]GameAPI%s*[%.%(]", name = "GameAPI" },
  { pattern = "%f[%w_]LuaAPI%s*[%.%(]", name = "LuaAPI" },
  { pattern = "%f[%w_]SceneUI%s*[%.%(]", name = "SceneUI" },
  { pattern = "%f[%w_]Enums%s*[%.%(]", name = "Enums" },
  { pattern = "%f[%w_]RegisterCustomEvent%s*%(", name = "RegisterCustomEvent" },
  { pattern = "%f[%w_]UnregisterCustomEvent%s*%(", name = "UnregisterCustomEvent" },
}

for _, token in ipairs(host_globals_tokens) do
  forbidden[#forbidden + 1] = {
    pattern = token.pattern,
    name = token.name,
    replacement = "host_runtime ports seam",
    path_pattern = "^src/ui/",
    allowlist = host_globals_allowlist,
    exemptions = host_globals_transitional_exemptions,
  }
end

local function _is_allowlisted(relpath, allowlist)
  if not allowlist then
    return false
  end
  for _, pattern in ipairs(allowlist) do
    if tostring(relpath):find(pattern) then
      return true
    end
  end
  return false
end

local function _is_transitional_exempt(relpath, line, exemptions)
  if not exemptions then
    return false
  end
  local file_exemptions = exemptions[tostring(relpath)]
  if not file_exemptions then
    return false
  end
  for _, snippet in ipairs(file_exemptions) do
    if line:find(snippet, 1, true) then
      return true
    end
  end
  return false
end

local function _is_rule_exempt(relpath, line, rule)
  return _is_allowlisted(relpath, rule.allowlist)
    or _is_transitional_exempt(relpath, line, rule.exemptions)
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

      for _, rule in ipairs(opts.forbidden or forbidden) do
        local path_allowed = rule.path_pattern == nil
          or tostring(relpath):find(rule.path_pattern) ~= nil
        if path_allowed
          and not _is_rule_exempt(relpath, line, rule)
          and line:find(rule.pattern) then
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

return M
