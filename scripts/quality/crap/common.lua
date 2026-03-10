local arch_common = require("arch_view.common")

local common = {}

function common.normalize_path(path)
  return arch_common.normalize_path(path)
end

function common.current_dir()
  return arch_common.current_dir()
end

function common.resolve_path(base, path)
  return arch_common.resolve_path(base, path)
end

function common.join_path(base, child)
  return arch_common.join_path(base, child)
end

function common.parent_dir(path)
  return arch_common.parent_dir(path)
end

function common.ensure_dir(path)
  return arch_common.ensure_dir(path)
end

function common.ensure_parent_dir(path)
  return arch_common.ensure_parent_dir(path)
end

function common.read_file(path)
  return arch_common.read_file(path)
end

function common.write_file(path, content)
  return arch_common.write_file(path, content)
end

function common.open_path(path)
  return arch_common.open_path(path)
end

function common.strip_source_prefix(path)
  local normalized = common.normalize_path(path)
  if normalized:sub(1, 1) == "@" then
    normalized = normalized:sub(2)
  end
  return normalized:gsub("^%./", "")
end

function common.relative_to(root, path)
  local normalized_root = common.normalize_path(root):gsub("/+$", "")
  local normalized_path = common.strip_source_prefix(path)
  if normalized_root ~= "" and normalized_path:sub(1, #normalized_root) == normalized_root then
    local suffix = normalized_path:sub(#normalized_root + 1)
    suffix = suffix:gsub("^/+", "")
    if suffix ~= "" then
      return suffix
    end
  end
  return normalized_path
end

function common.run_command(command)
  local process = io.popen(command)
  if not process then
    return nil, "failed to run command: " .. tostring(command)
  end
  local output = process:read("*a") or ""
  local ok = process:close()
  if ok == nil or ok == false then
    return nil, output
  end
  return output
end

function common.shell_quote(path)
  local normalized = common.normalize_path(path)
  if package.config:sub(1, 1) == "\\" then
    return '"' .. normalized:gsub("/", "\\") .. '"'
  end
  return '"' .. normalized .. '"'
end

return common
