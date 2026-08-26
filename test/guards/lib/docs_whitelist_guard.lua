require("test.bootstrap").install_package_paths()

local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local git_query = require("test.guards.lib.git_query")

local docs_whitelist_guard = {}

-- 项目叙事文档采用显式路径白名单。front matter 不再是准入条件；临时 effort
-- 由工单和 git 历史承载，不进入 docs/。
local config = require("test.guards.config.docs_whitelist")
local configured_retired_dirs = config.retired_dirs

local function is_docs_path(path)
  return path:sub(1, 5) == "docs/"
end

local function path_exists(paths, target)
  if paths[target] then
    return true
  end
  local prefix = target:gsub("/+$", "") .. "/"
  for path in pairs(paths) do
    if path:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function link_target(raw_target)
  local target = tostring(raw_target or ""):match("^%s*(.-)%s*$")
  if target:sub(1, 1) == "<" then
    target = target:match("^<([^>]+)>") or ""
  else
    target = target:match("^([^%s]+)") or ""
  end
  if target == "" or target:sub(1, 1) == "#" or target:match("^%a[%w+.-]*:") then
    return nil
  end
  target = target:match("^[^#?]+") or ""
  if target == "" then
    return nil
  end
  return target
end

local function broken_links(source_path, content, paths)
  local broken = {}
  local in_fence = false
  for line in (tostring(content or "") .. "\n"):gmatch("(.-)\n") do
    if line:match("^%s*```") or line:match("^%s*~~~") then
      in_fence = not in_fence
    elseif not in_fence then
      local prose = line:gsub("`[^`]*`", "")
      for raw_target in prose:gmatch("%b[]%(([^)\n]+)%)") do
        local target = link_target(raw_target)
        if target ~= nil then
          local resolved
          if target:sub(1, 1) == "/" then
            resolved = path_lib.simplify_path(target:sub(2))
          else
            resolved = path_lib.resolve_path(path_lib.parent_dir(source_path) or "", target)
          end
          if not path_exists(paths, resolved) then
            broken[#broken + 1] = resolved
          end
        end
      end
    end
  end
  return broken
end

-- 纯策略核:给定 tracked 路径表和一个 read(path) -> content|nil 的读取器,返回违规列表。
-- retired_dirs 可注入(spec 喂合成清单做语料无关验证),缺省读项目配置。
-- 不碰 git、不碰文件系统——门禁的判定逻辑必须能拿合成的「违规输入」喂进来验证它真的会红。
--
-- 纯核必须能接收合成违规输入；只跑真实仓库会让一个被掏空的门禁继续假绿。
function docs_whitelist_guard.check(paths, read, retired_dirs)
  local violations = {}
  retired_dirs = retired_dirs or configured_retired_dirs
  local existing_paths = {}
  for _, path in ipairs(paths) do
    existing_paths[path] = true
  end

  for _, path in ipairs(paths) do
    if is_docs_path(path) then
      local is_retired = false
      for _, retired in ipairs(retired_dirs) do
        if path:sub(1, #retired + 1) == retired .. "/" then
          is_retired = true
          violations[#violations + 1] = "docs_whitelist_guard: " .. retired
            .. "/ 是禁用的 effort 目录: " .. path
        end
      end

      if not is_retired then
        if not config.allowed_paths[path] then
          violations[#violations + 1] = "docs_whitelist_guard: 未在项目文档白名单: " .. path
        else
          local content = read(path)
          if content == nil then
            violations[#violations + 1] = "docs_whitelist_guard: 读不到 " .. path
          else
            for _, target in ipairs(broken_links(path, content, existing_paths)) do
              violations[#violations + 1] = "docs_whitelist_guard: 失效链接: " .. path .. " -> " .. target
            end
          end
        end
      end
    end
  end

  return violations
end

-- IO 壳:取 tracked docs 路径,把真实 reader 交给纯核。
function docs_whitelist_guard.run()
  local paths, err = git_query.list_files(".")
  if paths == nil then
    return { ok = false, error = "docs_whitelist_guard error: " .. tostring(err) }
  end
  local violations = docs_whitelist_guard.check(paths, fs_lib.read_file)
  if #violations > 0 then
    return { ok = false, error = table.concat(violations, "\n") }
  end
  return { ok = true, message = "docs_whitelist_guard ok" }
end

return docs_whitelist_guard
