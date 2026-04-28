require("tests.bootstrap").install_package_paths()

local common = require("shared.lib.common")

local M = {}

local function _split_lines(text)
  local lines = {}
  for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  return lines
end

local function _run_git(args)
  local command = { "git", "-C", "." }
  for _, arg in ipairs(args or {}) do
    command[#command + 1] = arg
  end
  local result = common.run_command(command, {
    cwd = ".",
  })
  if result.ok ~= true then
    return nil, result.output
  end
  return result.output
end

local function _tracked_matches(pathspec)
  local output, err = _run_git({ "ls-files", "--", pathspec })
  if output == nil then
    return nil, err
  end
  return _split_lines(output)
end

local function _gitlinks()
  local output, err = _run_git({ "ls-files", "-s" })
  if output == nil then
    return nil, err
  end

  local links = {}
  for _, line in ipairs(_split_lines(output)) do
    if line:match("^160000 ") then
      local path = line:match("%d+%s+[%da-f]+%s+%d+\t(.+)$")
      if path ~= nil then
        links[#links + 1] = path
      end
    end
  end
  return links
end

function M.run()
  local tracked_pathspecs = {
    ".claude/worktrees",
    "tools/quality/arch/viewer",
    "tools/quality/scrap/viewer",
    "tools/loc_engine/monopoly-loc.exe",
  }
  local violations = {}

  for _, pathspec in ipairs(tracked_pathspecs) do
    local matches, err = _tracked_matches(pathspec)
    if matches == nil then
      return { ok = false, error = "repo_hygiene error: " .. tostring(err) }
    end
    for _, match in ipairs(matches) do
      violations[#violations + 1] = "repo_hygiene: tracked generated/local artifact " .. tostring(match)
    end
  end

  local gitlinks, err = _gitlinks()
  if gitlinks == nil then
    return { ok = false, error = "repo_hygiene error: " .. tostring(err) }
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

function M.main()
  local result = M.run()
  if not result.ok then
    io.stderr:write(result.error, "\n")
    os.exit(1)
  end
  print(result.message)
end

if ... == nil then
  M.main()
else
  return M
end
