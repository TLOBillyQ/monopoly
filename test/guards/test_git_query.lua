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

return TestGitQuery
