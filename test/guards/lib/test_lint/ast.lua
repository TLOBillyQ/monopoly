-- 测试 lint 骨架(#127):AST 获取。parser 用项目工具缓存里的 luacheck
-- (与 lint 车道同一棵树、同一份真身校验),首次装载失败时按需 ensure;
-- 网络类装不上由调用方按 #112 不可用归类,不冒充「测试干净」。
require("test.bootstrap").install_package_paths()

local M = {}

local _parser

-- 返回 luacheck.parser 模块;装不上时返回 nil, err, unavailable(第三值同
-- foundation.bootstrap.ensure_luacheck_tree 的不可用记录)。
function M.parser()
  if _parser ~= nil then
    return _parser
  end
  local loaded, mod = pcall(require, "luacheck.parser")
  if not loaded then
    local bootstrap = require("foundation.bootstrap")
    local env = bootstrap.resolve()
    local ensured, err, unavailable = bootstrap.ensure_luacheck_tree(env.repo_root)
    if ensured ~= true then
      return nil, err, unavailable
    end
    mod = require("luacheck.parser")
  end
  -- 与 lint 车道同口径的真身校验:必须解析自项目 .toolcache/luarocks。
  local origin = package.searchpath("luacheck.parser", package.path) or ""
  assert(
    origin:gsub("\\", "/"):find("/.toolcache/luarocks/", 1, true) ~= nil,
    "luacheck.parser must resolve from .toolcache/luarocks, got: " .. origin
  )
  _parser = mod
  return _parser
end

-- 解析一份 spec 源码,返回 { ast, comments };语法错误返回 nil + 含行号的
-- 可读错误(不抛异常,调用方必须把解析失败报出来而不是静默跳过)。
function M.parse(source)
  local parser, err, unavailable = M.parser()
  if parser == nil then
    return nil, err, unavailable
  end
  -- luacheck 1.2.0 的 lexer 不吃裸字符串,源码要先经 decoder 包成 Chars 对象。
  local chars = require("luacheck.decoder").decode(tostring(source or ""))
  local ok, ast, comments = pcall(parser.parse, chars)
  if not ok then
    local syntax = ast
    if type(syntax) == "table" and syntax.msg ~= nil then
      return nil, "syntax error: " .. tostring(syntax.msg) .. " (line " .. tostring(syntax.line) .. ")"
    end
    return nil, "syntax error: " .. tostring(syntax)
  end
  return { ast = ast, comments = comments or {} }
end

return M
