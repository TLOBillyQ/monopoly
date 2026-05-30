local runtime_paths = {}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _strip_source_prefix(path)
  return _normalize_path(path):gsub("^@", "")
end

local function _join_path(base, child)
  local normalized_base = _normalize_path(base):gsub("/+$", "")
  local normalized_child = _normalize_path(child):gsub("^/+", "")
  if normalized_base == "" then
    return normalized_child
  end
  if normalized_child == "" then
    return normalized_base
  end
  return normalized_base .. "/" .. normalized_child
end

local function _dirname(path)
  local normalized = _normalize_path(path)
  return normalized:match("^(.*)/[^/]+$") or "."
end

local function _is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function _current_dir()
  local env_cwd = os.getenv("PWD")
  if env_cwd ~= nil and env_cwd ~= "" then
    return _normalize_path(env_cwd)
  end

  local command = _is_windows() and "cd" or "pwd"
  local process = io.popen(command)
  if process == nil then
    return "."
  end

  local output = process:read("*a") or ""
  process:close()
  local normalized = _normalize_path(output):gsub("%s+$", "")
  if normalized == "" then
    return "."
  end
  return normalized
end

local function _path_exists(path)
  local file = io.open(path, "rb")
  if file ~= nil then
    file:close()
    return true
  end

  local normalized = _normalize_path(path)
  local escaped = normalized:gsub('"', '\\"')
  local command
  if _is_windows() then
    command = string.format('if exist "%s" (exit 0) else (exit 1)', escaped)
  else
    command = string.format('[ -e "%s" ]', escaped)
  end

  local ok = os.execute(command)
  if type(ok) == "number" then
    return ok == 0
  end
  return ok == true
end

local function _is_absolute_path(path)
  local normalized = _normalize_path(path)
  return normalized:sub(1, 1) == "/" or normalized:match("^%a:[/]")
end

local function _resolve_source_path(source_path, cwd)
  local normalized_source = _strip_source_prefix(source_path)
  if normalized_source == "" then
    return _normalize_path(cwd or ".")
  end
  if _is_absolute_path(normalized_source) then
    return normalized_source
  end
  return _join_path(cwd or ".", normalized_source)
end

local function _parent_dir(path)
  local normalized = _normalize_path(path):gsub("/+$", "")
  local parent = normalized:match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return normalized
  end
  return parent
end

local function _looks_like_repo_root(path)
  local required_entries = {
    "src",
    "spec",
    "tools",
    "vendor",
  }

  for _, entry in ipairs(required_entries) do
    if _path_exists(_join_path(path, entry)) ~= true then
      return false
    end
  end

  return true
end

local _SUBMODULE_PROBE = "crap4lua/lib/crap4lua"

local function _read_file_first_line(path)
  local file = io.open(path, "r")
  if file == nil then
    return nil
  end
  local line = file:read("*l")
  file:close()
  return line
end

local function _resolve_main_worktree_root(repo_root)
  local dot_git = _join_path(repo_root, ".git")
  local line = _read_file_first_line(dot_git)
  if line == nil then
    return nil
  end
  local gitdir = line:match("^gitdir:%s*(.+)$")
  if gitdir == nil then
    return nil
  end
  gitdir = _normalize_path(gitdir)
  if not _is_absolute_path(gitdir) then
    gitdir = _join_path(repo_root, gitdir)
  end
  local worktrees_dir = _parent_dir(gitdir)
  local main_git_dir = _parent_dir(worktrees_dir)
  return _parent_dir(main_git_dir)
end

local function _resolve_vendor_dir(repo_root)
  local default_vendor = _join_path(repo_root, "vendor")
  if _path_exists(_join_path(default_vendor, _SUBMODULE_PROBE)) then
    return default_vendor
  end
  local main_root = _resolve_main_worktree_root(repo_root)
  if main_root == nil then
    return default_vendor
  end
  local main_vendor = _join_path(main_root, "vendor")
  if _path_exists(_join_path(main_vendor, _SUBMODULE_PROBE)) then
    return main_vendor
  end
  return default_vendor
end

function runtime_paths.resolve(opts)
  opts = opts or {}

  local cwd = _normalize_path(opts.cwd or _current_dir())
  local source_path = _resolve_source_path(
    opts.source_path or opts.script_path or opts.module_source or "",
    cwd
  )
  local script_dir = source_path
  if source_path:match("%.lua$") ~= nil then
    script_dir = _dirname(source_path)
  end

  local probe = script_dir
  while probe ~= "" do
    if _looks_like_repo_root(probe) then
      return {
        source_path = source_path,
        script_dir = script_dir,
        repo_root = probe,
        tools_dir = _join_path(probe, "tools"),
        vendor_dir = _resolve_vendor_dir(probe),
      }
    end

    local parent = _parent_dir(probe)
    if parent == probe or parent == "" then
      break
    end
    probe = parent
  end

  error("failed to resolve repo_root from source path: " .. tostring(source_path))
end

function runtime_paths.normalize_path(path)
  return _normalize_path(path)
end

function runtime_paths.join_path(base, child)
  return _join_path(base, child)
end

function runtime_paths.current_dir()
  return _current_dir()
end

return runtime_paths
