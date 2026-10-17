-- 测试 lint 骨架(#127):测试 spec 文件枚举。vacuous-branch 与后续规则(#128)共用。
local M = {}

-- 纯判定:路径是否属于「测试 spec」——test/** 或 tools/**/test/** 下、
-- basename 以 test_ 开头的 .lua。support 模块与 fixtures 数据不入选。
function M.is_test_spec(path)
  path = tostring(path or ""):gsub("\\", "/")
  local base = path:match("[^/]+$") or ""
  if base:match("^test_.*%.lua$") == nil then
    return false
  end
  if path:sub(1, 5) == "test/" then
    return true
  end
  return path:match("^tools/.+/test/") ~= nil
end

-- 从 tracked 路径表挑出 spec 文件,排序保证报告稳定。
function M.filter(paths)
  local specs = {}
  for _, path in ipairs(paths or {}) do
    if M.is_test_spec(path) then
      specs[#specs + 1] = path
    end
  end
  table.sort(specs)
  return specs
end

return M
