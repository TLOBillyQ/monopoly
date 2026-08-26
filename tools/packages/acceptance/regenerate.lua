-- Regenerate every gitignored acceptance spec from its feature.
--
-- The generated specs under tools/packages/acceptance/generated/ are gitignored
-- build outputs; this tool deterministically re-derives them from the features
-- listed in tools/packages/acceptance/acceptance_features.lua. It is the
-- regenerate step behind the `lua tools/cli.lua acceptance` entrypoint.

local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
assert(bootstrap.ensure_tool("acceptance4lua", env))

local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local gherkin_parser = require("acceptance4lua.gherkin_parser")
local entrypoint = require("packages.acceptance.entrypoint")
local registry = require("packages.acceptance.acceptance_features")

local regenerate = {}

-- Re-derive one feature's generated spec. ir_path is a transient JSON IR under
-- build/ (gitignored); generated_path is the standalone suite script to run.
local function _regenerate_one(feature, generated_path, ir_path)
  local ok, err = fs_lib.ensure_dir(path_lib.parent_dir(ir_path))
  if not ok then
    return nil, err
  end
  ok, err = fs_lib.ensure_dir(path_lib.parent_dir(generated_path))
  if not ok then
    return nil, err
  end
  ok, err = gherkin_parser.write_json_file(feature, ir_path)
  if not ok then
    return nil, err
  end
  ok, err = entrypoint.generate_file(ir_path, generated_path)
  if not ok then
    return nil, err
  end
  return true
end

-- Regenerate the whole suite. Returns true or (nil, error) on the first failure
-- so a broken feature surfaces immediately rather than silently dropping a spec.
-- options.generated_dir / options.entries override the registry defaults so the
-- suite can be regenerated into an isolated directory under test.
function regenerate.run(options)
  options = options or {}
  local report = options.report or function(_) end
  local generated_dir = options.generated_dir or registry.generated_dir
  local entries = options.entries or registry.entries
  local total = #entries
  for index, entry in ipairs(entries) do
    local generated_path = path_lib.join_path(generated_dir, entry.generated)
    -- gsub 返回 (串, 次数);作为末位实参会整组展开,须加括号截到单值,否则替换次数
    -- 会被 join_path 当成又一段路径拼进去。
    local ir_path = path_lib.join_path("build/acceptance", (entry.generated:gsub("%.lua$", ".json")))
    local ok, err = _regenerate_one(entry.feature, generated_path, ir_path)
    if not ok then
      return nil, string.format("%s: %s", entry.feature, tostring(err))
    end
    report(string.format("[%d/%d] %s -> %s", index, total, entry.feature, entry.generated))
  end
  return true, total
end

function regenerate.main()
  local ok, result = regenerate.run({
    report = function(line)
      io.stderr:write(line .. "\n")
    end,
  })
  if not ok then
    io.stderr:write("regenerate failed: " .. tostring(result) .. "\n")
    return 1
  end
  io.write(string.format("regenerated %d acceptance specs\n", result))
  return 0
end

if arg ~= nil and tostring(arg[0] or ""):match("tools/packages/acceptance/regenerate%.lua$") then
  os.exit(regenerate.main())
end

return regenerate
