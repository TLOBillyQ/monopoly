local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/vendor_submodules.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")

local vendor_submodules = {}

local function _trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _git(cwd, args)
  local command = { "git", "-C", cwd }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return common.run_command(command)
end

local function _short(hash)
  local text = tostring(hash or "")
  if text == "" then
    return "-"
  end
  return text:sub(1, 8)
end

local function _append_issue(issues, row, message)
  issues[#issues + 1] = {
    worktree = row.worktree,
    path = row.path,
    message = message,
    recorded = row.recorded,
    actual = row.actual,
    origin_main = row.origin_main,
  }
end

function vendor_submodules.repo_root(cwd)
  local result = _git(cwd or common.current_dir(), { "rev-parse", "--show-toplevel" })
  if not result.ok then
    return nil, result.output
  end
  return _trim(result.output)
end

function vendor_submodules.submodule_paths(root)
  local result = _git(root, {
    "config",
    "--file",
    common.join_path(root, ".gitmodules"),
    "--get-regexp",
    "^submodule\\..*\\.path$",
  })
  if not result.ok then
    return nil, result.output
  end

  local paths = {}
  for line in tostring(result.output or ""):gmatch("[^\n]+") do
    local path = line:match("%s([^%s]+)%s*$")
    if path ~= nil and path:match("^vendor/") then
      paths[#paths + 1] = path
    end
  end
  table.sort(paths)
  return paths
end

function vendor_submodules.worktrees(root)
  local result = _git(root, { "worktree", "list", "--porcelain" })
  if not result.ok then
    return nil, result.output
  end

  local worktrees = {}
  for line in tostring(result.output or ""):gmatch("[^\n]+") do
    local path = line:match("^worktree%s+(.+)$")
    if path ~= nil then
      worktrees[#worktrees + 1] = _normalize_path(path)
    end
  end
  table.sort(worktrees)
  return worktrees
end

function vendor_submodules.inspect(root, worktree, submodule_path, opts)
  local row = {
    worktree = worktree,
    path = submodule_path,
    recorded = nil,
    actual = nil,
    origin_main = nil,
    dirty = false,
    fetch_ok = true,
  }

  local issues = {}
  local tree = _git(worktree, { "ls-tree", "HEAD", submodule_path })
  if tree.ok then
    row.recorded = tree.output:match("commit%s+([0-9a-f]+)")
  end
  if row.recorded == nil then
    _append_issue(issues, row, "missing gitlink in superproject")
    return row, issues
  end

  local submodule_dir = common.join_path(worktree, submodule_path)
  local actual = _git(submodule_dir, { "rev-parse", "HEAD" })
  if actual.ok then
    row.actual = _trim(actual.output)
  else
    _append_issue(issues, row, "cannot read submodule HEAD: " .. _trim(actual.output))
    return row, issues
  end

  if opts ~= nil and opts.fetch == true then
    local fetch = _git(submodule_dir, { "fetch", "--quiet", "origin", "main" })
    row.fetch_ok = fetch.ok
    if not fetch.ok then
      _append_issue(issues, row, "cannot fetch origin/main: " .. _trim(fetch.output))
    end
  end

  local origin_main = _git(submodule_dir, { "rev-parse", "origin/main" })
  if origin_main.ok then
    row.origin_main = _trim(origin_main.output)
  else
    _append_issue(issues, row, "cannot read origin/main: " .. _trim(origin_main.output))
  end

  local status = _git(submodule_dir, { "status", "--porcelain", "-uall" })
  if not status.ok then
    _append_issue(issues, row, "cannot read submodule status: " .. _trim(status.output))
  elseif _trim(status.output) ~= "" then
    row.dirty = true
    _append_issue(issues, row, "submodule working tree is dirty")
  end

  if row.actual ~= row.recorded then
    _append_issue(issues, row, "submodule HEAD differs from recorded gitlink")
  end
  if row.origin_main ~= nil and row.origin_main ~= row.recorded then
    _append_issue(issues, row, "origin/main differs from recorded gitlink")
  end

  return row, issues
end

function vendor_submodules.check(opts)
  opts = opts or {}
  local root = opts.root
  if root == nil or root == "" then
    local root_err
    root, root_err = vendor_submodules.repo_root(common.current_dir())
    if root == nil then
      return {
        ok = false,
        issues = { { message = "cannot resolve repo root: " .. tostring(root_err) } },
        rows = {},
      }
    end
  end
  root = common.normalize_path(root)

  local paths, path_err = vendor_submodules.submodule_paths(root)
  if paths == nil then
    return {
      ok = false,
      issues = { { message = "cannot read .gitmodules: " .. tostring(path_err) } },
      rows = {},
    }
  end

  local worktrees, worktree_err = vendor_submodules.worktrees(root)
  if worktrees == nil then
    return {
      ok = false,
      issues = { { message = "cannot list worktrees: " .. tostring(worktree_err) } },
      rows = {},
    }
  end

  local rows = {}
  local issues = {}
  for _, worktree in ipairs(worktrees) do
    for _, path in ipairs(paths) do
      local row, row_issues = vendor_submodules.inspect(root, worktree, path, opts)
      rows[#rows + 1] = row
      for _, issue in ipairs(row_issues) do
        issues[#issues + 1] = issue
      end
    end
  end

  return {
    ok = #issues == 0,
    root = root,
    rows = rows,
    issues = issues,
    submodule_count = #paths,
    worktree_count = #worktrees,
  }
end

local function _usage()
  return table.concat({
    "usage: lua tools/quality/vendor_submodules.lua [--root <path>] [--fetch]",
    "Checks vendor submodules across all git worktrees.",
  }, "\n")
end

local function _parse_args(args)
  local opts = {}
  local index = 1
  while index <= #(args or {}) do
    local value = args[index]
    if value == "--root" then
      opts.root = args[index + 1]
      if opts.root == nil then
        return nil, "missing value for --root"
      end
      index = index + 2
    elseif value == "--fetch" then
      opts.fetch = true
      index = index + 1
    elseif value == "--help" or value == "-h" then
      opts.help = true
      index = index + 1
    else
      return nil, "unknown option: " .. tostring(value)
    end
  end
  return opts
end

function vendor_submodules.main(args)
  local opts, err = _parse_args(args or {})
  if opts == nil then
    io.stderr:write(_usage() .. "\n" .. tostring(err) .. "\n")
    return 2
  end
  if opts.help then
    io.write(_usage() .. "\n")
    return 0
  end

  local result = vendor_submodules.check(opts)
  if result.ok then
    io.write(string.format(
      "vendor submodules clean: %d worktrees, %d submodules\n",
      result.worktree_count or 0,
      result.submodule_count or 0
    ))
    return 0
  end

  for _, issue in ipairs(result.issues or {}) do
    io.stderr:write(string.format(
      "vendor submodule issue: worktree=%s path=%s recorded=%s actual=%s origin/main=%s message=%s\n",
      tostring(issue.worktree or "-"),
      tostring(issue.path or "-"),
      _short(issue.recorded),
      _short(issue.actual),
      _short(issue.origin_main),
      tostring(issue.message or "unknown")
    ))
  end
  return 1
end

if arg ~= nil and tostring(arg[0] or ""):match("vendor_submodules%.lua$") then
  os.exit(vendor_submodules.main(arg))
end

return vendor_submodules
