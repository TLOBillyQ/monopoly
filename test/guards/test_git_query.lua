local lu = require("luaunit")
local git_query = require("test.guards.lib.git_query")

TestGitQuery = {}

function TestGitQuery:test_list_files_excludes_tracked_files_deleted_from_worktree()
  local original_run_git = git_query.run_git
  local calls = {}
  git_query.run_git = function(args)
    calls[#calls + 1] = table.concat(args, " ")
    local command = table.concat(args, " ")
    if command == "ls-files --deleted src" then
      return "src/removed.lua\n"
    end
    if command == "ls-files src" then
      return "src/kept.lua\nsrc/removed.lua\n"
    end
    if command == "ls-files --others --exclude-standard src" then
      return "src/new.lua\n"
    end
    error("unexpected git command: " .. command)
  end

  local files = git_query.list_files("src")
  git_query.run_git = original_run_git

  lu.assertEquals(files, { "src/kept.lua", "src/new.lua" })
  lu.assertEquals(calls, {
    "ls-files --deleted src",
    "ls-files src",
    "ls-files --others --exclude-standard src",
  })
end

function TestGitQuery:test_list_files_returns_deleted_query_error()
  local original_run_git = git_query.run_git
  git_query.run_git = function()
    return nil, "git unavailable"
  end

  local files, err = git_query.list_files("src")
  git_query.run_git = original_run_git

  lu.assertNil(files)
  lu.assertEquals(err, "git unavailable")
end

-- 中文根级条目枚举钉：git 默认 core.quotepath=true 会把非 ASCII 路径转义加引号，
-- root_whitelist_guard 因此把违规名读成 `"tasks`，白名单条目永远对不上。
-- run_git 必须显式关掉 quotepath（机制钉），并保证真实枚举结果不带引号前缀（行为钉）。
function TestGitQuery:test_run_git_disables_core_quotepath()
  local proc_lib = require("foundation.proc")
  local original = proc_lib.run_command
  local captured = nil
  proc_lib.run_command = function(command, opts)
    captured = command
    return { ok = true, output = "" }
  end

  git_query.run_git({ "ls-files", "tasks" })
  proc_lib.run_command = original

  lu.assertEquals(captured, { "git", "-c", "core.quotepath=false", "-C", ".", "ls-files", "tasks" })
end

function TestGitQuery:test_list_files_reports_utf8_paths_unquoted()
  local files = git_query.list_files("tasks")
  lu.assertEquals(type(files), "table")
  -- 中文任务书存在时非空跑：枚举结果必须是 UTF-8 原文，既不能带 git 的引号外壳，
  -- 也不能含八进制转义反斜杠（tasks/ 为空时本循环空转，机制由上面的 argv 钉兜住）。
  for _, path in ipairs(files) do
    lu.assertEquals(path:sub(1, 1) == '"', false)
    lu.assertEquals(path:find("\\", 1, true) == nil, true)
  end
end

return TestGitQuery
