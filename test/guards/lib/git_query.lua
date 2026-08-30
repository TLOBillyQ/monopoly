require("test.bootstrap").install_package_paths()

local proc_lib = require("foundation.proc")

local M = {}

function M.split_lines(text)
  local lines = {}
  for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  return lines
end

-- core.quotepath=false:本仓库的根级条目含中文文件名（tasks/<中文任务书>.md）。
-- git 默认把非 ASCII 路径转义加引号输出（"tasks/\351\205\215..."），会让按路径首段
-- 判定的 guard 把违规名读成 `"tasks` ——白名单条目永远对不上。所有 guard 的 git
-- 枚举统一走这里，故引号开关在此一处关掉。
function M.run_git(args)
  local command = { "git", "-c", "core.quotepath=false", "-C", "." }
  for _, arg in ipairs(args or {}) do
    command[#command + 1] = arg
  end
  local result = proc_lib.run_command(command, { cwd = "." })
  if result.ok ~= true then
    return nil, result.output
  end
  return result.output
end

-- tracked-file guard 的公共 IO 壳：ls-files 取路径下 tracked 文件,交给纯核
-- check(lines)，违规拼接为 error、干净则报 "<name> ok"。三个 tracked guard 同構
-- 的 run 收敛于此，各 guard 的差异（reader、豁免清单）由 check 闭包自持。
function M.run_tracked_guard(guard_name, ls_path, check)
  local tracked, err = M.run_git({ "ls-files", ls_path })
  if tracked == nil then
    return { ok = false, error = guard_name .. " error: " .. tostring(err) }
  end

  local violations = check(M.split_lines(tracked))
  if #violations > 0 then
    return { ok = false, error = table.concat(violations, "\n") }
  end

  return { ok = true, message = guard_name .. " ok" }
end

function M.tracked_matches(pathspec)
  local output, err = M.run_git({ "ls-files", "--", pathspec })
  if output == nil then
    return nil, err
  end
  return M.split_lines(output)
end

-- tracked + 未跟踪未忽略文件合并枚举(新增未提交的文件也要被 guard 拦,
-- "人为新增违规形态"验的就是这个)。same_name_pair / cli_command_table /
-- cli_shape 三个结构 guard 同構的双 ls-files 枚举样板收敛于此。
function M.list_files(scope)
  local deleted_output, deleted_err = M.run_git({ "ls-files", "--deleted", scope })
  if deleted_output == nil then
    return nil, deleted_err
  end
  local deleted = {}
  for _, path in ipairs(M.split_lines(deleted_output)) do
    deleted[path] = true
  end

  local lines = {}
  for _, args in ipairs({
    { "ls-files", scope },
    { "ls-files", "--others", "--exclude-standard", scope },
  }) do
    local output, err = M.run_git(args)
    if output == nil then
      return nil, err
    end
    for _, line in ipairs(M.split_lines(output)) do
      if not deleted[line] then
        lines[#lines + 1] = line
      end
    end
  end
  return lines
end

return M
