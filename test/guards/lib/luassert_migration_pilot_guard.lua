--- #74 试点断言来源门禁。只检查来源,不约束后续 busted 的结构迁移。
local M = {}

M.LOADER_PATH = "test/support/luassert_loader.lua"
M.PILOT_FILES = {
  "test/behavior/foundation/test_scope.lua",
  "test/behavior/foundation/test_tables.lua",
  "test/behavior/foundation/test_class.lua",
  "test/behavior/foundation/test_memo.lua",
  "test/behavior/rules/test_boundary_assertions_t36.lua",
}

local _FORBIDDEN = {
  { literal = 'require("luaunit")', message = "仍然直接引入 luaunit 模块" },
  { literal = "require('luaunit')", message = "仍然直接引入 luaunit 模块" },
  { literal = 'require("luassert")', message = "绕过 loader 直接引入 luassert" },
  { literal = "require('luassert')", message = "绕过 loader 直接引入 luassert" },
}
local _REQUIRED = {
  { literal = 'require("test.support.luassert_loader")', message = "断言对象未从项目工具缓存 loader 取得" },
  { literal = ".load()", message = "没有调用 loader.load() 取真 luassert 断言对象" },
}
local _LOADER_FORBIDDEN = {
  { pattern = "_G%.assert%s*=", message = "loader 给 _G.assert 赋值" },
  { pattern = "_G%s*%[%s*[\"']assert[\"']%s*%]%s*=", message = "loader 给 _G.assert 赋值" },
  { pattern = "%f[%a]rawset%s*%(%s*_G", message = "loader 用 rawset 写 _G" },
}

local function _check_forbidden(path, source, rules, violations)
  for _, rule in ipairs(rules) do
    local found
    if rule.literal then
      if source:find(rule.literal, 1, true) then found = rule.literal end
    else
      found = source:match(rule.pattern)
    end
    if found then
      violations[#violations + 1] = string.format("%s: %s (命中 %q)", path, rule.message, found)
    end
  end
end

function M.check(entries)
  local violations = {}
  for _, entry in ipairs(entries or {}) do
    local path, source = entry.path, tostring(entry.source or "")
    if path == M.LOADER_PATH then
      _check_forbidden(path, source, _LOADER_FORBIDDEN, violations)
    else
      _check_forbidden(path, source, _FORBIDDEN, violations)
      for _, required in ipairs(_REQUIRED) do
        if not source:find(required.literal, 1, true) then
          violations[#violations + 1] = string.format("%s: %s(缺 %q)", path, required.message, required.literal)
        end
      end
    end
  end
  return violations
end

function M.run()
  local fs_lib = require("foundation.fs")
  local env = require("foundation.bootstrap").install(debug.getinfo(1, "S").source)
  local entries = {}
  local paths = { M.LOADER_PATH }
  for _, path in ipairs(M.PILOT_FILES) do paths[#paths + 1] = path end
  for _, path in ipairs(paths) do
    local source, err = fs_lib.read_file(env.repo_root .. "/" .. path)
    if source == nil then
      return { ok = false, error = "luassert_migration_pilot_guard error: " .. tostring(err) }
    end
    entries[#entries + 1] = { path = path, source = source }
  end
  local violations = M.check(entries)
  if #violations > 0 then return { ok = false, error = table.concat(violations, "\n") } end
  return { ok = true, message = string.format("luassert_migration_pilot_guard ok (%d 个试点文件)", #M.PILOT_FILES) }
end

return M
