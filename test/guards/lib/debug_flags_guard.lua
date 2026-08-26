require("test.bootstrap").install_package_paths()

local fs_lib = require("foundation.fs")
local git_query = require("test.guards.lib.git_query")

local M = {}

-- 发布泄出门禁(#265):debug_auto_all_roles 是真人玩家联调开关(开局全席位托管),
-- 必须为 false 发布。联调期本地临时改 true,这条 guard 保证它不会跟着发布跑出去。
local _FLAGS_PATH = "src/config/gameplay/debug_flags.lua"

-- 纯策略核:给定 tracked 路径表和一个 read(path) -> content|nil 的读取器,返回违规列表。
-- 不碰 git、不碰文件系统——spec 喂合成的「开关被翻成 true」输入验证它真的会红
-- 判定核可注入合成输入，避免门禁只在合规仓库上假绿。
function M.check(paths, read)
  local violations = {}

  for _, path in ipairs(paths) do
    if path == _FLAGS_PATH then
      local content = read(path)
      if content == nil then
        violations[#violations + 1] = "debug_flags_guard: 读不到 " .. path
      else
        local line_no = 0
        for line in (content .. "\n"):gmatch("(.-)\n") do
          line_no = line_no + 1
          -- 先剥注释再判定:注释里的 `debug_auto_all_roles = true` 不算违规。
          local code = line:gsub("%-%-.*$", "")
          if code:match("debug_auto_all_roles%s*=%s*true") then
            violations[#violations + 1] = "debug_flags_guard: " .. path .. ":" .. line_no
              .. " debug_auto_all_roles 必须为 false(联调开关,#265)——改回 false 再发布"
          end
        end
      end
    end
  end

  return violations
end

-- IO 壳:取 tracked 的 gameplay 配置路径,把真实 reader 交给纯核。
function M.run()
  return git_query.run_tracked_guard("debug_flags_guard", "src/config/gameplay", function(lines)
    return M.check(lines, fs_lib.read_file)
  end)
end

return M
