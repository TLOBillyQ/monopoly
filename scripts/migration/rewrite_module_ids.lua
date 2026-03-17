local bootstrap = require("scripts.shared.bootstrap")
local env = bootstrap.install(arg and arg[0])
local migration_map = require("tests.support.migration_map")

local function _scan_file(path, old_module)
  local file = io.open(path, "r")
  if not file then
    return false
  end
  local text = file:read("*a")
  file:close()
  return text:find(old_module, 1, true) ~= nil
end

local function _collect_repo_files()
  local roots = { "src", "tests", "scripts", "docs" }
  local files = {}
  for _, root in ipairs(roots) do
    local command = string.format('find "%s" -type f 2>/dev/null', root)
    local process = io.popen(command)
    if process then
      for line in process:lines() do
        files[#files + 1] = line
      end
      process:close()
    end
  end
  table.sort(files)
  return files
end

local function main()
  migration_map.validate_entries()
  local files = _collect_repo_files()
  local hits = {}
  for _, entry in ipairs(migration_map.iter_entries()) do
    for _, path in ipairs(files) do
      if _scan_file(path, entry.old_module) then
        hits[#hits + 1] = {
          path = path,
          old_module = entry.old_module,
          new_module = entry.new_module,
        }
      end
    end
  end

  print("rewrite_module_ids dry-run")
  print("repo_root=" .. env.repo_root)
  print("planned_replacements=" .. tostring(#hits))
  for _, hit in ipairs(hits) do
    print(hit.path .. ": " .. hit.old_module .. " -> " .. hit.new_module)
  end
end

main()
