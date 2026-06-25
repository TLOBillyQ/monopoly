local runtime_path_ops = {}

function runtime_path_ops.normalize(path)
  return tostring(path or ""):gsub("\\", "/")
end

function runtime_path_ops.strip_source_prefix(path)
  return runtime_path_ops.normalize(path):gsub("^@", "")
end

function runtime_path_ops.join(base, child)
  local normalized_base = runtime_path_ops.normalize(base):gsub("/+$", "")
  local normalized_child = runtime_path_ops.normalize(child):gsub("^/+", "")
  if normalized_base == "" then
    return normalized_child
  end
  if normalized_child == "" then
    return normalized_base
  end
  return normalized_base .. "/" .. normalized_child
end

function runtime_path_ops.dirname(path)
  local normalized = runtime_path_ops.normalize(path)
  return normalized:match("^(.*)/[^/]+$") or "."
end

function runtime_path_ops.is_windows()
  return package.config:sub(1, 1) == "\\"
end

function runtime_path_ops.current_dir()
  local env_cwd = os.getenv("PWD")
  if env_cwd ~= nil and env_cwd ~= "" then
    return runtime_path_ops.normalize(env_cwd)
  end

  local command = runtime_path_ops.is_windows() and "cd" or "pwd"
  local process = io.popen(command)
  if process == nil then
    return "."
  end

  local output = process:read("*a") or ""
  process:close()
  local normalized = runtime_path_ops.normalize(output):gsub("%s+$", "")
  return normalized ~= "" and normalized or "."
end

function runtime_path_ops.path_exists(path)
  local file = io.open(path, "rb")
  if file ~= nil then
    file:close()
    return true
  end

  local escaped = runtime_path_ops.normalize(path):gsub('"', '\\"')
  local command
  if runtime_path_ops.is_windows() then
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

function runtime_path_ops.is_absolute(path)
  local normalized = runtime_path_ops.normalize(path)
  return normalized:sub(1, 1) == "/" or normalized:match("^%a:[/]")
end

function runtime_path_ops.resolve_source_path(source_path, cwd)
  local normalized_source = runtime_path_ops.strip_source_prefix(source_path)
  if normalized_source == "" then
    return runtime_path_ops.normalize(cwd or ".")
  end
  if runtime_path_ops.is_absolute(normalized_source) then
    return normalized_source
  end
  return runtime_path_ops.join(cwd or ".", normalized_source)
end

function runtime_path_ops.parent_dir(path)
  local normalized = runtime_path_ops.normalize(path):gsub("/+$", "")
  local parent = normalized:match("^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return normalized
  end
  return parent
end

return runtime_path_ops
