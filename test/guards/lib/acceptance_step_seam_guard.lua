require("test.bootstrap").install_package_paths()

local fs_lib = require("foundation.fs")
local git_query = require("test.guards.lib.git_query")

local M = {}

-- acceptance step 接缝白名单门禁(ADR 0017 / issue #165)。
--
-- 病灶:step handler 直接 require src.rules 内部模块,driver/facade 接缝被绕空,
-- src 改内部表示时 step 静默漂移。接缝白名单口径：steps 只可经
-- driver、per-feature context、src 公开接缝(foundation / config / ui 公开面 /
-- rules ports)观察;src.rules 内部一律禁止。
--
-- 豁免清单只准收缩:存量越界模块显式列在 _EXEMPT 里逐步消化,新模块零豁免;
-- 已收敛干净却还挂在清单里的模块同样报错,防清单变成永久特权。
local _FORBIDDEN_PREFIX = "src%.rules%."
local _ALLOWED_PREFIX = "src%.rules%.ports%."

-- 存量豁免已随 DSL 重写清零(测试极简化决策/#192):绑定层迁 features/steps/ 时
-- 全部改走 driver / per-feature context / ports 接缝。清单只准收缩,新模块零豁免。
local _EXEMPT = {}

local guidance = "改走 driver 动词 / per-feature context / src.rules.ports 公开接缝(ADR 0017)"

local function _rules_internal_requires(content)
  local hits = {}
  for target in content:gmatch("require%s*%(?%s*[\"']([^\"']+)[\"']") do
    if target:find("^" .. _FORBIDDEN_PREFIX) and not target:find("^" .. _ALLOWED_PREFIX) then
      hits[#hits + 1] = target
    end
  end
  return hits
end

-- 纯策略核:给定路径表、read(path) -> content|nil 与豁免表,返回违规列表。
-- 不碰 git、不碰文件系统,违规输入可以合成喂入,保证门禁真的会红。
function M.check(paths, read, exemptions)
  local violations = {}

  for _, path in ipairs(paths) do
    if path:sub(-4) == ".lua" then
      local content = read(path)
      if content == nil then
        violations[#violations + 1] = "acceptance_step_seam_guard: 读不到 " .. path
      else
        local hits = _rules_internal_requires(content)
        if #hits > 0 and not exemptions[path] then
          violations[#violations + 1] = "acceptance_step_seam_guard: " .. path
            .. " 越界 require src.rules 内部模块: " .. table.concat(hits, ", ")
            .. " —— " .. guidance
        elseif #hits == 0 and exemptions[path] then
          violations[#violations + 1] = "acceptance_step_seam_guard: " .. path
            .. " 已不越界,请从豁免清单摘除(清单只准收缩)"
        end
      end
    end
  end

  return violations
end

-- IO 壳:取 tracked steps 路径,把真实 reader 与仓库豁免清单交给纯核。
function M.run()
  return git_query.run_tracked_guard("acceptance_step_seam_guard", "features/steps", function(lines)
    return M.check(lines, fs_lib.read_file, _EXEMPT)
  end)
end

return M
