--- luassert 装载器(#74 断言层迁移试点)。
---
--- 契约(与 tools/packages/luaunit_runner/runner.lua 的 luaunit 装载同口径):
---   - 只从 `<repo>/.toolcache/luarocks` 解析真身;解析到 tree 之外(用户 tree、
---     全局 PATH)即显式失败,不静默降级到另一份 luassert;
---   - tree 缺 rock 时按项目既有口径就地 bootstrap(luassert 的 say 依赖由
---     luarocks 依赖解析一并带进同一 tree),失败返回 nil, err;
---   - 返回断言对象本身,绝不写 `_G.assert`——旧运行器与 LuaUnit 的后端语义都
---     挂在全局 Lua assert 上,覆盖它等于换执行后端,而不是换断言词汇。
---
--- 调用方需已装好 package.path(runner / test/helper.lua 的既有前置),本模块
--- 不再自建第二套路径引导。
local M = {}

local _assert_obj = nil
local _load_error = nil
local _env = nil

local function _normalize(path)
  return tostring(path or ""):gsub("\\", "/")
end

--- repo_root 的唯一真源是 foundation.bootstrap(从源文件路径向上找仓库根,
--- 与 verify / spec_lane 同口径,不依赖 cwd)。结果进程内缓存。
function M.env()
  if _env == nil then
    _env = require("foundation.bootstrap").install(debug.getinfo(1, "S").source)
  end
  return _env
end

function M.repo_root()
  return M.env().repo_root
end

local function _cache_prefix(env)
  return _normalize(env.repo_root):gsub("/+$", "") .. "/.toolcache/luarocks/"
end

-- 解析 + 校验来源。返回规范化后的源路径;出 tree 即错。
local function _resolve_in_cache(name, prefix)
  local source = package.searchpath(name, package.path)
  if source == nil then
    return nil, name .. " is not resolvable from package.path"
  end
  local normalized = _normalize(source)
  if normalized:find(prefix, 1, true) ~= 1 then
    return nil, name .. " must load from the project tool cache, got: " .. normalized
  end
  return normalized
end

local function _load()
  local env = M.env()
  local bootstrap = require("foundation.bootstrap")
  local ok_tree, tree_err = bootstrap.ensure_luassert_tree(env.repo_root)
  if ok_tree ~= true then
    return nil, "luassert tree bootstrap failed: " .. tostring(tree_err)
  end

  local prefix = _cache_prefix(env)
  for _, name in ipairs({ "luassert", "say" }) do
    local _, resolve_err = _resolve_in_cache(name, prefix)
    if resolve_err ~= nil then
      return nil, resolve_err
    end
  end

  return require("luassert")
end

--- 加载真 luassert 断言对象。成功返回断言对象;失败返回 nil, err(原因带全,
--- 不返回空表让调用方误以为可用)。
function M.load()
  if _assert_obj ~= nil then
    return _assert_obj
  end
  if _load_error ~= nil then
    return nil, _load_error
  end
  local assert_obj, err = _load()
  if assert_obj == nil then
    _load_error = err
    return nil, err
  end
  _assert_obj = assert_obj
  return _assert_obj
end

return M
