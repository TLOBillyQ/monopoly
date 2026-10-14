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
    io.write(require("packages.test_runner.cli").usage())
    os.exit(0)
  end
end
local opts = { files = {}, roots = {}, arguments = {} }
local after, index = false, 1
while index <= #arg do
  local value = arg[index]
  if after then opts.files[#opts.files + 1] = value
  elseif value == "--" then after = true; opts.explicit_files = true
  elseif value:match("^%-%-file%-list=") then
    opts.explicit_files = true
    local count = #opts.files
    local list = assert(io.open(value:match("=(.*)$"), "rb"))
    for file in list:lines() do
      file = file:gsub("\r$", "")
      assert(file ~= "" and file:match("%.lua$") and not file:find("%z"), "invalid file identity")
      opts.files[#opts.files + 1] = file
    end
    list:close()
    assert(#opts.files > count, "empty spec file list")
  elseif value:match("^%-%-backend%-manifest=") then error("backend manifests are no longer supported")
  elseif value == "--run" or value == "--output" or value == "--helper" or value == "--pattern" then
    index = index + 1
    local name = value:sub(3)
    opts[name] = assert(arg[index], "missing " .. value .. " value")
  elseif value:match("^%-%-run=") or value:match("^%-%-output=") or value:match("^%-%-helper=") or value:match("^%-%-pattern=") then
    local name, parameter = value:match("^%-%-([%w]+)=(.*)$")
    opts[name] = parameter
  elseif value == "-Xoutput" then
    index = index + 1; opts.arguments[#opts.arguments + 1] = arg[index]
  elseif value == "-c" or value == "--coverage" then opts.coverage = true
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
end
local targets = opts.roots
if not opts.explicit_files and #opts.files == 0 and #targets == 0 then targets = profile.ROOT or { "test" } end
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
  local files, seen = {}, {}
  for _, file in ipairs(opts.files) do
    local identity = file:gsub("\\", "/"):gsub("^%./", "")
    assert(not seen[identity], "duplicate file identity: " .. identity)
    seen[identity] = true
    local verdict = boundary.test_verdict(file)
    if verdict then
      if opts.run ~= "tooling" then os.exit(boundary.emit(verdict)) end
      io.write(string.format("# EXCLUDED: %s cases=%d reason=%s\n", file, verdict.cases, verdict.message:gsub("\n", " ")))
    else
      local handle = assert(io.open(file, "rb"), "missing file identity: " .. file)
      handle:close()
      files[#files + 1] = file
    end
  end
  assert(#files > 0, "no available spec files selected")
  assert(bootstrap.ensure_busted_tree(root))
  require("packages.test_runner.cache_loader").install(root)
  if opts.coverage then
    assert(bootstrap.ensure_luacov_tree(root))
    require("luacov.runner").init(os.getenv("LUACOV_CONFIG") or "tools/packages/coverage/coverage_config.lua")
  end
  local total = require("packages.test_runner.busted_backend").run(files, opts.helper, opts.output, opts.arguments)
  io.write(string.format("# COUNTS: files=%d cases=%d passed=%d failed=%d errors=%d\n", total.files, total.cases, total.passed, total.failed, total.errors))
  if total.cases == 0 then io.stderr:write("test_runner: busted backend empty result\n") end
  if total.cases == 0 or total.failed + total.errors > 0 then os.exit(1) end
end)
if not ok then io.stderr:write("test_runner: " .. tostring(err) .. "\n"); os.exit(1) end
