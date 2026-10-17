-- 测试 lint 骨架(#127 与 #128 共用):统一违规报告格式。
-- 每条:<guard>: <rule>: <path>:<line> [<测试名>] <说明>
local M = {}

function M.format(guard_name, violation)
  local head = tostring(guard_name)
    .. ": " .. tostring(violation.rule)
    .. ": " .. tostring(violation.path)
    .. ":" .. tostring(violation.line)
  if violation.test ~= nil then
    head = head .. " [" .. tostring(violation.test) .. "]"
  end
  return head .. " " .. tostring(violation.message)
end

function M.format_all(guard_name, violations)
  local lines = {}
  for _, violation in ipairs(violations or {}) do
    lines[#lines + 1] = M.format(guard_name, violation)
  end
  return lines
end

return M
