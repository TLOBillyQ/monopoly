local bootstrap = require("scripts.shared.bootstrap")
local env = bootstrap.install(arg and arg[0])
local migration_map = require("tests.support.migration_map")

local function main()
  migration_map.validate_entries()
  local count = 0
  print("generate_shims dry-run")
  print("repo_root=" .. env.repo_root)
  for _, entry in ipairs(migration_map.iter_pairs()) do
    count = count + 1
    print(entry.old_path .. " => return require(\"" .. entry.new_module .. "\")")
  end
  print("planned_shims=" .. tostring(count))
end

main()
