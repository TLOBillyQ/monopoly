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
        tool_cache_dir = _join_path(probe, ".swarmforge/tools"),
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
