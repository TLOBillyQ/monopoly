-- tool_resolver.lua —— 工具跟主干解析:git ls-remote 取上游 HEAD commit,带缓存。
--
-- 钉版(tag + rockspec URL 命名约定)废弃后,tools.lock 只记仓库地址,
-- 新鲜度 = 上游 HEAD commit。解析结果缓存于 .toolcache/resolved-tools.tsv
-- (24h TTL),避免每个工具入口每次调用都打 Gitea(约 19 个入口共享
-- bootstrap.ensure_tool)。网络失败回退过期缓存;无缓存可回退时由调用方
-- 决定是否降级到 tree 里已装版本。
--
-- 缓存行格式:name<TAB>head<TAB>installed<TAB>resolved_at
-- head = 解析到的上游 HEAD;installed = 实际装进 tree 的 commit(浅克隆后
-- rev-parse 实测)。安装成功会把两者都写成实测 commit,缓存自愈。
local path_lib = require("foundation.path")
local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")

local tool_resolver = {}

local _CACHE_TTL_SECONDS = 24 * 60 * 60
local _CACHE_FILENAME = "resolved-tools.tsv"

-- git ls-remote <repo>.git HEAD,拿上游主干 commit。run 可注入以便测试。
function tool_resolver.head_commit(repo_url, run)
  run = run or proc_lib.run_command
  local remote = tostring(repo_url or ""):gsub("/+$", "")
  if remote:match("%.git$") == nil then
    remote = remote .. ".git"
  end
  local result = run({ "git", "ls-remote", remote, "HEAD" })
  if not result.ok then
    return nil, "git ls-remote failed for " .. remote .. ": " .. tostring(result.output)
  end
  local sha = tostring(result.output or ""):match("^(%x+)%s+HEAD")
  if sha == nil then
    return nil, "no HEAD ref at " .. remote
  end
  return sha
end

local function _cache_path(env)
  return path_lib.join_path((env or {}).tool_cache_dir or ".toolcache", _CACHE_FILENAME)
end

-- name → { commit = head_sha, installed = sha|nil, resolved_at = epoch }。
-- 文件不存在返回空表。
function tool_resolver.read_cache(env)
  local cache = {}
  local content = fs_lib.read_file(_cache_path(env))
  if content == nil then
    return cache
  end
  for line in tostring(content):gmatch("[^\r\n]+") do
    local name, head, installed, epoch = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%d+)$")
    if name ~= nil then
      if installed == "-" then
        installed = nil
      end
      cache[name] = { commit = head, installed = installed, resolved_at = tonumber(epoch) }
    end
  end
  return cache
end

function tool_resolver.write_cache(env, cache)
  local lines = {}
  for name, entry in pairs(cache) do
    lines[#lines + 1] = table.concat({
      name,
      entry.commit,
      entry.installed or "-",
      tostring(entry.resolved_at),
    }, "\t")
  end
  table.sort(lines)
  local path = _cache_path(env)
  local ok, err = fs_lib.ensure_parent_dir(path)
  if not ok then
    return nil, err
  end
  return fs_lib.write_file(path, table.concat(lines, "\n") .. "\n")
end

-- 安装成功后记录实测 commit(head 与 installed 一并更新,缓存自愈)。
function tool_resolver.mark_installed(env, name, commit)
  local cache = tool_resolver.read_cache(env)
  cache[name] = { commit = commit, installed = commit, resolved_at = os.time() }
  return tool_resolver.write_cache(env, cache)
end

-- 解析顺序:新鲜缓存 → git 远端 → 过期缓存兜底。
-- 成功返回 { commit = ..., installed = ...|nil, source = "cache"|"remote"|"stale-cache",
-- warning = 可选 };彻底失败返回 nil, err。
function tool_resolver.resolve(name, repo_url, env, opts)
  opts = opts or {}
  local cache = tool_resolver.read_cache(env)
  local entry = cache[name]
  local now = os.time()
  if entry ~= nil and not opts.force_refresh and now - entry.resolved_at < _CACHE_TTL_SECONDS then
    return { commit = entry.commit, installed = entry.installed, source = "cache" }
  end
  local sha, err = tool_resolver.head_commit(repo_url, opts.run)
  if sha ~= nil then
    cache[name] = { commit = sha, installed = entry and entry.installed, resolved_at = now }
    tool_resolver.write_cache(env, cache)
    return { commit = sha, installed = entry and entry.installed, source = "remote" }
  end
  if entry ~= nil then
    return { commit = entry.commit, installed = entry.installed, source = "stale-cache", warning = err }
  end
  return nil, err
end

return tool_resolver
