-- Windows capability rejection must precede dependency installation.
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local root = source:match("^(.*)/tools/packages/test_runner/runner.lua$") or "."
local boundary = dofile(root .. "/tools/foundation/platform_boundary.lua")
for _, value in ipairs(arg) do
  local verdict = boundary.test_verdict and boundary.test_verdict(value)
  if verdict then os.exit(boundary.emit(verdict)) end
end
local bootstrap = dofile(root .. "/tools/foundation/bootstrap.lua")
local env = bootstrap.install(source)
root = env.repo_root
local proc = require("foundation.proc")
for _, value in ipairs(arg) do
  if value == "--help" or value == "-h" then
    io.write(require("packages.luaunit_runner.cli").usage())
    os.exit(0)
  end
end
local opts = { files = {}, roots = {}, forward = {}, arguments = {} }
local after, index = false, 1
while index <= #arg do
  local value = arg[index]
  if after then opts.files[#opts.files + 1] = value
  elseif value == "--" then after = true
  elseif value:match("^%-%-backend%-manifest=") then opts.manifest = value:match("=(.*)$")
  elseif value == "--run" or value == "--output" or value == "--helper" or value == "--pattern" then
    index = index + 1
    local name = value:sub(3)
    opts[name] = assert(arg[index], "missing " .. value .. " value")
    opts.forward[#opts.forward + 1] = value .. "=" .. arg[index]
  elseif value:match("^%-%-run=") or value:match("^%-%-output=") or value:match("^%-%-helper=") or value:match("^%-%-pattern=") then
    local name, parameter = value:match("^%-%-([%w]+)=(.*)$")
    opts[name] = parameter
    opts.forward[#opts.forward + 1] = value
  elseif value == "-Xoutput" then
    index = index + 1; opts.arguments[#opts.arguments + 1] = arg[index]
    opts.forward[#opts.forward + 1] = value; opts.forward[#opts.forward + 1] = arg[index]
  elseif value == "-c" or value == "--coverage" then opts.coverage = true; opts.forward[#opts.forward + 1] = value
  else opts.roots[#opts.roots + 1] = value end
  index = index + 1
end
local profiles = assert(loadfile(root .. "/tools/packages/spec_lane/spec_profiles.lua"))()
local profile = profiles[opts.run or "default"]
if not profile then
  assert(require("foundation.fs").is_dir(opts.run), "unknown profile: " .. tostring(opts.run))
  profile = { ROOT = { opts.run }, helper = profiles.behavior.helper, output = profiles.behavior.output, pattern = profiles.behavior.pattern }
end
opts.helper = opts.helper or profile.helper
opts.output = opts.output or profile.output or "TAP"
opts.pattern = opts.pattern or profile.pattern or "test_"
local profile_output_args = profile.Xoutput or {}
if type(profile_output_args) == "string" then profile_output_args = { profile_output_args } end
for _, value in ipairs(profile_output_args) do
  opts.arguments[#opts.arguments + 1] = value
  opts.forward[#opts.forward + 1] = "-Xoutput"
  opts.forward[#opts.forward + 1] = value
end
local targets = opts.roots
if #opts.files == 0 and #targets == 0 then targets = profile.ROOT or { "test" } end
for _, target in ipairs(targets) do
  if target:match("%.lua$") then opts.files[#opts.files + 1] = target
  else
    for _, file in ipairs(proc.collect_files(target, ".lua") or {}) do
      local base = file:match("([^/\\]+)%.lua$")
      if base and base:find(opts.pattern) then opts.files[#opts.files + 1] = file end
    end
  end
end
local ok, err = pcall(function()
  assert(#opts.files > 0, "no spec files selected")
  local manifest = assert(loadfile(opts.manifest or root .. "/tools/packages/test_runner/backend_manifest.lua"))()
  local selected = require("packages.test_runner.manifest").partition(manifest, opts.files, root)
  for _, backend in ipairs({ "legacy", "busted" }) do
    local available = {}
    for _, file in ipairs(selected[backend]) do
      local verdict = boundary.test_verdict(file)
      if verdict then
        if opts.run ~= "tooling" then os.exit(boundary.emit(verdict)) end
        io.write(string.format("# EXCLUDED: %s cases=%d reason=%s\n", file, verdict.cases, verdict.message:gsub("\n", " ")))
      else available[#available + 1] = file end
    end
    selected[backend] = available
  end
  assert(#selected.legacy + #selected.busted > 0, "no available spec files selected")
  local total = { files = 0, cases = 0, passed = 0, failed = 0, errors = 0 }
  local failed = false
  if #selected.legacy > 0 then
    local command = { require("foundation.lua54").lua54_bin(), root .. "/tools/packages/luaunit_runner/runner.lua" }
    for _, value in ipairs(opts.forward) do command[#command + 1] = value end
    -- Windows cmd has an 8191-character command limit. Pass the explicit
    -- legacy partition as data, keeping one process and shared module identity.
    local list_path = require("foundation.env").make_temp_path("legacy_files", ".txt")
    for _, file in ipairs(selected.legacy) do assert(not file:find("[\r\n%z]"), "invalid file identity") end
    assert(require("foundation.fs").write_file(list_path, table.concat(selected.legacy, "\n") .. "\n"))
    command[#command + 1] = "--file-list=" .. list_path
    local result = proc.run_command(command)
    require("foundation.fs").remove_path(list_path)
    local backend_output = (result.output or ""):gsub("# COUNTS:", "# BACKEND COUNTS:")
    io.write(backend_output)
    local f, c, p, x, e
    for line in tostring(result.output):gmatch("[^\r\n]+") do
      local a, b, d, g, h = line:match("^# COUNTS: files=(%d+) cases=(%d+) passed=(%d+) failed=(%d+) errors=(%d+)$")
      if a then f, c, p, x, e = a, b, d, g, h end
    end
    assert(f and tonumber(f) == #selected.legacy and tonumber(c) > 0, "legacy backend empty/incomplete result")
    total.files, total.cases, total.passed, total.failed, total.errors = tonumber(f), tonumber(c), tonumber(p), tonumber(x), tonumber(e)
    failed = not result.ok
  end
  if #selected.busted > 0 then
    assert(bootstrap.ensure_busted_tree(root))
    require("packages.test_runner.cache_loader").install(root)
    if opts.coverage then
      assert(bootstrap.ensure_luacov_tree(root))
      require("luacov.runner").init(os.getenv("LUACOV_CONFIG") or "tools/packages/coverage/coverage_config.lua")
    end
    local counts = require("packages.test_runner.busted_backend").run(selected.busted, opts.helper, opts.output, opts.arguments)
    assert(counts.cases > 0, "busted backend empty result")
    for key, value in pairs(counts) do total[key] = total[key] + value end
  end
  io.write(string.format("# COUNTS: files=%d cases=%d passed=%d failed=%d errors=%d\n", total.files, total.cases, total.passed, total.failed, total.errors))
  if failed or total.failed + total.errors > 0 then os.exit(1) end
end)
if not ok then io.stderr:write("test_runner: " .. tostring(err) .. "\n"); os.exit(1) end
