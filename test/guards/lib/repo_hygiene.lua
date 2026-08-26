require("test.bootstrap").install_package_paths()

local git_query = require("test.guards.lib.git_query")

local M = {}

local function _gitlinks()
  local output, err = git_query.run_git({ "ls-files", "-s" })
  if output == nil then
    return nil, err
  end

  local links = {}
  for _, line in ipairs(git_query.split_lines(output)) do
    if line:match("^160000 ") then
      local path = line:match("%d+%s+[%da-f]+%s+%d+\t(.+)$")
      if path ~= nil then
        links[#links + 1] = path
      end
    end
  end
  return links
end

-- 生成物/本地件误提交;swarmforge/features/acceptance 的墓碑规则已由 swarm-return 决策
-- 解除(干净回归),对应纪律改由 root_whitelist_guard 与 .gitignore 承担;
-- 生成物回流仍在此拦截：tools/packages/acceptance/generated 是 gitignored 生成物。
local _TRACKED_PATHSPEC_RULES = {
  { pathspec = ".claude/worktrees", message = "tracked generated/local artifact" },
  { pathspec = "tools/packages/arch_view/viewer", message = "tracked generated/local artifact" },
  { pathspec = "tools/packages/acceptance/generated/", message = "tracked generated/local artifact" },
  { pathspec = ".swarmforge/", message = "tracked swarm runtime state" },
}

function M.run()
  local violations = {}

  for _, rule in ipairs(_TRACKED_PATHSPEC_RULES) do
    local matches, tracked_err = git_query.tracked_matches(rule.pathspec)
    if matches == nil then
      return { ok = false, error = "repo_hygiene error: " .. tostring(tracked_err) }
    end
    for _, match in ipairs(matches) do
      violations[#violations + 1] = "repo_hygiene: " .. rule.message .. " " .. tostring(match)
    end
  end

  local gitlinks, gitlinks_err = _gitlinks()
  if gitlinks == nil then
    return { ok = false, error = "repo_hygiene error: " .. tostring(gitlinks_err) }
  end
  for _, path in ipairs(gitlinks) do
    if path:match("^vendor/") == nil then
      violations[#violations + 1] = "repo_hygiene: non-vendor gitlink " .. tostring(path)
    end
  end

  if #violations > 0 then
    return {
      ok = false,
      error = table.concat(violations, "\n"),
    }
  end

  return { ok = true, message = "repo_hygiene ok" }
end

return M
