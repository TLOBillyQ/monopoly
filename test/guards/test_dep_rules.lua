---@diagnostic disable: undefined-global, undefined-field
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard_support = require("test.support.guards.guard_support")

-- 规则表与行级白名单是本仓佐料,住 test/guards/config/dep_rules.lua(#176);本文件只留扫描壳。
local dep_rules_config = require("test.guards.config.dep_rules")
local rules = dep_rules_config.rules
local dep_rules_whitelist = dep_rules_config.whitelist

local function _is_whitelisted_line(relpath, line)
  local allow_by_file = dep_rules_whitelist[relpath]
  if allow_by_file == nil then
    return false
  end
  for snippet in pairs(allow_by_file) do
    if line:find(snippet, 1, true) then
      return true
    end
  end
  return false
end

local function _scan_rule(rule)
  return guard_support.find_line_violation({
    roots = rule.roots,
    find_violation = function(_, relpath, line, line_number)
      if _is_whitelisted_line(relpath, line) then
        return nil
      end

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

local function _build_error_report(rule, err)
  return table.concat({
    "dep_rules error",
    "rule: " .. tostring(rule.description),
    "roots: " .. table.concat(rule.roots or {}, ", "),
    "message: " .. tostring(err),
  }, "\n")
end

local function _build_violation_report(violation)
  return table.concat({
    "dep_rules violation",
    "dep_rules violation: "
      .. tostring(violation.path)
      .. ":"
      .. tostring(violation.line)
      .. " contains "
      .. tostring(violation.token),
    "rule: " .. tostring(violation.description),
    tostring(violation.text),
  }, "\n")
end

TestDepRules = {}

for index, rule in ipairs(rules) do
  TestDepRules["test_" .. string.format("rule %02d: %s", index, rule.description)] = function(self)
    local hit, err = _scan_rule(rule)

    if err and not tostring(err):find("no lua files found under", 1, true) then
      lu.assertTrue(false, _build_error_report(rule, err))
      return
    end

    local ok = hit == nil
    local full_report = ok and "dep_rules ok" or _build_violation_report(hit)
    lu.assertTrue(ok, full_report)
  end
end


return TestDepRules
