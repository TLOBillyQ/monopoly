-- 测试 lint 骨架(#127 与 #128 共用):豁免注释解析。
-- 语法:`-- lint-allow: <规则名> <理由>`,写在违规行或其上一行;理由必填,
-- 缺理由(或缺规则名)的豁免本身判红。
local M = {}

-- comments: luacheck parser 的注释列表({ contents, line, ... },contents 不含 `--`)。
-- 返回 by_line(line -> rule -> reason)与解析违规列表({ rule = "lint-allow", line, message })。
function M.parse(comments)
  local by_line = {}
  local violations = {}
  for _, comment in ipairs(comments or {}) do
    local rest = tostring(comment.contents or ""):match("^%s*lint%-allow:%s*(.-)%s*$")
    if rest ~= nil then
      local rule, reason = rest:match("^(%S+)%s+(.+)$")
      if rule == nil then
        rule = rest:match("^(%S+)$")
        violations[#violations + 1] = {
          rule = "lint-allow",
          line = comment.line,
          message = rule ~= nil
            and ("lint-allow: " .. rule .. " 缺豁免理由")
            or "lint-allow 缺规则名与理由",
        }
      else
        by_line[comment.line] = by_line[comment.line] or {}
        by_line[comment.line][rule] = reason
      end
    end
  end
  return by_line, violations
end

-- 违规行或上一行有同规则、带理由的豁免即生效。
function M.exempted(by_line, rule, line)
  for _, comment_line in ipairs({ line, line - 1 }) do
    local entry = by_line[comment_line]
    if entry ~= nil and entry[rule] ~= nil then
      return true
    end
  end
  return false
end

return M
