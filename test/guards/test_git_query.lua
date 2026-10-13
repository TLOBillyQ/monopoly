require("test.bootstrap").install_package_paths()
local luassert = assert
local git_query = require("test.guards.lib.git_query")
local proc_lib = require("foundation.proc")

describe("TestGitQuery", function()
  local original_run_git
  local original_run_command

  before_each(function()
    original_run_git = git_query.run_git
    original_run_command = proc_lib.run_command
  end)

  after_each(function()
    git_query.run_git = original_run_git
    proc_lib.run_command = original_run_command
  end)

  it("test_list_files_excludes_tracked_files_deleted_from_worktree", function()
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

    luassert.is.same({ "src/kept.lua", "src/new.lua" }, files)
    luassert.is.same({
      "ls-files --deleted src",
      "ls-files src",
      "ls-files --others --exclude-standard src",
    }, calls)
  end)

  it("test_list_files_returns_deleted_query_error", function()
    git_query.run_git = function()
      return nil, "git unavailable"
    end

    local files, err = git_query.list_files("src")

    luassert.is_nil(files)
    luassert.is.equal("git unavailable", err)
  end)

  -- 中文根级条目枚举钉：git 默认 core.quotepath=true 会把非 ASCII 路径转义加引号，
  -- root_whitelist_guard 因此把违规名读成 `"tasks`，白名单条目永远对不上。
  -- run_git 必须显式关掉 quotepath（机制钉），并保证真实枚举结果不带引号前缀（行为钉）。
  it("test_run_git_disables_core_quotepath", function()
    local captured = nil
    proc_lib.run_command = function(command, opts)
      captured = command
      return { ok = true, output = "" }
    end

    git_query.run_git({ "ls-files", "tasks" })

    luassert.is.same({ "git", "-c", "core.quotepath=false", "-C", ".", "ls-files", "tasks" }, captured)
  end)

  it("test_list_files_reports_utf8_paths_unquoted", function()
    local files = git_query.list_files("tasks")
    luassert.is.equal("table", type(files))
    -- 中文任务书存在时非空跑：枚举结果必须是 UTF-8 原文，既不能带 git 的引号外壳，
    -- 也不能含八进制转义反斜杠（tasks/ 为空时本循环空转，机制由上面的 argv 钉兜住）。
    for _, path in ipairs(files) do
      luassert.is.equal(false, path:sub(1, 1) == '"')
      luassert.is.equal(true, path:find("\\", 1, true) == nil)
    end
  end)
end)
